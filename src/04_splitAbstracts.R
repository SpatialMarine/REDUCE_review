# -----------------------------------------------------------------------------

# Title:

#--------------------------------------------------------------------------------
# 04. Split abstract list among participants
#--------------------------------------------------------------------------------
library(readxl)
library(dplyr)

# 1. Load paper list------------------------------------------------------------
list <- read_excel(  file.path(input_data, "rm_duplicates", "paperList.xlsx"))
head(list)

trial <- read_excel(  file.path(input_data, "rm_duplicates", "CriteriaTrial_DRG_completed.xlsm"), sheet = 2)
head(trial)

# Merge results from trial:
list_updated <- list %>%
  left_join(
    trial %>%
      select(
        paperID,
        rev1_name,
        TA_decisionRev1,
        TA_exclCriteria_rev1,
        `notes (column only available in this trial)`,
        Topic,
        TaxaGroup),
    by = "paperID")


# 2. Split them by participants-------------------------------------------------
reviewers <- c(
  "DFF", "ISM", "LNH", "NPS", "PGU", "TM", "EM", 
  "DRG", "CS", "ABC", "AEP", "GA", "DK", "CL")

length(reviewers)
# 14

set.seed(123)
papers <- list_updated  # or your object name

n_papers <- nrow(papers)
n_papers

n_reviewers <- length(reviewers)
n_reviewers

# Number of papers to double-review
n_overlap <- round(n_papers * 0.25)

# Randomise paper order, but keep existing rev1_name where present
papers_split <- papers %>%
  slice_sample(prop = 1)

# Identify papers without assigned reviewer
missing_rev1 <- is.na(papers_split$rev1_name) | papers_split$rev1_name == ""

# Current workload from already assigned papers
current_load <- table(
  factor(papers_split$rev1_name[!missing_rev1], levels = reviewers)
)

# Assign only missing rev1_name, balancing total workload
for(i in which(missing_rev1)) {
  
  chosen_reviewer <- reviewers[which.min(current_load)]
  
  papers_split$rev1_name[i] <- chosen_reviewer
  
  current_load[chosen_reviewer] <- current_load[chosen_reviewer] + 1
}

# Select 25% of papers for second review
overlap_ids <- sample(papers_split$paperID, n_overlap)

# Add second reviewer
papers_split <- papers_split %>%
  mutate(
    rev2_name = NA_character_
  )

# Track workload for reviewer 2
rev2_load <- setNames(rep(0, n_reviewers), reviewers)

for (id in overlap_ids) {
  
  rev1 <- papers_split$rev1_name[papers_split$paperID == id]
  
  possible_rev2 <- reviewers[reviewers != rev1]
  
  # Choose reviewer with lowest current rev2 load
  chosen_rev2 <- possible_rev2[which.min(rev2_load[possible_rev2])]
  
  papers_split$rev2_name[papers_split$paperID == id] <- chosen_rev2
  
  rev2_load[chosen_rev2] <- rev2_load[chosen_rev2] + 1
}

workload <- bind_rows(
  papers_split %>% 
    filter(!is.na(rev1_name)) %>% 
    count(reviewer = rev1_name),
  
  papers_split %>% 
    filter(!is.na(rev2_name)) %>% 
    count(reviewer = rev2_name)
) %>%
  group_by(reviewer) %>%
  summarise(total_abstracts = sum(n), .groups = "drop") %>%
  arrange(reviewer)

workload

# Check overlap
pair_overlap <- papers_split %>%
  filter(!is.na(rev2_name)) %>%
  count(rev1_name, rev2_name, name = "n_shared") %>%
  arrange(desc(n_shared))

pair_overlap

n_papers
n_overlap
sum(!is.na(papers_split$rev2_name))


# Export dataset by reviewer
reviewer_datasets <- lapply(reviewers, function(r) {
  papers_split %>%
    filter(rev1_name == r | rev2_name == r) %>%
    mutate(
      rev1_name = r,
      rev2_name = NA_character_
    )
})

names(reviewer_datasets) <- reviewers
reviewer_datasets[["DRG"]]


# Export
library(writexl)
output_dir <- file.path(input_data, "abstracts_byReviewer")
dir.create(output_dir, showWarnings = FALSE)

for(r in reviewers){
  
  df <- papers_split %>%
    filter(rev1_name == r | rev2_name == r) %>%
    
    # Make all assignments appear as reviewer 1
    mutate(
      rev1_name = r
    ) %>%
    
    # Rename long notes column
    rename(
      notes = `notes (column only available in this trial)`
    ) %>%
    
    # Remove rev2 column
    select(-rev2_name)
  
  write_xlsx(
    df,
    file.path(output_dir, paste0("Abstracts_", r, ".xlsx"))
  )
}
