# -----------------------------------------------------------------------------

# Title:

#--------------------------------------------------------------------------------
# 01. Fitting queries in WOS and SCOPUS
#--------------------------------------------------------------------------------

# This script builds reproducible and transparent Boolean search queries for
# systematic literature searches in Web of Science and Scopus using the `litsearchr` package. 

# In the context of West Africa and the Eastern Central Atlantic (REDUCE area),
# the objective is to identify peer-reviewed studies addressing:
# 1. the spatial distribution of fishing effort
# 2. the spatial distribution of IUU
# 3. the spatial distribution of ghost gear (ALFDG)
# 3. the spatial distribution of marine megafauna bycatch (marine mammals, turtles, birds, chondrichthyans)

# The workflow:
# 1. Defines concept-based keyword blocks,
# 2. Combines them into two research-question-specific queries (RQ1 and RQ2)
# 3. Formats database-specific search strings following WoS and Scopus syntax requirements. 
# It also includes: 
#  - Explicit exclusion terms
#  - restricts results to:
#  - peer-reviewed articles in english
#  - published during a predefined publication period

# The resulting queries are intended for use in systematic or scoping
# reviews, ensuring consistency, transparency, and reproducibility of the
# literature search strategy across databases.

# Notes --------------------------------------------------

# - Concept blocks are defined independently and combined using Boolean logic
#   (OR within concepts, AND between concepts) via `litsearchr::write_search()`.
# - XXX research questions are implemented:

# RESEARCH QUESTION 1
# How are industrial longline, purse seine, and trawl fisheries
# spatially distributed in West African marine waters, in terms
# of the location and intensity of fishing effort?

#     * RQ1: Region + Industrial fishing fleets + spatial fishing effort

# RESEARCH QUESTION 2
# What evidence exists on the spatial distribution and reported
# hotspots of illegal, unreported, and unregulated (IUU) industrial
# fishing by longline, purse seine, and trawl fleets in West African waters?

#     * RQ2: Region + Industrial fishing fleets + IUU fishing

# RESEARCH QUESTION 3
# What evidence exists on the spatial distribution and reported
# ghost gear from industrial fishing in West African waters?

#     * RQ3: Region + Industrial fishing fleets + Ghost gear

# RESEARCH QUESTION 4
# What evidence exists on the spatial distribution and reported
# bycatch by industrial fishing by longline, purse seine, and trawl fleets 
# in West African waters?

#     * RQ4: Region + Industrial fishing fleets + Marine megafauna

# - Exclusion terms may be applied separately to comply with database-specific
#   constraints (NOT inside TS for WoS, NOT outside TITLE-ABS-KEY for Scopus).
# - Searches are restricted to journal articles published between a certain period of time
# - Only English-language search terms are used, with stemming and exact phrase
#   matching enabled.
# - The script outputs fully formatted search strings ready for direct use in
#   the WoS and Scopus web interfaces.
#
# -----------------------------------------------------------------------------

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
  "industrial fish*", "industrial fleet*", "industrial vessel*","distant-water fleet*", "distant water fleet*", 
  "longline*", "longliner*", "long-line*",
  "purse seine*", "purse-seine*", "purseseine*", "purse seine*", "purse-seine*", "purseseine*", 
  "FAD*", "fish aggregating device*", "fish-aggregating device*",
  "trawl*", "trawler*"
) |> unique() |> sort()


# region
region_terms <- c(
    # Countries and territories (FAO Area 34 scope)
  "morocc*", "western sahara", "mauritania*", "senegal*", "cabo verde", "cape verde*",
  "gambia*", "guinea bissau", "guinea-bissau", "guinea*", "sierra leone*",
  "liberia*", "côte d'ivoire", "cote d'ivoire", "ivory coast", "ivor*", "ghana*",
  "togo*", "benin*", "nigeria*", "cameroon*", "equatorial guinea*", "gabon*",
  "sao tome and principe","são tomé and príncipe", "são tomé*", "canary islands",
  "angola*","congo*", "republic of congo", "democratic republic of congo",
    # Regional descriptors
  "west africa*", "northwest africa", "south atlantic", "central east atlantic",
  "eastern central atlantic", "eastern atlantic",
    # Management areas
  "cecaf","fao area 34","fao 34",
    # Oceanographic regions
  "gulf of guinea", "canary current", "guinea current"
  ) |> unique() |> sort()


# spatial effort
impact_component_terms <- c(
  #FISHING EFFORT:
  "fishing effort", "fishing intensity", "fishing distribution",
  "fishing pressure", "fishing footprint",
  "spatial distribution", "spatial pattern*",
  "spatial analys*", "hotspot*", "fishing footprint", "effort distribution",
  #IUU:
  "IUU", "illegal fish*", "unreported fish*", "unregulated fish*", "fisheries crime",
  #GHOST GEAR:
  "ghost gear", "lost fishing gear", "abandoned fishing gear", 
  "derelict fishing gear", "abandoned, lost or otherwise discarded fishing gear",
  #MEGAFAUNA BYCATCH:
  "megafauna",
    # Elasmobranchs
  "elasmobranch*", "shark*", "batoid*", "skate*", "chondrichthyan*", "chimaera*", "holocephal*",
    # Cetaceans
  "cetacean*", "dolphin*", "whale*", "porpoise*", "marine mammal*",
    # Sea turtles
  "sea turtle*",
    # Seabirds
  "seabird*"
) |> unique() |> sort()

# monitoring 
#monitoring_data_terms <- c(
#  "monitoring",
#  "tracking",
#  "vessel tracking",
#  "satellite",
#  "remote sensing",
#  "AIS", "Automatic Identification System",
#  "VMS", "Vessel Monitoring System",
#  "observer data",
#  "logbook data",
#  "fisher survey*",
#  "fishers survey*",
#  "fisher interview*",
#  "fishers interview*",
#  "questionnaire*"
#) |> unique() |> sort()

# not interested in
#exclude_terms <- c(
#  "artisanal", "small-scale", "small scale", "subsistence",
#  "aquaculture", "freshwater", "inland"
#) |> unique() |> sort()

# -------------------------
# BUILD TWO QUERIES WITH write_search()
# -------------------------
# write_search()
# Takes search terms grouped by concept group and writes Boolean searches in which terms within concept groups are separated by "OR" and concept groups are separated by "AND". 

# RQ
rq1_groups <- list(
  fleet_terms,
  region_terms,
  impact_component_terms)

rq1_bool <- litsearchr::write_search(
  groupdata = rq1_groups,
  languages = "English",
  exactphrase = TRUE,
  stemming = FALSE,
  closure = "none",
  writesearch = FALSE
)

# -------------------------
# BUILD EXCLUSION BLOCK (separately -> don't embed NOT inside TITLE-ABS-KEY)
# -------------------------
#exclude_block_scopus <- paste(exclude_terms, collapse = " OR ")
#exclude_block_wos    <- paste0('("', exclude_terms, '")', collapse = " OR ")

# -------------------------
# WRAP FOR WoS / Scopus
# -------------------------

# WoS can keep NOT inside TS 
wos_rq1 <- paste0(
  "TS=(", rq1_bool, ")",
  #" NOT TS=(", exclude_block_wos, ")",
  " AND DT=(Article) AND PY=(1900-2024)"
)

# Scopus exclusions must be outside TITLE-ABS-KEY
scopus_rq1 <- paste0(
  "TITLE-ABS-KEY(", rq1_bool, ")",
  #" AND NOT TITLE-ABS-KEY(", exclude_block_scopus, ")",
  " AND DOCTYPE(ar) AND PUBYEAR < 2025"
)

cat("\n--- WoS RQ1 ---\n", wos_rq1, "\n") # 200
cat("\n--- Scopus RQ1 ---\n", scopus_rq1, "\n") # 222


