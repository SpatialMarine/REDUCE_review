# -----------------------------------------------------------------------------

# Title:

#--------------------------------------------------------------------------------
# 01. Fitting queries in WOS and SCOPUS
#--------------------------------------------------------------------------------

# This script builds reproducible and transparent Boolean search queries for
# systematic literature searches in Web of Science and Scopus using the `litsearchr` package. 

# In the context of West Africa and the Eastern Central Atlantic (REDUCE area),
# the objective is to identify peer-reviewed studies addressing:
# 1. the spatial distribution of marine megafauna and methods used.
# 2. the spatial distribution and intensity of industrial fishing (including IUU fishing)
# 3. the spatial distribution of bycatch risk.

# The workflow:
# 1. Defines concept-based keyword blocks,
# 2. Combines them into two research-question-specific queries (RQ1 and RQ2)
# 3. Formats database-specific search strings following WoS and Scopus syntax requirements. 
# It also includes: 
#- Explicit exclusion terms
#- restricts results to:
#  - peer-reviewed articles in english
#  - published during a predefined publication period
#
# The resulting queries are intended for use in systematic or scoping
# reviews, ensuring consistency, transparency, and reproducibility of the
# literature search strategy across databases.

# Notes --------------------------------------------------

# - Concept blocks are defined independently and combined using Boolean logic
#   (OR within concepts, AND between concepts) via `litsearchr::write_search()`.
# - XXX research questions are implemented:
#     * RQ1: Industrial fishing fleets + region + spatial fishing effort
#     * RQ2: Industrial fishing fleets + region + IUU fishing
# - Exclusion terms are applied separately to comply with database-specific
#   constraints (NOT inside TS for WoS, NOT outside TITLE-ABS-KEY for Scopus).
# - Searches are restricted to journal articles published between a certain period of time
# - Only English-language search terms are used, with stemming and exact phrase
#   matching enabled.
# - The script outputs fully formatted search strings ready for direct use in
#   the WoS and Scopus web interfaces.
#
# -----------------------------------------------------------------------------

# RESEARCH QUESTION 1
# How are industrial longline, purse seine, and trawl fisheries
# spatially distriibuted in West African marine waters, in terms
# of the location and intensity of fishing effort?

# RESEARCH QUESTION 2
# What evidence exists on the spatial distribution and reported
# hotspots of illegal, unreported, and unregulated (IUU) industrial
# fishing by longline, purse seine, and trawl fleets in West African waters?

#remotes::install_github("elizagrames/litsearchr")
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
cat("\n--- WoS RQ2 ---\n", wos_rq2, "\n") # 5

cat("\n--- Scopus RQ1 ---\n", scopus_rq1, "\n") # 177
cat("\n--- Scopus RQ2 ---\n", scopus_rq2, "\n") # 14

