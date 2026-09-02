# -----------------------------------------------------------------------------

# Title:

#--------------------------------------------------------------------------------
# 05. Summarise completed abstract screening and reviewer agreement
#--------------------------------------------------------------------------------

library(readxl)
library(dplyr)
library(purrr)
library(tidyr)
library(stringr)
library(ggplot2)
library(writexl)


# 1. Settings -----------------------------------------------------------------

folder_path <- file.path(input_data, "abstracts_byReviewer", "Done")
output_dir <- file.path(output_data, "abstract_screening")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# During title/abstract screening, retaining a paper accepted by either reviewer
# is the conservative option. Disagreements are still exported for resolution.
# Change to "agreement_only" if only unanimously accepted papers should proceed.
resolution_policy <- "include_if_any_accept"
if (!resolution_policy %in% c("include_if_any_accept", "agreement_only")) {
  stop("Unknown resolution_policy: ", resolution_policy)
}

accepted_colour <- "seagreen3"
rejected_colour <- "firebrick3"
disagreement_colour <- "#E69F00"
missing_colour <- "grey80"


# 2. Read and standardise completed files -------------------------------------

files <- list.files(
  folder_path,
  pattern = "\\.xlsx?$",
  full.names = TRUE,
  ignore.case = TRUE
)
files <- files[!str_starts(basename(files), fixed("~$"))]

if (length(files) == 0) {
  stop("No Excel files found in: ", folder_path)
}

clean_names <- function(x) {
  x %>%
    str_replace_all("\\s+", " ") %>%
    str_trim()
}

read_completed_file <- function(file) {
  required_cols <- c("paperID", "rev1_name", "TA_decisionRev1")

  # Some completed workbooks have Criteria as their first worksheet. Find the
  # screening sheet from its column names instead of relying on sheet order.
  sheet_names <- excel_sheets(file)
  data_sheet <- keep(sheet_names, function(sheet) {
    header <- read_excel(file, sheet = sheet, n_max = 0)
    names(header) <- clean_names(names(header))
    all(required_cols %in% names(header))
  })

  if (length(data_sheet) != 1) {
    stop(
      "Expected one screening worksheet in ", basename(file),
      "; found ", length(data_sheet), "."
    )
  }

  dat <- read_excel(file, sheet = data_sheet[[1]])
  names(dat) <- clean_names(names(dat))

  missing_cols <- setdiff(required_cols, names(dat))

  if (length(missing_cols) > 0) {
    stop(
      "Missing required column(s) in ", basename(file), ": ",
      paste(missing_cols, collapse = ", ")
    )
  }

  dat %>%
    mutate(
      across(everything(), as.character),
      source_file = basename(file),
      paperID = str_squish(paperID),
      rev1_name = str_squish(rev1_name),
      decision_original = str_squish(TA_decisionRev1),
      decision = case_when(
        str_detect(str_to_lower(decision_original), "accept") ~ "Accepted",
        str_detect(str_to_lower(decision_original), "reject") ~ "Rejected",
        TRUE ~ NA_character_
      )
    )
}

all_reviews <- map_dfr(files, read_completed_file) %>%
  filter(!is.na(paperID), paperID != "")

# Protect against an accidental duplicate copy of the same review.
duplicate_review_rows <- all_reviews %>%
  count(paperID, rev1_name, name = "n_rows") %>%
  filter(n_rows > 1)

if (nrow(duplicate_review_rows) > 0) {
  warning(
    "Repeated paperID-reviewer combinations were found. ",
    "They are exported and counted only once in the summaries."
  )
}

reviews <- all_reviews %>%
  arrange(paperID, rev1_name, source_file) %>%
  distinct(paperID, rev1_name, .keep_all = TRUE)


# 3. Screening totals ---------------------------------------------------------

decision_counts <- reviews %>%
  mutate(decision = replace_na(decision, "Missing")) %>%
  count(decision, name = "n_reviews") %>%
  complete(
    decision = c("Accepted", "Rejected", "Missing"),
    fill = list(n_reviews = 0)
  )

paper_summary <- reviews %>%
  group_by(paperID) %>%
  summarise(
    title = first(na.omit(title), default = NA_character_),
    n_reviewers = n_distinct(rev1_name),
    reviewers = paste(sort(unique(rev1_name)), collapse = " | "),
    n_accepted = sum(decision == "Accepted", na.rm = TRUE),
    n_rejected = sum(decision == "Rejected", na.rm = TRUE),
    n_missing = sum(is.na(decision)),
    decisions = paste(sort(unique(na.omit(decision))), collapse = " | "),
    .groups = "drop"
  ) %>%
  mutate(
    agreement_status = case_when(
      n_missing > 0 ~ "Incomplete",
      n_accepted > 0 & n_rejected > 0 ~ "Disagreement",
      n_accepted > 0 ~ "Accepted",
      n_rejected > 0 ~ "Rejected",
      TRUE ~ "Incomplete"
    ),
    proceeds_to_next_phase = if (resolution_policy == "include_if_any_accept") {
      n_accepted > 0
    } else if (resolution_policy == "agreement_only") {
      n_accepted > 0 & n_rejected == 0
    } else {
      rep(NA, n())
    }
  )

paper_status_counts <- paper_summary %>%
  count(agreement_status, name = "n_papers") %>%
  complete(
    agreement_status = c(
      "Accepted", "Rejected", "Disagreement", "Incomplete"
    ),
    fill = list(n_papers = 0)
  )

overall_summary <- tibble(
  metric = c(
    "Files processed",
    "Unique papers in current subset",
    "Individual review decisions",
    "Papers reviewed more than once",
    "Reviewer disagreements",
    "Papers proceeding to next phase",
    "Papers with incomplete decisions",
    "Papers with no decision yet"
  ),
  value = c(
    length(files),
    nrow(paper_summary),
    nrow(reviews),
    sum(paper_summary$n_reviewers > 1),
    sum(paper_summary$agreement_status == "Disagreement"),
    sum(paper_summary$proceeds_to_next_phase, na.rm = TRUE),
    sum(paper_summary$agreement_status == "Incomplete"),
    sum(paper_summary$n_missing == paper_summary$n_reviewers)
  )
)


# 4. Reviewer agreement -------------------------------------------------------

overlap_reviews <- reviews %>%
  semi_join(
    paper_summary %>% filter(n_reviewers > 1),
    by = "paperID"
  )

reviewer_pairs <- overlap_reviews %>%
  select(paperID, rev1_name, decision) %>%
  inner_join(
    overlap_reviews %>%
      select(paperID, rev1_name, decision),
    by = "paperID",
    suffix = c("_1", "_2"),
    relationship = "many-to-many"
  ) %>%
  filter(rev1_name_1 < rev1_name_2) %>%
  mutate(
    pair = paste(rev1_name_1, rev1_name_2, sep = " vs "),
    agrees = !is.na(decision_1) &
      !is.na(decision_2) &
      decision_1 == decision_2
  )

pairwise_agreement <- reviewer_pairs %>%
  group_by(pair, rev1_name_1, rev1_name_2) %>%
  summarise(
    n_shared = n(),
    n_complete = sum(!is.na(decision_1) & !is.na(decision_2)),
    n_agree = sum(agrees),
    percent_agreement = if_else(
      n_complete > 0,
      round(100 * n_agree / n_complete, 1),
      NA_real_
    ),
    .groups = "drop"
  )

disagreement_details <- overlap_reviews %>%
  semi_join(
    paper_summary %>% filter(agreement_status == "Disagreement"),
    by = "paperID"
  ) %>%
  select(any_of(c(
    "paperID", "title", "authors", "year", "rev1_name", "decision",
    "TA_exclCriteria_rev1", "Topic", "TaxaGroup", "source_file"
  ))) %>%
  arrange(paperID, rev1_name)


# 5. Figures ------------------------------------------------------------------

overview_plot_data <- bind_rows(
  overall_summary %>%
    filter(metric %in% c(
      "Unique papers in current subset",
      "Papers proceeding to next phase"
    )),
  decision_counts %>%
    filter(decision %in% c("Accepted", "Rejected")) %>%
    transmute(
      metric = paste(decision, "review decisions"),
      value = n_reviews
    )
) %>%
  mutate(metric = factor(
    metric,
    levels = c(
      "Unique papers in current subset",
      "Accepted review decisions",
      "Rejected review decisions",
      "Papers proceeding to next phase"
    )
  ))

p_overview <- ggplot(overview_plot_data, aes(x = metric, y = 1)) +
  geom_tile(aes(fill = metric), width = 0.94, height = 0.9) +
  geom_text(aes(label = value), size = 13, fontface = "bold", colour = "white") +
  geom_text(
    aes(label = metric),
    y = 0.72,
    size = 4,
    fontface = "bold",
    colour = "white"
  ) +
  scale_fill_manual(values = c(
    "Unique papers in current subset" = "#4D4D4D",
    "Accepted review decisions" = accepted_colour,
    "Rejected review decisions" = rejected_colour,
    "Papers proceeding to next phase" = "#0072B2"
  )) +
  coord_cartesian(ylim = c(0.5, 1.5), clip = "off") +
  labs(
    title = "Title and abstract screening: current subset",
    subtitle = paste("Resolution policy:", resolution_policy),
    x = NULL,
    y = NULL
  ) +
  theme_void(base_size = 13) +
  theme(
    legend.position = "none",
    plot.title = element_text(face = "bold"),
    plot.subtitle = element_text(colour = "grey35")
  )

p_overview

ggsave(
  file.path(output_dir, "screening_overview.png"),
  p_overview,
  width = 11,
  height = 4.5,
  dpi = 300
)

p_status <- ggplot(
  paper_status_counts,
  aes(x = agreement_status, y = n_papers, fill = agreement_status)
) +
  geom_col(width = 0.7) +
  geom_text(aes(label = n_papers), vjust = -0.4, fontface = "bold") +
  scale_fill_manual(values = c(
    "Accepted" = accepted_colour,
    "Rejected" = rejected_colour,
    "Disagreement" = disagreement_colour,
    "Incomplete" = missing_colour
  )) +
  labs(
    title = "Screening outcome by unique Paper ID",
    x = NULL,
    y = "Number of papers"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold"),
    legend.position = "none"
  )

p_status

ggsave(
  file.path(output_dir, "unique_paper_outcomes.png"),
  p_status,
  width = 8,
  height = 6,
  dpi = 300
)

if (nrow(overlap_reviews) > 0) {
  overlap_order <- paper_summary %>%
    filter(n_reviewers > 1) %>%
    arrange(suppressWarnings(as.numeric(paperID)), paperID) %>%
    pull(paperID)

  p_overlap <- overlap_reviews %>%
    mutate(
      paperID = factor(paperID, levels = rev(overlap_order)),
      rev1_name = str_squish(rev1_name)
    ) %>%
    ggplot(aes(x = rev1_name, y = paperID, fill = decision)) +
    geom_tile(color = "white", linewidth = 0.3) +
    scale_fill_manual(
      values = c("Accepted" = accepted_colour, "Rejected" = rejected_colour),
      na.value = missing_colour,
      name = "Decision"
    ) +
    labs(
      title = "Decisions for Paper IDs screened by multiple reviewers",
      x = NULL,
      y = "Paper ID"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      panel.grid = element_blank(),
      plot.title = element_text(face = "bold"),
      legend.position = "right"
    )

  overlap_height <- max(6, min(20, 2 + length(overlap_order) * 0.22))

  ggsave(
    file.path(output_dir, "overlap_decisions_by_reviewer.png"),
    p_overlap,
    width = 12,
    height = overlap_height,
    dpi = 300,
    limitsize = FALSE
  )
  p_overlap
}


# 6. Export results -----------------------------------------------------------

write_xlsx(
  list(
    "overall_summary" = overall_summary,
    "decision_counts_reviews" = decision_counts,
    "paper_status_counts" = paper_status_counts,
    "paper_summary" = paper_summary,
    "reviews_clean" = reviews,
    "disagreement_details" = disagreement_details,
    "pairwise_agreement" = pairwise_agreement,
    "duplicate_review_rows" = duplicate_review_rows
  ),
  file.path(output_dir, "abstract_screening_summary.xlsx")
)

message(
  "Done! Results saved in: ", output_dir, "\n",
  "Unique papers in this subset: ", nrow(paper_summary), "\n",
  "Proceeding to next phase: ",
  sum(paper_summary$proceeds_to_next_phase, na.rm = TRUE), "\n",
  "Disagreements requiring resolution: ",
  sum(paper_summary$agreement_status == "Disagreement")
)
