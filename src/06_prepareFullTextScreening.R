# -----------------------------------------------------------------------------

# Title:

#--------------------------------------------------------------------------------
# 06. Summarise final abstract screening and prepare full-text assignments
#--------------------------------------------------------------------------------

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(writexl)


# 1. Settings -----------------------------------------------------------------

screening_file <- file.path(
  output_data,
  "abstract_screening",
  "abstract_screening_final.xlsx"
)

topic_assignment_file <- file.path(
  output_data,
  "abstract_screening_topic_assignments.xlsx"
)

gold_papers_file <- file.path(
  input_data,
  "rm_duplicates",
  "goldPapers.xlsx"
)

output_dir <- file.path(output_data, "full_text_screening")
topic_output_dir <- file.path(output_dir, "by_topic")

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(topic_output_dir, showWarnings = FALSE, recursive = TRUE)

accepted_colour <- "seagreen3"
rejected_colour <- "firebrick3"
unclassified_colour <- "grey70"

valid_topics <- c(
  "Fishing effort", "IUU fishing", "Megafauna catch", "Ghost gear"
)


# 2. Read final abstract-screening dataset ------------------------------------

if (!file.exists(screening_file)) {
  stop(
    "Final abstract-screening workbook not found at: ", screening_file,
    "\nRun src/05_summariseAbstractScreening.R first."
  )
}

if (!"final_screening" %in% excel_sheets(screening_file)) {
  stop(
    basename(screening_file),
    " must contain a worksheet named final_screening."
  )
}

final_screening <- read_excel(
  screening_file,
  sheet = "final_screening"
) %>%
  mutate(
    across(everything(), as.character),
    paperID = str_squish(paperID),
    final_decision = str_squish(final_decision)
  )

required_columns <- c(
  "paperID", "final_decision", "TA_exclCriteria_final", "Topic_final",
  "TaxaGroup_final", "fishingGear_final"
)

missing_columns <- setdiff(required_columns, names(final_screening))

if (length(missing_columns) > 0) {
  stop(
    "Missing required column(s) in ", basename(screening_file), ": ",
    paste(missing_columns, collapse = ", ")
  )
}

invalid_final_decisions <- final_screening %>%
  filter(
    is.na(final_decision) |
      !final_decision %in% c("Accepted", "Rejected")
  )

if (nrow(invalid_final_decisions) > 0) {
  stop(
    "Every paper must have Accepted or Rejected in final_decision. ",
    "Check Paper ID(s): ",
    paste(invalid_final_decisions$paperID, collapse = ", ")
  )
}


# 3. Homogenise final categories ---------------------------------------------

clean_category <- function(x) {
  x %>%
    str_replace_all("\u00a0", " ") %>%
    str_squish() %>%
    na_if("")
}

clean_doi <- function(x) {
  x %>%
    str_to_lower() %>%
    str_squish() %>%
    str_remove("^doi\\s*:\\s*") %>%
    str_remove("^https?://(dx\\.)?doi\\.org/") %>%
    str_remove("[\\s\\.;,\\)]+$") %>%
    na_if("")
}

normalise_exclusion <- function(x) {
  x_clean <- x %>%
    clean_category() %>%
    str_to_upper() %>%
    str_replace_all("[- ]", "_")

  case_when(
    x_clean == "STUDYTYPE" ~ "STUDY_TYPE",
    TRUE ~ x_clean
  )
}

normalise_topic <- function(x) {
  x_clean <- x %>% clean_category() %>% str_to_lower()

  case_when(
    x_clean == "fishing effort" ~ "Fishing effort",
    x_clean %in% c("iuu", "iuu fishing") ~ "IUU fishing",
    x_clean == "megafauna catch" ~ "Megafauna catch",
    x_clean == "ghost gear" ~ "Ghost gear",
    TRUE ~ clean_category(x)
  )
}

normalise_taxa <- function(x) {
  x_clean <- x %>% clean_category() %>% str_to_lower()

  case_when(
    x_clean %in% c("chondrichthyan", "chondrichthyans") ~
      "Chondrichthyans",
    x_clean %in% c("sea bird", "sea birds", "seabird", "seabirds") ~
      "Seabirds",
    x_clean %in% c("sea turtle", "sea turtles") ~ "Sea turtles",
    x_clean %in% c(
      "cetacean", "cetaceans", "marine mammal", "marine mammals"
    ) ~ "Marine mammals",
    TRUE ~ clean_category(x)
  )
}

normalise_gear <- function(x) {
  x_clean <- x %>% clean_category() %>% str_to_lower()

  case_when(
    x_clean %in% c("longline", "longlines") ~ "Longline",
    x_clean == "trawl" ~ "Trawl",
    x_clean %in% c("purse seine", "purse-seine") ~ "Purse seine",
    TRUE ~ clean_category(x)
  )
}

# Multiple selections are expanded so one paper can contribute to more than
# one category (for example, "Longline, Trawl").
expand_categories <- function(data, column, normalise_function) {
  data %>%
    transmute(
      paperID,
      category = clean_category(.data[[column]]) %>%
        str_replace_all("\\s*[/;|]\\s*", ",")
    ) %>%
    separate_longer_delim(category, delim = ",") %>%
    mutate(category = normalise_function(category)) %>%
    filter(!is.na(category)) %>%
    distinct(paperID, category)
}

audit_categories <- function(
    data,
    column,
    variable,
    normalise_function,
    missing_label = "Unclassified") {
  data %>%
    transmute(
      paperID,
      original_category = clean_category(.data[[column]]) %>%
        replace_na(missing_label) %>%
        str_replace_all("\\s*[/;|]\\s*", ",")
    ) %>%
    separate_longer_delim(original_category, delim = ",") %>%
    mutate(
      original_category = clean_category(original_category),
      standardised_category = if_else(
        original_category == missing_label,
        missing_label,
        normalise_function(original_category)
      ),
      variable = variable
    ) %>%
    count(
      variable, original_category, standardised_category,
      name = "n_papers",
      sort = TRUE
    )
}

add_unclassified <- function(
    category_data,
    scope_data,
    missing_label = "Unclassified") {
  unclassified <- scope_data %>%
    distinct(paperID) %>%
    anti_join(category_data %>% distinct(paperID), by = "paperID") %>%
    mutate(category = missing_label)

  bind_rows(category_data, unclassified)
}

accepted_papers <- final_screening %>%
  filter(final_decision == "Accepted")

rejected_papers <- final_screening %>%
  filter(final_decision == "Rejected")

# Topic assignments are kept in a separate manual workbook, following the same
# principle as reviewer 3 adjudication: the script creates the template once
# and never overwrites it.
original_missing_topic_ids <- accepted_papers %>%
  filter(is.na(clean_category(Topic_final))) %>%
  pull(paperID)

if (file.exists(topic_assignment_file)) {
  if (!"topic_assignments" %in% excel_sheets(topic_assignment_file)) {
    stop(
      basename(topic_assignment_file),
      " must contain a worksheet named topic_assignments."
    )
  }

  topic_assignments <- read_excel(
    topic_assignment_file,
    sheet = "topic_assignments",
    col_types = "text"
  )

  required_assignment_columns <- c(
    "paperID", "Topic_assignment", "Topic_assignment_notes",
    "TaxaGroup_assignment", "fishingGear_assignment"
  )
  missing_assignment_columns <- setdiff(
    required_assignment_columns,
    names(topic_assignments)
  )

  if (length(missing_assignment_columns) > 0) {
    stop(
      "Missing topic-assignment column(s): ",
      paste(missing_assignment_columns, collapse = ", ")
    )
  }

  topic_assignments <- topic_assignments %>%
    transmute(
      paperID = str_squish(paperID),
      Topic_assignment = normalise_topic(Topic_assignment),
      Topic_assignment_notes = clean_category(Topic_assignment_notes),
      TaxaGroup_assignment = clean_category(TaxaGroup_assignment),
      fishingGear_assignment = clean_category(fishingGear_assignment)
    ) %>%
    filter(!is.na(paperID))

  duplicated_assignment_ids <- topic_assignments %>%
    count(paperID, name = "n_rows") %>%
    filter(n_rows > 1)

  if (nrow(duplicated_assignment_ids) > 0) {
    stop(
      "Topic assignments must contain one row per Paper ID. Duplicate(s): ",
      paste(duplicated_assignment_ids$paperID, collapse = ", ")
    )
  }

  unknown_assignment_ids <- setdiff(
    topic_assignments$paperID,
    original_missing_topic_ids
  )

  if (length(unknown_assignment_ids) > 0) {
    stop(
      "Topic assignments were supplied for Paper IDs that do not require ",
      "them: ", paste(unknown_assignment_ids, collapse = ", ")
    )
  }

  invalid_topic_assignments <- topic_assignments %>%
    filter(
      !is.na(Topic_assignment),
      !Topic_assignment %in% valid_topics
    )

  if (nrow(invalid_topic_assignments) > 0) {
    stop(
      "Topic_assignment must be one of: ",
      paste(valid_topics, collapse = ", "),
      ". Check Paper ID(s): ",
      paste(invalid_topic_assignments$paperID, collapse = ", ")
    )
  }
} else {
  topic_assignments <- tibble(
    paperID = character(),
    Topic_assignment = character(),
    Topic_assignment_notes = character(),
    TaxaGroup_assignment = character(),
    fishingGear_assignment = character()
  )
}

accepted_papers <- accepted_papers %>%
  left_join(topic_assignments, by = "paperID") %>%
  mutate(
    Topic_final_original = Topic_final,
    TaxaGroup_final_original = TaxaGroup_final,
    fishingGear_final_original = fishingGear_final,
    Topic_for_full_text = coalesce(Topic_assignment, Topic_final),
    TaxaGroup_for_full_text = coalesce(
      TaxaGroup_assignment,
      TaxaGroup_final
    ),
    fishingGear_for_full_text = coalesce(
      fishingGear_assignment,
      fishingGear_final
    )
  )

topic_assignment_required <- accepted_papers %>%
  filter(is.na(clean_category(Topic_for_full_text))) %>%
  select(any_of(c(
    "paperID", "title", "abstract", "keywords", "authors", "year", "doi",
    "reviewer_1", "Topic_reviewer_1", "reviewer_2", "Topic_reviewer_2",
    "reviewer_3", "Topic_reviewer_3",
    "Topic_assignment", "Topic_assignment_notes",
    "TaxaGroup_assignment", "fishingGear_assignment"
  ))) %>%
  arrange(suppressWarnings(as.numeric(paperID)), paperID)

if (!file.exists(topic_assignment_file) &&
    nrow(topic_assignment_required) > 0) {
  write_xlsx(
    list("topic_assignments" = topic_assignment_required),
    topic_assignment_file
  )

  message(
    "Topic-assignment template created at: ", topic_assignment_file, "\n",
    "Complete Topic_assignment and rerun this script."
  )
}

exclusion_membership <- rejected_papers %>%
  expand_categories("TA_exclCriteria_final", normalise_exclusion) %>%
  add_unclassified(rejected_papers)

topic_membership <- accepted_papers %>%
  expand_categories("Topic_for_full_text", normalise_topic) %>%
  add_unclassified(accepted_papers, "Unspecified")

# Taxonomic-group summaries are meaningful only for papers classified under
# Megafauna catch.
megafauna_papers <- accepted_papers %>%
  semi_join(
    topic_membership %>% filter(category == "Megafauna catch"),
    by = "paperID"
  )

taxa_membership <- megafauna_papers %>%
  expand_categories("TaxaGroup_for_full_text", normalise_taxa) %>%
  add_unclassified(megafauna_papers)

gear_membership <- accepted_papers %>%
  expand_categories("fishingGear_for_full_text", normalise_gear) %>%
  add_unclassified(accepted_papers)

category_counts <- list(
  "Exclusion criteria" = exclusion_membership,
  "Topic" = topic_membership,
  "Taxonomic group" = taxa_membership,
  "Fishing gear" = gear_membership
) %>%
  lapply(\(x) {
    x %>%
      count(category, name = "n_papers", sort = TRUE)
  })

category_standardisation_audit <- bind_rows(
  audit_categories(
    rejected_papers,
    "TA_exclCriteria_final",
    "Exclusion criteria",
    normalise_exclusion
  ),
  audit_categories(
    accepted_papers,
    "Topic_for_full_text",
    "Topic",
    normalise_topic,
    missing_label = "Unspecified"
  ),
  audit_categories(
    megafauna_papers,
    "TaxaGroup_for_full_text",
    "Taxonomic group",
    normalise_taxa
  ),
  audit_categories(
    accepted_papers,
    "fishingGear_for_full_text",
    "Fishing gear",
    normalise_gear
  )
)


# 4. Audit gold papers --------------------------------------------------------

if (file.exists(gold_papers_file)) {
  gold_papers <- read_excel(gold_papers_file) %>%
    transmute(
      gold_category = clean_category(gold_category),
      doi = clean_doi(doi)
    ) %>%
    filter(!is.na(doi)) %>%
    distinct(gold_category, doi)

  duplicate_screening_dois <- final_screening %>%
    transmute(doi = clean_doi(doi)) %>%
    filter(!is.na(doi)) %>%
    count(doi, name = "n_rows") %>%
    filter(n_rows > 1)

  if (nrow(duplicate_screening_dois) > 0) {
    stop(
      "Duplicated DOI(s) prevent an unambiguous gold-paper audit: ",
      paste(duplicate_screening_dois$doi, collapse = ", ")
    )
  }

  gold_audit <- gold_papers %>%
    group_by(doi) %>%
    summarise(
      gold_categories = paste(sort(unique(gold_category)), collapse = ", "),
      .groups = "drop"
    ) %>%
    left_join(
      final_screening %>%
        transmute(
          paperID,
          doi = clean_doi(doi),
          title,
          final_decision,
          TA_exclCriteria_final,
          Topic_for_screening = Topic_final,
          TaxaGroup_for_screening = TaxaGroup_final,
          fishingGear_for_screening = fishingGear_final
        ) %>%
        filter(!is.na(doi)),
      by = "doi"
    ) %>%
    mutate(
      gold_screening_status = case_when(
        is.na(paperID) ~ "Not found in screening dataset",
        final_decision == "Accepted" ~ "Accepted",
        final_decision == "Rejected" ~ "Rejected",
        TRUE ~ "Missing final decision"
      )
    ) %>%
    arrange(gold_screening_status, gold_categories, doi)

  gold_summary <- gold_audit %>%
    count(gold_screening_status, name = "n_gold_papers") %>%
    complete(
      gold_screening_status = c(
        "Accepted", "Rejected", "Not found in screening dataset",
        "Missing final decision"
      ),
      fill = list(n_gold_papers = 0)
    )

  gold_attention <- gold_audit %>%
    filter(gold_screening_status != "Accepted")

  if (nrow(gold_attention) > 0) {
    warning(
      nrow(gold_attention),
      " gold paper(s) were not accepted. Review: ",
      paste(gold_attention$doi, collapse = ", ")
    )
  }
} else {
  warning(
    "Gold-paper file not found at: ", gold_papers_file, "\n",
    "Rerun src/02_Handling_RIS.R to create it, then rerun this script."
  )

  gold_audit <- tibble()
  gold_summary <- tibble()
  gold_attention <- tibble()
}


# 5. Category plots -----------------------------------------------------------

plot_category_counts <- function(count_data, title, subtitle, colour, filename) {
  plot_data <- count_data %>%
    mutate(category = reorder(category, n_papers))

  p <- ggplot(plot_data, aes(x = category, y = n_papers)) +
    geom_col(
      aes(fill = category %in% c("Unclassified", "Unspecified")),
      width = 0.7
    ) +
    geom_text(
      aes(label = n_papers),
      hjust = -0.15,
      fontface = "bold",
      size = 4
    ) +
    coord_flip(clip = "off") +
    scale_fill_manual(
      values = c("FALSE" = colour, "TRUE" = unclassified_colour)
    ) +
    scale_y_continuous(
      expand = expansion(mult = c(0, 0.12))
    ) +
    labs(
      title = title,
      subtitle = subtitle,
      x = NULL,
      y = "Number of unique papers"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank(),
      plot.title = element_text(face = "bold"),
      legend.position = "none"
    )

  ggsave(
    file.path(output_dir, filename),
    p,
    width = 9,
    height = max(5, 2.5 + 0.45 * nrow(count_data)),
    dpi = 300,
    limitsize = FALSE
  )

  p
}

p_exclusion <- plot_category_counts(
  category_counts[["Exclusion criteria"]],
  "Rejected papers by exclusion criterion",
  "Final adjudicated decisions",
  rejected_colour,
  "papers_by_exclusion_criterion.png"
)

p_topic <- plot_category_counts(
  category_counts[["Topic"]],
  "Accepted papers by topic",
  "A paper can contribute to more than one category",
  accepted_colour,
  "accepted_papers_by_topic.png"
)

p_taxa <- plot_category_counts(
  category_counts[["Taxonomic group"]],
  "Accepted papers by taxonomic group",
  "Only papers classified as Megafauna catch",
  accepted_colour,
  "accepted_papers_by_taxonomic_group.png"
)

p_gear <- plot_category_counts(
  category_counts[["Fishing gear"]],
  "Accepted papers by fishing gear",
  "A paper can contribute to more than one category",
  accepted_colour,
  "accepted_papers_by_fishing_gear.png"
)

if (nrow(gold_summary) > 0) {
  p_gold <- gold_summary %>%
    mutate(
      gold_screening_status = factor(
        gold_screening_status,
        levels = c(
          "Accepted", "Rejected", "Not found in screening dataset",
          "Missing final decision"
        )
      )
    ) %>%
    ggplot(aes(x = gold_screening_status, y = n_gold_papers)) +
    geom_col(aes(fill = gold_screening_status), width = 0.7) +
    geom_text(
      aes(label = n_gold_papers),
      vjust = -0.35,
      fontface = "bold"
    ) +
    scale_fill_manual(values = c(
      "Accepted" = accepted_colour,
      "Rejected" = rejected_colour,
      "Not found in screening dataset" = unclassified_colour,
      "Missing final decision" = "#E69F00"
    )) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
    labs(
      title = "Screening outcomes for gold papers",
      x = NULL,
      y = "Number of unique gold papers"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      axis.text.x = element_text(angle = 25, hjust = 1),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      plot.title = element_text(face = "bold"),
      legend.position = "none"
    )

  ggsave(
    file.path(output_dir, "gold_paper_screening_outcomes.png"),
    p_gold,
    width = 9,
    height = 6,
    dpi = 300
  )
}


# 6. Prepare accepted papers for full-text assignment -------------------------

collapse_membership <- function(data, output_column) {
  data %>%
    group_by(paperID) %>%
    summarise(
      "{output_column}" := paste(sort(category), collapse = ", "),
      .groups = "drop"
    )
}

accepted_full_text <- accepted_papers %>%
  left_join(
    collapse_membership(topic_membership, "Topic_standardised"),
    by = "paperID"
  ) %>%
  left_join(
    collapse_membership(taxa_membership, "TaxaGroup_standardised"),
    by = "paperID"
  ) %>%
  left_join(
    collapse_membership(gear_membership, "fishingGear_standardised"),
    by = "paperID"
  ) %>%
  mutate(
    full_text_reviewer_1 = NA_character_,
    full_text_reviewer_2 = NA_character_,
    full_text_status = NA_character_,
    full_text_notes = NA_character_
  ) %>%
  relocate(
    paperID, title, abstract, keywords,
    Topic_standardised, TaxaGroup_standardised, fishingGear_standardised,
    full_text_reviewer_1, full_text_reviewer_2,
    full_text_status, full_text_notes
  ) %>%
  arrange(suppressWarnings(as.numeric(paperID)), paperID)

write_xlsx(
  list("accepted_papers" = accepted_full_text),
  file.path(output_dir, "accepted_full_text_all.xlsx")
)

safe_filename <- function(x) {
  x %>%
    str_to_lower() %>%
    str_replace_all("[^a-z0-9]+", "_") %>%
    str_remove_all("^_|_$")
}

topic_categories <- topic_membership$category %>%
  unique() %>%
  setdiff("Unspecified") %>%
  sort()

for (topic_name in topic_categories) {
  topic_papers <- topic_membership %>%
    filter(category == topic_name) %>%
    select(paperID) %>%
    inner_join(accepted_full_text, by = "paperID") %>%
    arrange(suppressWarnings(as.numeric(paperID)), paperID)

  write_xlsx(
    list("accepted_papers" = topic_papers),
    file.path(
      topic_output_dir,
      paste0("full_text_", safe_filename(topic_name), ".xlsx")
    )
  )
}

write_xlsx(
  c(
    category_counts,
    list("Standardisation audit" = category_standardisation_audit)
  ),
  file.path(output_dir, "final_screening_category_counts.xlsx")
)

if (nrow(gold_audit) > 0) {
  write_xlsx(
    list(
      "summary" = gold_summary,
      "gold_papers" = gold_audit,
      "requires_attention" = gold_attention
    ),
    file.path(output_dir, "gold_paper_screening_audit.xlsx")
  )
}

message(
  "Done! Full-text screening files saved in: ", output_dir, "\n",
  "Accepted papers: ", nrow(accepted_papers), "\n",
  "Rejected papers: ", nrow(rejected_papers), "\n",
  "Topic workbooks created: ", length(topic_categories), "\n",
  "Accepted papers still requiring a topic: ",
  nrow(topic_assignment_required), "\n",
  "Gold papers requiring attention: ", nrow(gold_attention)
)
