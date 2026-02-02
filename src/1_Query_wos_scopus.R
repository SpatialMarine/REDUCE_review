# RESEARCH QUESTION 1
# How are industrial longline, purse seine, and trawl fisheries
# spatially distriibuted in West African marine waters, in terms
# of the location and intensity of fishing effort?

# RESEARCH QUESTION 2
# What evidence exists on the spatial distribution and reported
# hotspots of illegal, unreported, and unregulated (IUU) industrial
# fishing by longline, purse seine, and trawl fleets in West African waters?

library(litsearchr)
library(tidyr)
library(dplyr)
library(stringr)

# -------------------------
# CONCEPT BLOCKS 
# -------------------------

# fleet
fleet_terms <- c(
  "industrial fish*", "industrial fleet*", "industrial vessel*",
  "distant-water fleet*", "distant water fleet*", 
  "longline*", "longliner*", "long-line*",
  "purse seine*", "purse-seine*", "purseseine*",
  "trawl*", "trawler*"
) |> unique() |> sort()

# region
region_terms <- c(
  # Regional descriptors
  "West Africa", "West African",
  "West African waters",
  "African waters",
  "African Atlantic waters",
  "Eastern Central Atlantic",
  "Eastern* Atlantic*",
  "tropical eastern Atlantic",
  "West African Atlantic waters",
  "Northwest Africa", "North-West Africa", "Northwestern Africa", "NW Africa",
  # Oceanographic regions
  "Gulf of Guinea",
  "Canary Current", "Canary Current Large Marine Ecosystem",
  "Guinea Current", "Guinea Current Large Marine Ecosystem",
  # Coastal countries (West Africa)
  "Mauritania","Senegal","Gambia","Guinea","Guinea-Bissau",
  "Sierra Leone","Liberia","Cote d'Ivoire","Ivory Coast",
  "Ghana","Togo","Benin","Nigeria",
  # Islands & archipelagos (non-African + African)
  "Canary Islands", "Canaries",
  "Madeira", "Azores",
  "Cape Verde", "Cabo Verde",
  "Bioko",
  "Sao Tome", "São Tomé",
  "Principe", "Príncipe",
  "Sao Tome and Principe",
  "Annobon", "Annobón"
) |> unique() |> sort()

# spatial effort
spatial_effort_terms <- c(
  "fishing effort", "fishing intensity", "fishing distribution",
  "fishing pressure", "fishing footprint",
  "spatial distribution", "spatial pattern*",
  "spatial analys*", "hotspot*", "fishing footprint", "effort distribution"
) |> unique() |> sort()

# monitoring 
monitoring_data_terms <- c(
  "monitoring",
  "tracking",
  "vessel tracking",
  "satellite",
  "remote sensing",
  "AIS", "Automatic Identification System",
  "VMS", "Vessel Monitoring System",
  "observer data",
  "logbook data",
  "fisher survey*",
  "fishers survey*",
  "fisher interview*",
  "fishers interview*",
  "questionnaire*"
) |> unique() |> sort()

#iuu
iuu_terms <- c(
  "IUU", "IUU fishing",
  "illegal fish*", "unreported fish*", "unregulated fish*",
  "illegal fishing", "fisheries crime"
) |> unique() |> sort()

# not interested in
exclude_terms <- c(
  "artisanal", "small-scale", "small scale", "subsistence",
  "aquaculture", "freshwater", "inland"
) |> unique() |> sort()

# -------------------------
# BUILD TWO QUERIES WITH write_search()
# -------------------------
# write_search()
# Takes search terms grouped by concept group and writes Boolean searches in which terms within concept groups are separated by "OR" and concept groups are separated by "AND". 

# RQ1
rq1_groups <- list(
  fleet_terms,
  region_terms,
  spatial_effort_terms)
  #c(spatial_effort_terms, monitoring_data_terms))

rq1_bool <- litsearchr::write_search(
  groupdata = rq1_groups,
  languages = "English",
  exactphrase = TRUE,
  stemming = TRUE,
  closure = "none",
  writesearch = FALSE
)

# RQ2 (subset of RQ1)
rq2_groups <- list(
  fleet_terms,
  region_terms,
  iuu_terms)


rq2_bool <- litsearchr::write_search(
  groupdata = rq2_groups,
  languages = "English",
  exactphrase = TRUE,
  stemming = TRUE,
  closure = "none",
  writesearch = FALSE
)

# -------------------------
# BUILD EXCLUSION BLOCK (separately -> don't embed NOT inside TITLE-ABS-KEY)
# -------------------------
exclude_block_scopus <- paste(exclude_terms, collapse = " OR ")
exclude_block_wos    <- paste0('("', exclude_terms, '")', collapse = " OR ")

# -------------------------
# WRAP FOR WoS / Scopus
# -------------------------

# WoS can keep NOT inside TS 
wos_rq1 <- paste0(
  "TS=(", rq1_bool, ")",
  " NOT TS=(", exclude_block_wos, ")",
  " AND DT=(Article) AND PY=(1900-2024)"
)

wos_rq2 <- paste0(
  "TS=(", rq2_bool, ")",
  " NOT TS=(", exclude_block_wos, ")",
  " AND DT=(Article) AND PY=(1900-2024)"
)

# Scopus exclusions must be outside TITLE-ABS-KEY
scopus_rq1 <- paste0(
  "TITLE-ABS-KEY(", rq1_bool, ")",
  " AND NOT TITLE-ABS-KEY(", exclude_block_scopus, ")",
  " AND DOCTYPE(ar) AND PUBYEAR > 1999 AND PUBYEAR < 2025"
)

scopus_rq2 <- paste0(
  "TITLE-ABS-KEY(", rq2_bool, ")",
  " AND NOT TITLE-ABS-KEY(", exclude_block_scopus, ")",
  " AND DOCTYPE(ar) AND PUBYEAR > 1999 AND PUBYEAR < 2025"
)

cat("\n--- WoS RQ1 ---\n", wos_rq1, "\n") # 101
#cat("\n--- WoS RQ2 ---\n", wos_rq2, "\n") # 5
cat("\n--- Scopus RQ1 ---\n", scopus_rq1, "\n") # 177
#cat("\n--- Scopus RQ2 ---\n", scopus_rq2, "\n") # 14

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

