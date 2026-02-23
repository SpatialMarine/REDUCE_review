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
library(litsearchr)
library(tidyr)
library(dplyr)
library(stringr)

# -------------------------
# Read ris files and remove duplicates
# -------------------------

#######
# RQ1 #
#######

#wos
wos1 <- synthesisr::read_refs(
  filename   = paste0(input_data, "/RIS/WoS_MegaFull.ris"),
  tag_naming = "wos",
  return_df  = TRUE,
  verbose    = TRUE) %>%
  #dplyr::select(title, DO) %>%
  rename(doi = DO) %>%
  mutate(source = "wos") #%>%
  #drop_na(doi) 

wos2 <- synthesisr::read_refs(
  filename   = paste0(input_data, "/RIS/WoS_MegaFull2.ris"),
  tag_naming = "wos",
  return_df  = TRUE,
  verbose    = TRUE) %>%
  #dplyr::select(title, DO) %>%
  rename(doi = DO) %>%
  mutate(source = "wos") #%>%
#drop_na(doi) 


#scopus
scopus <- synthesisr::read_refs(
  filename   = paste0(input_data, "/RIS/Scopus_MegaFull.ris"),
  tag_naming = "scopus",
  return_df  = TRUE,
  verbose    = TRUE) %>%
  #dplyr::select(title, doi) %>%
  mutate(source = "scopus") #%>%
  #drop_na(doi) # ara n results = 309 (no 341)


# merge both and remove duplicates (by doi)
clean_doi <- function(x) {
  x %>%
    str_to_lower() %>%
    str_trim() %>%
    str_remove("^doi\\s*:\\s*") %>%
    str_remove("^https?://(dx\\.)?doi\\.org/") %>%
    str_remove("[\\s\\.;,\\)]+$")  # trim trailing junk
}

wos1 <- wos1 %>%
  mutate(doi = clean_doi(doi)) #%>%
  #filter(!is.na(doi), doi != "")

wos2 <- wos2 %>%
  mutate(doi = clean_doi(doi)) #%>%
#filter(!is.na(doi), doi != "")

scopus <- scopus %>%
  mutate(doi = clean_doi(doi)) #%>%
  #filter(!is.na(doi), doi != "")

# Filter by doi and when to available by tittle:
all <- bind_rows(scopus, wos1, wos2) %>%
  mutate(
    doi = clean_doi(doi),
    title_clean = title %>%
      str_to_lower() %>%
      str_squish() %>%
      str_replace_all("[^a-z0-9\\s]", "")  # remove punctuation
  ) %>%
  mutate(dedup_key = if_else(!is.na(doi) & doi != "", doi, title_clean)) %>%
  distinct(dedup_key, .keep_all = TRUE) %>%
  select(-title_clean, -dedup_key)

glimpse(all) #1666
2642-1666 #976 duplicados

# check gold papers
gold_doi <- c(
  "10.2960/J.v35.m534", #Change in Elasmobranchs and Other Incidental Species in the Spanish Deepwater Black Hake Trawl Fishery off Mauritania (1992–2001) #NOPE
  "10.1111/faf.12555", #"Tracking industrial fishing activities in African waters from space"
  "10.1126/science.aao5646",#Tracking the global footprint of fisheries
  "10.3389/fmars.2021.602917",#Industrial Fishing Near West African Marine Protected Areas and Its Potential Effects on Mobile Marine Predators
  "10.1111/faf.12436", #"Catching industrial fishing incursions into inshore waters of Africa from space"
  "10.1371/journal.pone.0118351", #Euros vs. Yuan: Comparing European and Chinese Fishing Access in West Africa
  "10.1126/sciadv.abq2109", #Hot spots of unseen fishing vessels #NOPE
  "10.1126/sciadv.abp8200", #Tracking elusive and shifting identities of the global fishing fleet #NOPE
  "10.3389/fmars.2017.00050" #Assessing the Effectiveness of Monitoring Control and Surveillance of Illegal Fishing: The Case of West Africa #NOPE
) 

all %>%
  filter(doi %in% gold_doi) %>%
  select(title, doi, source)

head(all)
# structure the dataframe and export:
all_keep <- all %>%
  mutate(
    paperID = row_number()) %>%
  transmute(
    paperID,
    authors = author,
    title = title,
    year = year,
    journal = source_abbreviated,        
    volume = volume,
    issue = issue,
    start_page = start_page,
    end_page = end_page,
    doi = doi,
    abstract = abstract,
    Language = language,
    document_type = document_type,
    source = source        # WoS vs Scopus
  )

glimpse(all_keep)


# export:
library(openxlsx)
dir <- paste0(input_data, "/rm_duplicates")
if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)

write.xlsx(
  all_keep,
  file = paste0(dir,"/paperList.xlsx"),
  overwrite = TRUE)
