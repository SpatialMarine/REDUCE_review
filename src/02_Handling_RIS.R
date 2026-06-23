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
library(openxlsx)

# -------------------------
# Read ris files and remove duplicates
# -------------------------

#######
# RQ1 #
#######

#wos
wos1 <- synthesisr::read_refs(
  filename   = paste0(input_data, "/RIS/wos1.ris"),
  tag_naming = "wos",
  return_df  = TRUE,
  verbose    = TRUE) %>%
  #dplyr::select(title, DO) %>%
  rename(doi = DO) %>%
  mutate(source = "wos") #%>%
  #drop_na(doi) 

wos2 <- synthesisr::read_refs(
  filename   = paste0(input_data, "/RIS/wos2.ris"),
  tag_naming = "wos",
  return_df  = TRUE,
  verbose    = TRUE) %>%
  #dplyr::select(title, DO) %>%
  rename(doi = DO) %>%
  mutate(source = "wos") #%>%
#drop_na(doi) 
glimpse(wos2)

#scopus
scopus <- synthesisr::read_refs(
  filename   = paste0(input_data, "/RIS/scopus.ris"),
  tag_naming = "scopus",
  return_df  = TRUE,
  verbose    = TRUE) %>%
  #dplyr::select(title, doi) %>%
  mutate(source = "scopus") #%>%
  #drop_na(doi) # ara n results = 309 (no 341)
glimpse(scopus)

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

glimpse(all) #2285
3630-2285 #1335 duplicados


# 2. check gold papers

# 2.1. Fishing effort-----------------------------------------------------------
gold_doi_effort <- c( #11
  "10.1111/faf.12555", #"Tracking industrial fishing activities in African waters from space"
  "10.1126/science.aao5646",#Tracking the global footprint of fisheries
  "10.3389/fmars.2021.602917",#Industrial Fishing Near West African Marine Protected Areas and Its Potential Effects on Mobile Marine Predators
  "10.1111/faf.12436", #"Catching industrial fishing incursions into inshore waters of Africa from space"
  "10.1371/journal.pone.0118351", #Euros vs. Yuan: Comparing European and Chinese Fishing Access in West Africa
  "10.1126/sciadv.aat3681", #The environmental niche of the global high seas pelagic longline fleet
  #"10.1111/conl.12360", #Trends in Industrial and Artisanal Catch Per Effort in West African Fisheries ## THIS A REVIEW!!! ALTHOUGH IT IS NOT AN ACTUAL REVIEW...
  "10.1016/j.marpol.2016.05.009" #Overview of West African fisheries under climate change: Impacts, vulnerabilities and adaptive responses of the artisanal and industrial sectors
  ) 

# filter gold ones:
gold_tbl <- tibble(doi = gold_doi_effort)
gold_check <- gold_tbl %>%
    mutate(in_dataset = doi %in% all$doi)
sum(gold_check$in_dataset)

# present / missing
gold_check %>% filter(in_dataset)
gold_check %>% filter(!in_dataset)

# 2.2. IUU----------------------------------------------------------------------
gold_doi_iuu <- c(
  "10.1126/sciadv.abq2109", #Hot spots of unseen fishing vessels 
  "10.1126/sciadv.abp8200", #Tracking elusive and shifting identities of the global fishing fleet
  "10.3389/fmars.2017.00050", #Assessing the Effectiveness of Monitoring Control and Surveillance of Illegal Fishing: The Case of West Africa 
  "10.1093/icesjms/fsaf033", #Bias in Global Fishing Watch AIS data analyses results in overestimate of Northeast Atlantic pelagic fishing impact 
  "10.1038/s41586-023-06825-8", #Satellite mapping reveals extensive industrial activity at sea
  "10.1016/j.marpol.2024.106209" #The complementary relationship between illegal fishing and maritime piracy: A case study of the Gulf of Guinea 
  )

# filter gold ones:
gold_tbl <- tibble(doi = gold_doi_iuu)
gold_check <- gold_tbl %>%
  mutate(in_dataset = doi %in% all$doi)
sum(gold_check$in_dataset)

# present / missing
gold_check %>% filter(in_dataset)
gold_check %>% filter(!in_dataset)

# 2.3. Ghost gear---------------------------------------------------------------
gold_doi_ghost <- c(
  "10.1126/sciadv.ads2902", #The global footprint of drifting fish aggregating devices
  "10.1126/sciadv.abq0135", #Global estimates of fishing gear lost to the ocean each year
  #"10.1038/s41893-022-00883-y", #Recovery at sea of abandoned, lost or discarded drifting fish aggregating devices #PROBLEM: IT DOES NOT INCLUDE STUDY AREA IN ABSTRACT
  "10.1111/faf.12596" #Plastic gear loss estimates from remote observation of industrial fishing activity
  
)

# filter gold ones:
gold_tbl <- tibble(doi = gold_doi_ghost)
gold_check <- gold_tbl %>%
  mutate(in_dataset = doi %in% all$doi)
sum(gold_check$in_dataset)

# present / missing
gold_check %>% filter(in_dataset)
gold_check %>% filter(!in_dataset)


# 2.4. Sea birds----------------------------------------------------------------
gold_doi_birds <- c(
  "10.1073/pnas.1318960111", #Global patterns of marine mammal, seabird, and sea turtle bycatch reveal taxa-specific and cumulative megafauna hotspots
  "10.1111/1365-2664.70139", #Seabird- vessel interactions in industrial fisheries of Northwest Africa: Implications for international bycatch management
  #"10.1016/j.biocon.2014.12.001", #Adult and juvenile European seabirds at risk from marine plundering off West Africa
  "10.1016/j.fishres.2023.106730", #The Portuguese industrial pelagic longline fishery in the Northeast Atlantic: Catch composition, spatio-temporal dynamics of fishing effort, and target species catch rates 
  "10.1093/icesjms/fsr118" #An assessment of seabird–fishery interactions in the Atlantic Ocean
)

# filter gold ones:
gold_tbl <- tibble(doi = gold_doi_birds)
gold_check <- gold_tbl %>%
  mutate(in_dataset = doi %in% all$doi)
sum(gold_check$in_dataset)

# present / missing
gold_check %>% filter(in_dataset)
gold_check %>% filter(!in_dataset)


# 2.5. Pelagic elasmobranch-----------------------------------------------------
gold_doi_pela <- c(
  "10.1016/j.fishres.2006.01.012", #Change in Elasmobranchs and Other Incidental Species in the Spanish Deepwater Black Hake Trawl Fishery off Mauritania (1992–2001) #NOPE
  "10.1016/j.fishres.2023.106730", #The Portuguese industrial pelagic longline fishery in the Northeast Atlantic: Catch composition, spatio-temporal dynamics of fishing effort, and target species catch rates
  "10.1016/j.biocon.2022.109534", #Unreported discards of internationally protected pelagic sharks in a global fishing hotspot are potentially large
  "10.1051/alr/2012030", #An overview of the hooking mortality of elasmobranchs caught in a swordfish pelagic longline fishery in the Atlantic Ocean
  "10.1016/j.gecco.2020.e01211" #Elasmobranch bycatch distributions and mortality: Insights from the European tropical tuna purse-seine fi
  )

# filter gold ones:
gold_tbl <- tibble(doi = gold_doi_pela)
gold_check <- gold_tbl %>%
  mutate(in_dataset = doi %in% all$doi)
sum(gold_check$in_dataset)

# present / missing
gold_check %>% filter(in_dataset)
gold_check %>% filter(!in_dataset)

# 2.7. Demersal elasmobranch----------------------------------------------------
gold_doi_dem <- c(
  "10.2989/025776191784287664", #Distribution of offshore demersal cartilaginous fish (Class Chondrichthyes) off the west coast of southern Africa, with notes on their systematics
  "10.2960/j.v35.m534" #Change in Elasmobranchs and Other Incidental Species in the Spanish Deepwater Black Hake Trawl Fishery off Mauritania (1992–2001)
  #"10.3390/fishes10070358", #A Long-Term Overview of Elasmobranch Fisheries in an Oceanic Archipelago: A Case Study of the Madeira Archipelago # this is artisanal...
  #"10.1007/s10531-019-01732-9", #Risks to biodiversity and coastal livelihoods from artisanal elasmobranch fisheries in a Least Developed Country: The Gambia (West Africa) # this is artisanal...
  #"10.1016/j.dsr.2015.04.013" #Structure and zonation of demersal and deep-water fish assemblages off the Cabo Verde archipelago (northeast-Atlantic) as sampled by baited longlines # this is artisanal...
)

# filter gold ones:
gold_tbl <- tibble(doi = gold_doi_dem)
gold_check <- gold_tbl %>%
  mutate(in_dataset = doi %in% all$doi)
sum(gold_check$in_dataset)

# present / missing
gold_check %>% filter(in_dataset)
gold_check %>% filter(!in_dataset)

# 2.7. Seaturtles---------------------------------------------------------------
gold_doi_turt <- c(
  #"10.1002/aqc.3983" #Nowhere to hide: Sea turtle bycatch in Northwest Africa BIBLIOGRAPHICAL REVIEW!
  "10.1016/j.fishres.2006.01.012", #Bycatch and release of pelagic megafauna in industrial trawler fisheries off Northwest Africa
  "10.1002/aqc.70099", #Mortality of Marine Turtles Bycaught in Industrial Fisheries Operating Off North-Wester Africa
  "10.2989/ajms.2009.31.1.8.779", #Turtle bycatch in the pelagic longline fishery off southern Africa
  "10.1007/s10531-017-1367-z" #A first estimate of sea turtle bycatch in the industrial trawling fishery of Gabon
)

# filter gold ones:
gold_tbl <- tibble(doi = gold_doi_turt)
gold_check <- gold_tbl %>%
  mutate(in_dataset = doi %in% all$doi)
sum(gold_check$in_dataset)

# present / missing
gold_check %>% filter(in_dataset)
gold_check %>% filter(!in_dataset)


# 2.8. Marine mammals-----------------------------------------------------------
gold_doi_mamamls <- c(
  #"10.1016/j.biocon.2009.12.023", #An interview-based approach to assess marine mammal and sea turtle captures in artisanal fisheries #ARTISANAL!
  #"10.1007/s10745-015-9727-3", #Food, Pharmacy, Friend? Bycatch, Direct Take and Consumption of Dolphins in West Africa #ARTISANAL
  #"10.3389/fmars.2016.00163", #The Utilization of Aquatic Bushmeat from Small Cetaceans and Manatees in South America and West Africa # REVIEW
  #"10.3390/d14090716", #Range-Wide Conservation Efforts for the Critically Endangered Atlantic Humpback Dolphin (Sousa teuszii) # KIND OF REVIEW
  #"10.2989/AJMS.2008.30.2.4.554" #Records of Fraser's dolphin Lagenodelphis hosei Fraser 1956 from the Gulf of Guinea and Angola #ARTISANAL
)

# filter gold ones:
gold_tbl <- tibble(doi = gold_doi_iuu)
gold_check <- gold_tbl %>%
  mutate(in_dataset = doi %in% all$doi)
sum(gold_check$in_dataset)

# present / missing
gold_check %>% filter(in_dataset)
gold_check %>% filter(!in_dataset)







# 3. structure the dataframe and export-----------------------------------------
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
    source = source,        # WoS vs Scopus
    keywords = keywords
  )

glimpse(all_keep)


# export as excel:

dir <- paste0(input_data, "/rm_duplicates")
if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)

write.xlsx(
  all_keep,
  file = paste0(dir,"/paperList.xlsx"),
  overwrite = TRUE)

# export as ris:
library(dplyr)
library(purrr)
library(stringr)

# Function to convert one row into RIS format
make_ris <- function(authors, title, year, journal, volume, issue,
                     start_page, end_page, doi, abstract, keywords,
                     document_type = NA, ...) {
  
  # RIS type
  ris_type <- case_when(
    document_type %in% c("Article", "Review") ~ "JOUR",
    TRUE ~ "JOUR"
  )
  
  # Authors
  au <- if (!is.na(authors) && authors != "") {
    authors_vec <- str_split(authors, "\\s+and\\s+")[[1]]
    paste0("AU  - ", authors_vec, collapse = "\n")
  } else {
    ""
  }
  
  # Keywords
  kw <- if (!is.na(keywords) && keywords != "") {
    keywords_vec <- str_split(keywords, "\\s+and\\s+")[[1]]
    paste0("KW  - ", keywords_vec, collapse = "\n")
  } else {
    ""
  }
  
  paste0(
    "TY  - ", ris_type, "\n",
    if (au != "") paste0(au, "\n") else "",
    if (!is.na(title) && title != "") paste0("TI  - ", title, "\n") else "",
    if (!is.na(journal) && journal != "") paste0("JO  - ", journal, "\n") else "",
    if (!is.na(year) && year != "") paste0("PY  - ", year, "\n") else "",
    if (!is.na(volume) && volume != "") paste0("VL  - ", volume, "\n") else "",
    if (!is.na(issue) && issue != "") paste0("IS  - ", issue, "\n") else "",
    if (!is.na(start_page) && start_page != "") paste0("SP  - ", start_page, "\n") else "",
    if (!is.na(end_page) && end_page != "") paste0("EP  - ", end_page, "\n") else "",
    if (!is.na(doi) && doi != "") paste0("DO  - ", doi, "\n") else "",
    if (!is.na(abstract) && abstract != "") paste0("AB  - ", str_replace_all(abstract, "\n", " "), "\n") else "",
    if (kw != "") paste0(kw, "\n") else "",
    "ER  - \n"
  )
}

ris_entries <- pmap_chr(all_keep, make_ris)

file_path <- paste0(input_data, "/RIS/merged")
  if (!dir.exists(file_path)) dir.create(file_path, recursive = TRUE)

file <- paste0(file_path, "/finalRIS.ris")
  
writeLines(ris_entries, file, useBytes = TRUE)
