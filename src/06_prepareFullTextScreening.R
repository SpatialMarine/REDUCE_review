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

output_dir <- file.path(output_data, "full_text_screening")
topic_output_dir <- file.path(output_dir, "by_topic")

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(topic_output_dir, showWarnings = FALSE, recursive = TRUE)

accepted_colour <- "seagreen3"
rejected_colour <- "firebrick3"
unclassified_colour <- "grey70"


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
    x_clean == "iuu fishing" ~ "IUU fishing",
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
    x_clean %in% c("marine mammal", "marine mammals") ~ "Marine mammals",
    TRUE ~ clean_category(x)
  )
}

normalise_gear <- function(x) {
  x_clean <- x %>% clean_category() %>% str_to_lower()

  case_when(
    x_clean == "longline" ~ "Longline",
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

audit_categories <- function(data, column, variable, normalise_function) {
  data %>%
    transmute(
      paperID,
      original_category = clean_category(.data[[column]]) %>%
        replace_na("Unclassified") %>%
        str_replace_all("\\s*[/;|]\\s*", ",")
    ) %>%
    separate_longer_delim(original_category, delim = ",") %>%
    mutate(
      original_category = clean_category(original_category),
      standardised_category = if_else(
        original_category == "Unclassified",
        "Unclassified",
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

add_unclassified <- function(category_data, scope_data) {
  unclassified <- scope_data %>%
    distinct(paperID) %>%
    anti_join(category_data %>% distinct(paperID), by = "paperID") %>%
    mutate(category = "Unclassified")

  bind_rows(category_data, unclassified)
}

accepted_papers <- final_screening %>%
  filter(final_decision == "Accepted")

rejected_papers <- final_screening %>%
  filter(final_decision == "Rejected")

exclusion_membership <- rejected_papers %>%
  expand_categories("TA_exclCriteria_final", normalise_exclusion) %>%
  add_unclassified(rejected_papers)

topic_membership <- accepted_papers %>%
  expand_categories("Topic_final", normalise_topic) %>%
  add_unclassified(accepted_papers)

taxa_membership <- accepted_papers %>%
  expand_categories("TaxaGroup_final", normalise_taxa) %>%
  add_unclassified(accepted_papers)

gear_membership <- accepted_papers %>%
  expand_categories("fishingGear_final", normalise_gear) %>%
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
    "Topic_final",
    "Topic",
    normalise_topic
  ),
  audit_categories(
    accepted_papers,
    "TaxaGroup_final",
    "Taxonomic group",
    normalise_taxa
  ),
  audit_categories(
    accepted_papers,
    "fishingGear_final",
    "Fishing gear",
    normalise_gear
  )
)


# 4. Category plots -----------------------------------------------------------

plot_category_counts <- function(count_data, title, subtitle, colour, filename) {
  plot_data <- count_data %>%
    mutate(category = reorder(category, n_papers))

  p <- ggplot(plot_data, aes(x = category, y = n_papers)) +
    geom_col(aes(fill = category == "Unclassified"), width = 0.7) +
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
  "A paper can contribute to more than one category",
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


# 5. Prepare accepted papers for full-text assignment -------------------------

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

topic_categories <- sort(unique(topic_membership$category))

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

message(
  "Done! Full-text screening files saved in: ", output_dir, "\n",
  "Accepted papers: ", nrow(accepted_papers), "\n",
  "Rejected papers: ", nrow(rejected_papers), "\n",
  "Topic workbooks created: ", length(topic_categories)
)
