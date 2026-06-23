# -----------------------------------------------------------------------------

# Title:

#--------------------------------------------------------------------------------
# 03. Compare abstract-screening decisions across reviewers
#--------------------------------------------------------------------------------

library(readxl)
library(dplyr)
library(purrr)
library(tidyr)
library(stringr)
library(writexl)
library(ggplot2)
library(forcats)


# 1. Load data------------------------------------------------------------
# Folder containing all reviewer Excel files

folder_path <- paste0(input_data, "/CriteriaTrial/ParticipantTrial")   

files <- list.files(
  folder_path,
  pattern = "\\.xlsm$",
  full.names = TRUE
)


# 2. Columns to compare ------------------------------------------------------------

compare_cols <- c(
  "TA_decisionRev1",
  "TA_exclCriteria_rev1",
  "Topic",
  "TaxaGroup")

base_cols <- c(
  "paperID", "authors", "year", "title", "abstract",
  "rev1_name", compare_cols)


# 2.1. Function to read each file
read_reviewer_file <- function(file) {
  dat <- read_excel(
    file,
    sheet = "CriteriaTest",
    skip = 2)
  names(dat) <- names(dat) %>%
    str_replace_all("\\s+", " ") %>%
    str_trim()
  dat %>%
    mutate(
      source_file = basename(file),
      across(everything(), ~ as.character(.x)),
      across(all_of(compare_cols), ~ str_squish(.x)))
}

# Combine all reviewer files
all_reviews <- map_dfr(files, read_reviewer_file)
# check reviewers
reviewer_summary <- all_reviews %>%
  count(rev1_name, source_file, name = "n_papers")


# Long format for comparison
reviews_long <- all_reviews %>%
  select(paperID, title, abstract, rev1_name, all_of(compare_cols)) %>%
  pivot_longer(
    cols = all_of(compare_cols),
    names_to = "field",
    values_to = "answer"
  ) %>%
  mutate(
    answer = ifelse(answer == "", NA_character_, answer)
  )


# 2.2. Detect disagreements per paper and field
disagreement_summary <- reviews_long %>%
  group_by(paperID, title, field) %>%
  summarise(n_reviewers = n_distinct(rev1_name),
    n_different_answers = n_distinct(answer, na.rm = TRUE),
    answers_given = paste(
      sort(unique(na.omit(answer))),
      collapse = " | "
    ),
    .groups = "drop"
  ) %>%
  mutate(
    disagreement = n_different_answers > 1
  )


# Detailed disagreement table
disagreement_details <- reviews_long %>%
  inner_join(
    disagreement_summary %>%
      filter(disagreement) %>%
      select(paperID, field),
    by = c("paperID", "field")
  ) %>%
  arrange(paperID, field, rev1_name)


# Wide table: one row per paper-field, one column per reviewer
disagreement_wide <- disagreement_details %>%
  select(paperID, title, field, rev1_name, answer) %>%
  pivot_wider(
    names_from = rev1_name,
    values_from = answer
  ) %>%
  arrange(paperID, field)


# 2.3. Agreement percentage per reviewer and field
majority_answers <- reviews_long %>%
  group_by(paperID, field, answer) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(paperID, field) %>%
  slice_max(n, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  rename(majority_answer = answer)

reviewer_agreement <- reviews_long %>%
  left_join(majority_answers, by = c("paperID", "field")) %>%
  mutate(
    agrees_with_majority = answer == majority_answer
  ) %>%
  group_by(rev1_name, field) %>%
  summarise(
    n_screened = n(),
    n_agree = sum(agrees_with_majority, na.rm = TRUE),
    agreement_percent = round(100 * n_agree / n_screened, 1),
    .groups = "drop"
  ) %>%
  arrange(rev1_name, field)


# 2.4. Personalised feedback: where each reviewer differs
personalised_feedback <- reviews_long %>%
  left_join(majority_answers, by = c("paperID", "field")) %>%
  filter(answer != majority_answer | is.na(answer)) %>%
  select(
    rev1_name,
    paperID,
    title,
    field,
    reviewer_answer = answer,
    majority_answer
  ) %>%
  arrange(rev1_name, field, paperID)


# 2.5. Export everything to Excel
output_file <- file.path(folder_path, "reviewer_agreement_feedback.xlsx")

write_xlsx(
  list(
    "all_reviews_combined" = all_reviews,
    "reviewer_summary" = reviewer_summary,
    "disagreement_summary" = disagreement_summary,
    "disagreement_wide" = disagreement_wide,
    "reviewer_agreement" = reviewer_agreement,
    "personalised_feedback" = personalised_feedback
  ),
  output_file
)

message("Done! File saved here: ", output_file)

# Prepare data
plot_decisions <- all_reviews %>%
  mutate(
    paperID = factor(paperID, levels = sort(unique(as.numeric(paperID)))),
    rev1_name = str_squish(rev1_name),
    TA_decisionRev1 = str_squish(TA_decisionRev1),
    TA_decisionRev1 = case_when(
      str_detect(str_to_lower(TA_decisionRev1), "accept") ~ "Accepted",
      str_detect(str_to_lower(TA_decisionRev1), "reject") ~ "Rejected",
      TRUE ~ NA_character_
    )
  )

# Plot
ggplot(plot_decisions,
       aes(x = rev1_name,
           y = paperID,
           fill = TA_decisionRev1)) +
  geom_tile(color = "white", linewidth = 0.3) +
  scale_fill_manual(
    values = c(
      "Accepted" = "seagreen3",
      "Rejected" = "firebrick3"
    ),
    na.value = "grey80",
    name = "Decision"
  ) +
  labs(
    title = "Accepted vs Rejected decisions across participants",
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

output_file <- file.path(folder_path, "decisions.png")
ggsave(
  filename = output_file,
  width = 12,
  height = 8,
  dpi = 300
)





# ============================================================
# Prepare data
# ============================================================

plot_excl <- all_reviews %>%
  mutate(
    paperID = factor(
      paperID,
      levels = sort(unique(as.numeric(paperID)))
    ),
    
    rev1_name = str_squish(rev1_name),
    
    TA_exclCriteria_rev1 = str_squish(TA_exclCriteria_rev1),
    
    # Replace empty values
    TA_exclCriteria_rev1 = ifelse(
      TA_exclCriteria_rev1 == "",
      "None",
      TA_exclCriteria_rev1
    )
  )

abbrev_excl <- function(x) {
  
  x <- str_squish(x)
  
  x %>%
    str_replace_all("LOCATION", "LOC") %>%
    str_replace_all("NOTOPIC", "TOP") %>%
    str_replace_all("GEAR", "GEAR") %>%
    str_replace_all("TAXA", "TAXA") %>%
    str_replace_all("STUDY_TYPE", "TYPE") %>%
    str_replace_all("DOCUMENT", "DOC") %>%
    str_replace_all("LANGUAGE", "LAN")
}

plot_excl <- plot_excl %>%
  mutate(
    excl_short = abbrev_excl(TA_exclCriteria_rev1),
    
    # Empty strings -> NA
    excl_short = na_if(excl_short, "")
  )
# ============================================================
# Plot
# ============================================================

ggplot(plot_excl,
       aes(x = rev1_name,
           y = paperID,
           fill = excl_short)) +
  
  geom_tile(color = "white", linewidth = 0.3) +
  geom_text(
    aes(label = excl_short),
    size = 3
  ) +
  scale_fill_discrete(
    na.value = "grey70"
  ) +
  labs(
    title = "Exclusion criteria used across participants",
    x = NULL,
    y = "Paper ID",
    fill = "Exclusion criterion"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid = element_blank(),
    legend.position = "none"
  )


output_file <- file.path(folder_path, "criteria_noleg.png")
ggsave(
  filename = output_file,
  width = 10.7,
  height = 8,
  dpi = 300
)


# ============================================================
# Exclusion criteria hierarchy
# ============================================================

criteria_hierarchy <- c(
  "LANGUAGE",
  "DOCUMENT",
  "NOTOPIC",
  "LOCATION",
  "GEAR",
  "TAXA",
  "STUDY_TYPE"
)

# ============================================================
# Function to keep only the highest-priority criterion
# ============================================================

select_hierarchical_criterion <- function(x) {
  
  if (is.na(x) || str_squish(x) == "") {
    return(NA_character_)
  }
  
  # Split combinations such as "LOCATION / NOTOPIC / TAXA"
  criteria_present <- x %>%
    str_squish() %>%
    str_split("\\s*/\\s*") %>%
    unlist()
  
  # Return the first criterion according to the hierarchy
  selected <- criteria_hierarchy[criteria_hierarchy %in% criteria_present]
  
  if (length(selected) == 0) {
    return(NA_character_)
  } else {
    return(selected[1])
  }
}

# ============================================================
# Apply to trial dataset
# ============================================================

all_reviews_hierarchical <- all_reviews %>%
  mutate(
    TA_exclCriteria_original = TA_exclCriteria_rev1,
    TA_exclCriteria_rev1 = map_chr(
      TA_exclCriteria_rev1,
      select_hierarchical_criterion
    )
  )

# ============================================================
# Prepare plotting dataset
# ============================================================

plot_excl_hier <- all_reviews_hierarchical %>%
  mutate(
    paperID = factor(
      paperID,
      levels = sort(unique(as.numeric(paperID)))
    ),
    
    rev1_name = str_squish(rev1_name),
    
    TA_exclCriteria_rev1 = str_squish(TA_exclCriteria_rev1)
  )

# ============================================================
# Abbreviations
# ============================================================

abbrev_excl <- function(x) {
  
  x %>%
    str_replace_all("LOCATION", "LOC") %>%
    str_replace_all("NOTOPIC", "TOP") %>%
    str_replace_all("GEAR", "GEAR") %>%
    str_replace_all("TAXA", "TAX") %>%
    str_replace_all("STUDY_TYPE", "TYPE") %>%
    str_replace_all("DOCUMENT", "DOC") %>%
    str_replace_all("LANGUAGE", "LAN")
}

plot_excl_hier <- plot_excl_hier %>%
  mutate(
    excl_short = abbrev_excl(TA_exclCriteria_rev1),
    excl_short = na_if(excl_short, "")
  )

# ============================================================
# Plot
# ============================================================

ggplot(plot_excl_hier,
       aes(x = rev1_name,
           y = paperID,
           fill = excl_short)) +
  
  geom_tile(color = "white", linewidth = 0.3) +
  
  geom_text(
    aes(label = excl_short),
    size = 3
  ) +
  
  scale_fill_manual(
    values = c(
      "GEAR" = "#F8766D",
      "LOC" = "#D89000",
      "TOP" = "#00BFC4",
      "TAX" = "#E76BF3",
      "TYPE" = "#C77CFF",
      "DOC" = "#7CAE00",
      "LAN" = "#619CFF"
    ),
    na.value = "grey70"
  ) +
  
  labs(
    title = "Hierarchical exclusion criteria across participants",
    x = NULL,
    y = "Paper ID"
  ) +
  
  theme_minimal(base_size = 13) +
  
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid = element_blank(),
    legend.position = "none"
  )

# ============================================================
# Save
# ============================================================

output_file <- file.path(
  folder_path,
  "criteria_hierarchical_noleg.png"
)

ggsave(
  filename = output_file,
  width = 7,
  height = 8,
  dpi = 300
)




#-----REMVOE COLOUR FROM THOSE THAT ARE FORCED TO BE ACCEPTED-------------------
plot_excl_hier <- plot_excl_hier %>%
  mutate(
    label_plot = ifelse(
      paperID %in% c("559", "327", "24", "21", "17", "16"),
      "",
      excl_short
    )
  )


ggplot(plot_excl_hier,
       aes(x = rev1_name,
           y = paperID,
           fill = fill_plot)) +
  
  geom_tile(color = "white", linewidth = 0.3) +
  
  geom_text(
    aes(label = label_plot),
    size = 3
  ) +
  
  scale_fill_manual(
    values = c(
      "GEAR" = "#F8766D",
      "LOC" = "#D89000",
      "TOP" = "#00BFC4",
      "TAX" = "#E76BF3",
      "TYPE" = "#C77CFF",
      "DOC" = "#7CAE00",
      "LAN" = "#619CFF",
      "SPECIAL_GREY" = "grey70"
    ),
    na.value = "grey70"
  ) +
  
  labs(
    title = "Hierarchical exclusion criteria across participants",
    x = NULL,
    y = "Paper ID"
  ) +
  
  theme_minimal(base_size = 13) +
  
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid = element_blank(),
    legend.position = "none"
  )

output_file <- file.path(
  folder_path,
  "criteria_hierarchical_noleg.png"
)

ggsave(
  filename = output_file,
  width = 7,
  height = 8,
  dpi = 300
)


### PLOT NUMBER OF DISAGREEMENTS
# Count majority decision per paper
paper_disagreement <- plot_decisions %>%
  filter(!is.na(TA_decisionRev1)) %>%
  group_by(paperID, TA_decisionRev1) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(paperID) %>%
  mutate(
    total_reviewers = sum(n),
    majority_n = max(n),
    n_disagree = total_reviewers - majority_n,
    disagreement_percent = round(100 * n_disagree / total_reviewers, 1)
  ) %>%
  slice_max(n, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  mutate(
    paperID = reorder(paperID, n_disagree)
  )

ggplot(paper_disagreement,
       aes(x = n_disagree,
           y = paperID)) +
  
  geom_col(
    fill = "steelblue",
    width = 0.75
  ) +
  
  geom_text(
    aes(label = paste0(n_disagree, "/", total_reviewers)),
    hjust = -0.15,
    size = 3.8
  ) +
  
  scale_x_continuous(
    breaks = 0:max(paper_disagreement$total_reviewers),
    limits = c(0, max(paper_disagreement$n_disagree) + 0.8)
  ) +
  
  labs(
    title = "Disagreement with the majority decision per paper",
    subtitle = "Number of reviewers whose decision differed from the majority",
    x = "Number of reviewers disagreeing",
    y = "Paper ID"
  ) +
  
  theme_minimal(base_size = 14) +
  
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", size = 16),
    plot.subtitle = element_text(size = 12),
    axis.title.y = element_text(margin = margin(r = 10)),
    axis.title.x = element_text(margin = margin(t = 10))
  )

ggsave(
  file.path(folder_path, "decision_disagreement_per_paper_pretty.png"),
  width = 8.5,
  height = 8,
  dpi = 300
)



disagreement_distribution <- paper_disagreement %>%
  mutate(
    disagreement_label = paste0(n_disagree, "/", total_reviewers),
    disagreement_label = factor(
      disagreement_label,
      levels = c("0/10", "1/10", "2/10", "3/10", "4/10", "5/10")
    )
  ) %>%
  count(disagreement_label, name = "n_papers")

ggplot(disagreement_distribution,
       aes(x = disagreement_label,
           y = n_papers)) +
  
  geom_col(
    fill = "steelblue",
    width = 0.65
  ) +
  
  geom_text(
    aes(label = n_papers),
    vjust = -0.4,
    size = 5
  ) +
  
  scale_y_continuous(
    limits = c(0, max(disagreement_distribution$n_papers) + 3),
    breaks = seq(0, 40, by = 5)
  ) +
  
  labs(
    title = "Distribution of reviewer disagreement across papers",
    subtitle = "Number of papers by disagreement level",
    x = "Reviewers disagreeing with the majority decision",
    y = "Number of papers"
  ) +
  
  theme_minimal(base_size = 14) +
  
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", size = 16)
  )

ggsave(
  file.path(folder_path, "decision_disagreement_distribution.png"),
  width = 7,
  height = 5,
  dpi = 300
)
