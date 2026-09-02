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

# Reviewer 3 completes this workbook manually. It is kept separate from the
# final output so rerunning the script never overwrites the adjudications.
adjudicator_name <- "DRG"
reviewer3_file <- file.path(
  output_data,
  "abstract_screening/abstract_screening_reviewer3.xlsx"
)

adjudication_columns <- c(
  "paperID", "reviewer_3", "decision_reviewer_3",
  "TA_exclCriteria_reviewer_3", "notes_reviewer_3",
  "Topic_reviewer_3", "TaxaGroup_reviewer_3",
  "fishingGear_reviewer_3"
)


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

# Standardise reviewer answers before comparing them. Slash-separated multiple
# selections are sorted so that different ordering does not create a false
# disagreement.
normalise_for_comparison <- function(x) {
  map_chr(x, function(value) {
    if (is.na(value) || str_squish(value) == "") {
      return(NA_character_)
    }

    value %>%
      str_split("\\s*/\\s*") %>%
      unlist() %>%
      str_squish() %>%
      str_to_lower() %>%
      unique() %>%
      sort() %>%
      paste(collapse = " / ")
  })
}

has_disagreement <- function(value_1, value_2, reviewer_2) {
  value_1_clean <- normalise_for_comparison(value_1) %>%
    replace_na("<missing>")
  value_2_clean <- normalise_for_comparison(value_2) %>%
    replace_na("<missing>")

  !is.na(reviewer_2) & value_1_clean != value_2_clean
}

clean_manual_value <- function(x) {
  x %>%
    as.character() %>%
    str_replace_all("\u00a0", " ") %>%
    str_squish() %>%
    na_if("")
}

if (file.exists(reviewer3_file)) {
  reviewer3_sheets <- excel_sheets(reviewer3_file)

  if (!"final_screening" %in% reviewer3_sheets) {
    stop(
      basename(reviewer3_file),
      " must contain a worksheet named final_screening."
    )
  }

  adjudication_decisions <- read_excel(
    reviewer3_file,
    sheet = "final_screening",
    col_types = "text"
  )
  names(adjudication_decisions) <- clean_names(
    names(adjudication_decisions)
  )

  missing_adjudication_columns <- setdiff(
    adjudication_columns,
    names(adjudication_decisions)
  )

  if (length(missing_adjudication_columns) > 0) {
    stop(
      "Missing reviewer 3 column(s) in ", basename(reviewer3_file), ": ",
      paste(missing_adjudication_columns, collapse = ", ")
    )
  }

  adjudication_decisions <- adjudication_decisions %>%
    select(all_of(adjudication_columns)) %>%
    mutate(across(everything(), clean_manual_value)) %>%
    filter(
      !is.na(reviewer_3) |
        if_any(-paperID, ~ !is.na(.x))
    )

  duplicated_adjudication_ids <- adjudication_decisions %>%
    count(paperID, name = "n_rows") %>%
    filter(is.na(paperID) | n_rows > 1)

  if (nrow(duplicated_adjudication_ids) > 0) {
    stop(
      "Reviewer 3 adjudications must have one non-missing row per Paper ID."
    )
  }
} else {
  adjudication_decisions <- tibble(
    paperID = character(),
    reviewer_3 = character(),
    decision_reviewer_3 = character(),
    TA_exclCriteria_reviewer_3 = character(),
    notes_reviewer_3 = character(),
    Topic_reviewer_3 = character(),
    TaxaGroup_reviewer_3 = character(),
    fishingGear_reviewer_3 = character()
  )
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
    abstract = first(na.omit(abstract), default = NA_character_),
    keywords = first(na.omit(keywords), default = NA_character_),
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


# 5. Create adjudication and final screening dataset --------------------------

if (any(paper_summary$n_reviewers > 2)) {
  stop(
    "At least one paper has more than two initial reviewers. ",
    "Reviewer 3 is reserved for manual adjudication."
  )
}

valid_adjudication_decisions <- c("Accepted", "Rejected")
invalid_adjudication_decisions <- adjudication_decisions %>%
  filter(
    !is.na(decision_reviewer_3),
    !decision_reviewer_3 %in% valid_adjudication_decisions
  )

if (nrow(invalid_adjudication_decisions) > 0) {
  stop(
    "decision_reviewer_3 must contain only Accepted or Rejected. ",
    "Invalid Paper ID(s): ",
    paste(invalid_adjudication_decisions$paperID, collapse = ", ")
  )
}

reviewer_slots <- reviews %>%
  transmute(
    paperID,
    reviewer_name = rev1_name,
    decision,
    TA_exclCriteria = TA_exclCriteria_rev1,
    notes,
    Topic,
    TaxaGroup,
    fishingGear
  ) %>%
  group_by(paperID) %>%
  arrange(reviewer_name, .by_group = TRUE) %>%
  mutate(reviewer_number = row_number()) %>%
  ungroup() %>%
  pivot_wider(
    id_cols = paperID,
    names_from = reviewer_number,
    values_from = c(
      reviewer_name, decision, TA_exclCriteria, notes,
      Topic, TaxaGroup, fishingGear
    ),
    names_glue = "{.value}_{reviewer_number}"
  ) %>%
  rename(
    reviewer_1 = reviewer_name_1,
    decision_reviewer_1 = decision_1,
    TA_exclCriteria_reviewer_1 = TA_exclCriteria_1,
    notes_reviewer_1 = notes_1,
    Topic_reviewer_1 = Topic_1,
    TaxaGroup_reviewer_1 = TaxaGroup_1,
    fishingGear_reviewer_1 = fishingGear_1,
    reviewer_2 = reviewer_name_2,
    decision_reviewer_2 = decision_2,
    TA_exclCriteria_reviewer_2 = TA_exclCriteria_2,
    notes_reviewer_2 = notes_2,
    Topic_reviewer_2 = Topic_2,
    TaxaGroup_reviewer_2 = TaxaGroup_2,
    fishingGear_reviewer_2 = fishingGear_2
  ) %>%
  mutate(
    disagreement_TA_exclCriteria = has_disagreement(
      TA_exclCriteria_reviewer_1,
      TA_exclCriteria_reviewer_2,
      reviewer_2
    ),
    disagreement_Topic = has_disagreement(
      Topic_reviewer_1,
      Topic_reviewer_2,
      reviewer_2
    ),
    disagreement_TaxaGroup = has_disagreement(
      TaxaGroup_reviewer_1,
      TaxaGroup_reviewer_2,
      reviewer_2
    ),
    disagreement_fishingGear = has_disagreement(
      fishingGear_reviewer_1,
      fishingGear_reviewer_2,
      reviewer_2
    ),
    disagreement_any_variable = disagreement_TA_exclCriteria |
      disagreement_Topic |
      disagreement_TaxaGroup |
      disagreement_fishingGear
  )

required_adjudication_ids <- union(
  paper_summary$paperID[paper_summary$agreement_status == "Disagreement"],
  reviewer_slots$paperID[reviewer_slots$disagreement_any_variable]
)

unknown_adjudication_ids <- setdiff(
  adjudication_decisions$paperID,
  required_adjudication_ids
)

if (length(unknown_adjudication_ids) > 0) {
  stop(
    "Adjudication entries were supplied for Paper IDs without any ",
    "disagreement: ", paste(unknown_adjudication_ids, collapse = ", ")
  )
}

missing_adjudication_ids <- setdiff(
  required_adjudication_ids,
  adjudication_decisions$paperID
)

if (length(missing_adjudication_ids) > 0) {
  warning(
    "Add these Paper IDs to adjudication_decisions to resolve all ",
    "disagreements: ", paste(sort(missing_adjudication_ids), collapse = ", ")
  )
}

metadata_cols <- c(
  "paperID", "authors", "year", "journal", "volume", "issue",
  "start_page", "end_page", "doi", "Language", "document_type", "source",
  "title", "abstract", "keywords"
)

paper_metadata <- reviews %>%
  select(any_of(metadata_cols)) %>%
  distinct(paperID, .keep_all = TRUE)

final_screening <- paper_metadata %>%
  left_join(reviewer_slots, by = "paperID") %>%
  left_join(
    paper_summary %>%
      select(paperID, n_reviewers, agreement_status),
    by = "paperID"
  ) %>%
  mutate(
    requires_adjudication = agreement_status == "Disagreement" |
      disagreement_any_variable
  ) %>%
  left_join(adjudication_decisions, by = "paperID") %>%
  mutate(
    reviewer_3 = if_else(
      requires_adjudication,
      coalesce(reviewer_3, adjudicator_name),
      NA_character_
    ),
    decision_reviewer_3 = if_else(
      requires_adjudication,
      decision_reviewer_3,
      NA_character_
    ),
    TA_exclCriteria_reviewer_3 = if_else(
      requires_adjudication,
      TA_exclCriteria_reviewer_3,
      NA_character_
    ),
    Topic_reviewer_3 = if_else(
      requires_adjudication,
      Topic_reviewer_3,
      NA_character_
    ),
    TaxaGroup_reviewer_3 = if_else(
      requires_adjudication,
      TaxaGroup_reviewer_3,
      NA_character_
    ),
    fishingGear_reviewer_3 = if_else(
      requires_adjudication,
      fishingGear_reviewer_3,
      NA_character_
    ),
    notes_reviewer_3 = if_else(
      requires_adjudication,
      notes_reviewer_3,
      NA_character_
    ),
    final_decision = case_when(
      !is.na(decision_reviewer_3) ~ decision_reviewer_3,
      agreement_status == "Accepted" ~ "Accepted",
      agreement_status == "Rejected" ~ "Rejected",
      TRUE ~ NA_character_
    ),
    TA_exclCriteria_final = case_when(
      final_decision == "Accepted" ~ NA_character_,
      disagreement_TA_exclCriteria &
        !is.na(TA_exclCriteria_reviewer_3) ~ TA_exclCriteria_reviewer_3,
      !disagreement_TA_exclCriteria ~ coalesce(
        TA_exclCriteria_reviewer_1,
        TA_exclCriteria_reviewer_2
      ),
      TRUE ~ NA_character_
    ),
    Topic_final = case_when(
      final_decision == "Rejected" ~ NA_character_,
      disagreement_Topic & !is.na(Topic_reviewer_3) ~ Topic_reviewer_3,
      !disagreement_Topic ~ coalesce(Topic_reviewer_1, Topic_reviewer_2),
      TRUE ~ NA_character_
    ),
    TaxaGroup_final = case_when(
      final_decision == "Rejected" ~ NA_character_,
      disagreement_TaxaGroup &
        !is.na(TaxaGroup_reviewer_3) ~ TaxaGroup_reviewer_3,
      !disagreement_TaxaGroup ~ coalesce(
        TaxaGroup_reviewer_1,
        TaxaGroup_reviewer_2
      ),
      TRUE ~ NA_character_
    ),
    fishingGear_final = case_when(
      final_decision == "Rejected" ~ NA_character_,
      disagreement_fishingGear &
        !is.na(fishingGear_reviewer_3) ~ fishingGear_reviewer_3,
      !disagreement_fishingGear ~ coalesce(
        fishingGear_reviewer_1,
        fishingGear_reviewer_2
      ),
      TRUE ~ NA_character_
    ),
    proceeds_to_next_phase = final_decision == "Accepted"
  ) %>%
  select(
    paperID, title, abstract, keywords, authors, year, journal, volume, issue,
    start_page, end_page, doi, Language, document_type, source,
    reviewer_1, decision_reviewer_1,
    TA_exclCriteria_reviewer_1, notes_reviewer_1, Topic_reviewer_1,
    TaxaGroup_reviewer_1, fishingGear_reviewer_1,
    reviewer_2, decision_reviewer_2,
    TA_exclCriteria_reviewer_2, notes_reviewer_2, Topic_reviewer_2,
    TaxaGroup_reviewer_2, fishingGear_reviewer_2,
    reviewer_3, decision_reviewer_3,
    TA_exclCriteria_reviewer_3, notes_reviewer_3, Topic_reviewer_3,
    TaxaGroup_reviewer_3, fishingGear_reviewer_3,
    disagreement_TA_exclCriteria, disagreement_Topic,
    disagreement_TaxaGroup, disagreement_fishingGear,
    disagreement_any_variable, requires_adjudication,
    n_reviewers, agreement_status,
    final_decision, TA_exclCriteria_final, Topic_final,
    TaxaGroup_final, fishingGear_final, proceeds_to_next_phase
  ) %>%
  arrange(suppressWarnings(as.numeric(paperID)), paperID)

if (file.exists(reviewer3_file)) {
  unresolved_decision_ids <- final_screening %>%
    filter(
      agreement_status == "Disagreement",
      is.na(decision_reviewer_3)
    ) %>%
    pull(paperID)

  if (length(unresolved_decision_ids) > 0) {
    stop(
      "Missing reviewer 3 decision for Paper ID(s): ",
      paste(unresolved_decision_ids, collapse = ", ")
    )
  }
}

# Replace the provisional policy count with the adjudicated result whenever a
# reviewer 3 workbook is available.
overall_summary <- overall_summary %>%
  mutate(
    value = if_else(
      metric == "Papers proceeding to next phase",
      sum(final_screening$proceeds_to_next_phase, na.rm = TRUE),
      value
    )
  )

variable_disagreements <- final_screening %>%
  filter(disagreement_any_variable) %>%
  select(
    paperID, title, abstract, keywords,
    reviewer_1, decision_reviewer_1,
    reviewer_2, decision_reviewer_2,
    disagreement_TA_exclCriteria,
    TA_exclCriteria_reviewer_1, TA_exclCriteria_reviewer_2,
    disagreement_Topic, Topic_reviewer_1, Topic_reviewer_2,
    disagreement_TaxaGroup, TaxaGroup_reviewer_1, TaxaGroup_reviewer_2,
    disagreement_fishingGear,
    fishingGear_reviewer_1, fishingGear_reviewer_2,
    reviewer_3, decision_reviewer_3, notes_reviewer_3,
    TA_exclCriteria_reviewer_3, Topic_reviewer_3,
    TaxaGroup_reviewer_3, fishingGear_reviewer_3,
    TA_exclCriteria_final, Topic_final, TaxaGroup_final, fishingGear_final
  )


# 6. Figures ------------------------------------------------------------------

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

disagreement_reviews <- reviews %>%
  semi_join(
    paper_summary %>% filter(agreement_status == "Disagreement"),
    by = "paperID"
  )

if (nrow(disagreement_reviews) > 0) {
  disagreement_order <- paper_summary %>%
    filter(agreement_status == "Disagreement") %>%
    arrange(suppressWarnings(as.numeric(paperID)), paperID) %>%
    pull(paperID)

  p_disagreement <- disagreement_reviews %>%
    mutate(
      paperID = factor(paperID, levels = rev(disagreement_order)),
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
      title = "Reviewer decisions requiring adjudication",
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

  disagreement_height <- max(
    6,
    min(12, 2 + length(disagreement_order) * 0.30)
  )

  ggsave(
    file.path(output_dir, "overlap_decisions_by_reviewer.png"),
    p_disagreement,
    width = 10,
    height = disagreement_height,
    dpi = 300,
    limitsize = FALSE
  )
  p_disagreement
}


# 7. Export results -----------------------------------------------------------

if (!file.exists(reviewer3_file)) {
  write_xlsx(
    list(
      "final_screening" = final_screening,
      "variable_disagreements" = variable_disagreements
    ),
    reviewer3_file
  )

  message(
    "Reviewer 3 template created at: ", reviewer3_file, "\n",
    "Complete it and rerun the script to apply the adjudications."
  )
}

write_xlsx(
  list(
    "overall_summary" = overall_summary,
    "decision_counts_reviews" = decision_counts,
    "paper_status_counts" = paper_status_counts,
    "paper_summary" = paper_summary,
    "reviews_clean" = reviews,
    "final_screening" = final_screening,
    "variable_disagreements" = variable_disagreements,
    "disagreement_details" = disagreement_details,
    "pairwise_agreement" = pairwise_agreement,
    "duplicate_review_rows" = duplicate_review_rows
  ),
  file.path(output_dir, "abstract_screening_summary.xlsx")
)

# Standalone adjudicated dataset for downstream screening. This never
# overwrites abstract_screening_reviewer3.xlsx.
write_xlsx(
  list(
    "final_screening" = final_screening,
    "variable_disagreements" = variable_disagreements
  ),
  file.path(output_dir, "abstract_screening_final.xlsx")
)

message(
  "Done! Results saved in: ", output_dir, "\n",
  "Unique papers in this subset: ", nrow(paper_summary), "\n",
  "Proceeding to next phase: ",
  sum(final_screening$proceeds_to_next_phase, na.rm = TRUE), "\n",
  "Disagreements requiring resolution: ",
  sum(paper_summary$agreement_status == "Disagreement")
)
