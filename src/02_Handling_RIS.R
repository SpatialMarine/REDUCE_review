# -----------------------------------------------------------------------------

# Title:

#--------------------------------------------------------------------------------
# 02. Handling ".ris" data
#--------------------------------------------------------------------------------

# This script imports bibliographic records exported as .ris files from
# Web of Science (WoS) and Scopus for each research question
# and prepares a clean, merged dataset of unique references.
# It also enables to validate search adequacy by checking the presence of predefined “gold” papers.

# Notes --------------------------------------------------
#
# - The script is executed separately for each research question to compare them
#   using their respective WoS and Scopus .ris exports.
# - Deduplication is DOI-based (`distinct(doi, .keep_all = TRUE)`), meaning that:
#   * records missing a DOI are excluded before merging!!!!!!!!!!!!!!
# - DOI cleaning removes common formats that appear in exports:
#   "doi: ...", "https://doi.org/...", and trailing punctuation.
# - `source` is retained to track whether a record came from WoS or Scopus
#   (useful for reporting and audit trails).
# - The “gold DOI” check is a lightweight QA step to confirm that key expected
#   references are captured by the search and survive the cleaning pipeline.
#
# -----------------------------------------------------------------------------

# -------------------------
# Read ris files and remove duplicates
# -------------------------

#######
# RQ1 #
#######

#wos
wos <- synthesisr::read_refs(
  filename   = "C:/Users/lnh88/Dropbox/Projects/ongoing/REDUCE_Milestone/RQ1_WOS.ris",
  tag_naming = "wos",
  return_df  = TRUE,
  verbose    = TRUE) %>%
  dplyr::select(title, DO) %>%
  rename(doi = DO) %>%
  mutate(source = "wos") %>%
  drop_na(doi) # ara n results = 163 (no 182)

#scopus
scopus <- synthesisr::read_refs(
  filename   = "C:/Users/lnh88/Dropbox/Projects/ongoing/REDUCE_Milestone/RQ1_SCOPUS.ris",
  tag_naming = "scopus",
  return_df  = TRUE,
  verbose    = TRUE) %>%
  dplyr::select(title, doi) %>%
  mutate(source = "scopus") %>%
  drop_na(doi) # ara n results = 309 (no 341)


# merge both and remove duplicates (by doi)
clean_doi <- function(x) {
  x %>%
    str_to_lower() %>%
    str_trim() %>%
    str_remove("^doi\\s*:\\s*") %>%
    str_remove("^https?://(dx\\.)?doi\\.org/") %>%
    str_remove("[\\s\\.;,\\)]+$")  # trim trailing junk
}

wos <- wos %>%
  mutate(doi = clean_doi(doi)) %>%
  filter(!is.na(doi), doi != "")

scopus <- scopus %>%
  mutate(doi = clean_doi(doi)) %>%
  filter(!is.na(doi), doi != "")

all <- bind_rows(scopus, wos) %>%
  distinct(doi, .keep_all = TRUE)

glimpse(all)

# check gold papers

gold_doi <- c(
  "10.1111/faf.12555", #"Tracking industrial fishing activities in African waters from space"
  "10.1126/science.aao5646",#Tracking the global footprint of fisheries
  "10.3389/fmars.2021.602917"#Industrial Fishing Near West African Marine Protected Areas and Its Potential Effects on Mobile Marine Predators
) 

all %>%
  filter(doi %in% gold_doi) %>%
  select(title, doi, source)


#######
# RQ2 #
#######

#wos
wos <- synthesisr::read_refs(
  filename   = "C:/Users/lnh88/Dropbox/Projects/ongoing/REDUCE_Milestone/RQ2_wos.ris",
  tag_naming = "wos",
  return_df  = TRUE,
  verbose    = TRUE) %>%
  dplyr::select(title, DO) %>%
  rename(doi = DO) %>%
  mutate(source = "wos") %>%
  drop_na(doi)

#scopus
scopus <- synthesisr::read_refs(
  filename   = "C:/Users/lnh88/Dropbox/Projects/ongoing/REDUCE_Milestone/RQ2_scopus.ris",
  tag_naming = "scopus",
  return_df  = TRUE,
  verbose    = TRUE) %>%
  dplyr::select(title, doi) %>%
  mutate(source = "scopus") %>%
  drop_na(doi)


# merge both and remove duplicates (by doi)
clean_doi <- function(x) {
  x %>%
    str_to_lower() %>%
    str_trim() %>%
    str_remove("^doi\\s*:\\s*") %>%
    str_remove("^https?://(dx\\.)?doi\\.org/") %>%
    str_remove("[\\s\\.;,\\)]+$")  # trim trailing junk
}

wos <- wos %>%
  mutate(doi = clean_doi(doi)) %>%
  filter(!is.na(doi), doi != "")

scopus <- scopus %>%
  mutate(doi = clean_doi(doi)) %>%
  filter(!is.na(doi), doi != "")

all <- bind_rows(scopus, wos) %>%
  distinct(doi, .keep_all = TRUE)

glimpse(all)

# check gold papers

gold_doi <- c(
  "10.1111/faf.12436", #"Catching industrial fishing incursions into inshore waters of Africa from space"
  "10.1371/journal.pone.0118351", #Euros vs. Yuan: Comparing European and Chinese Fishing Access in West Africa
  "10.1126/sciadv.abq2109", #Hot spots of unseen fishing vessels
  "10.1126/sciadv.abp8200", #Tracking elusive and shifting identities of the global fishing fleet
  "10.3389/fmars.2017.00050" #Assessing the Effectiveness of Monitoring Control and Surveillance of Illegal Fishing: The Case of West Africa
)

all %>%
  filter(doi %in% gold_doi) %>%
  select(title, doi, source)
