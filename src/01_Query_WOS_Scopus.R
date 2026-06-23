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


# 1. Add key words in concept blocks -------------------------------------------


# 1.1. FLEET
fleet_terms <- c(
  "industrial fish*", "industrial fleet*", "industrial vessel*", "F.R.S.",
  "distant-water fleet*", "distant water fleet*", 
  "longline*", "long-line*",
  "purse seine*", "purse-seine*", "purseseine*", 
  "FAD*", "fish aggregating device*", "fish-aggregating device*",
  "trawl*",
  # include global studies from GFW:
  "commercial fisher*", "fishing fleet", "illegal fishing"
) |> unique() |> sort()


# 1.2. REGION
region_terms <- c(
    # Countries and territories (FAO Area 34 scope)
  "morocc*", "western sahara", "mauritania*", "senegal*", "cabo verde", "cape verde*",
  "gambia*", "guinea*", "sierra leone*",
  "liberia*", "ivor*", "ghana*",
  "togo*", "benin*", "nigeria*", "cameroon*", "gabon*",
  "sao tome*", "são tomé*", "canary islands",
  "angola*","congo*", "ascension island*",
  "helena island*", "st helena", "saint helena", "angola*", "namibia*", 
    # Regional descriptors
  "africa*", #needed to capture gold papers
  "east* central atlantic", "east* atlantic", "south* atlantic", "east* tropical atlantic",
  "canary current", 
    # Management areas
  #"cecaf","fao area 34","fao 34", "seafo", "fao area 47", "fao 47",
    # Capture global studies
  "global" #needed to capture gold papers
  ) |> unique() |> sort()


# 1.3. IMPACT COMPONENT
impact_component_terms <- c(
  #FISHING EFFORT:
  "fishing effort", "fishing intensity", "fishing distribution", "shift* target species",
  "fishing pressure", "fishing footprint", "fishing activit*",
  "spatial distribution", "spatial pattern*",
  "spatial analys*", "hotspot*", "fishing footprint", "effort distribution",
  # needed generalities for gold papers:
  "satellite imagery", "vessel tracking","AIS", #"vessel GPS",
  #IUU:
  "IUU", "illegal fish*", "unreported fish*", "unregulated fish*", "fisheries crime",
  #GHOST GEAR:
  "ghost gear", "lost fishing gear", "abandoned fishing gear",  "abandoned, lost or discarded",
  "derelict fishing gear", "abandoned, lost or otherwise discarded fishing gear",
  #MEGAFAUNA BYCATCH:
  "megafauna", "bycatch", "by-catch", 
  "accidental catch*", "accidental captur*", 
  "incidental catch*", "incidental captur*", 
  #"non-target catch*", "interactions with fisher*", "fisheries interaction*",
    # Elasmobranchs
  "elasmobranch*", "shark*", "batoid*", "skate*", "chondrichthyan*", "chimaera*", "holocephal*", #"cartilaginous fish*",
  #"skate*", "rajiformes", "myliobatiformes", "rhinopristiformes", "torpediniformes",
  #"stingray*", "manta ray*", "devil ray*", "eagle ray*", "guitarfish*", "wedgefish*", "sawfish*", "electric ray*",
  
   # Cetaceans
  "cetacean*", "dolphin*", "whale*", "porpoise*", "marine mammal*",
    # Sea turtles
  "sea turtle*",
    # Seabirds
  "seabird*"
) |> unique() |> sort()

# not interested in
#exclude_terms <- c(
#  "artisanal", "small-scale", "small scale", "subsistence",
#  "aquaculture", "freshwater", "inland"
#) |> unique() |> sort()



# 2. Build queries with edits automatically fitted by write_search() ------------
# write_search() takes search terms grouped by concept group and writes Boolean 
# searches in which terms within concept groups are separated by "OR" and concept 
# groups are separated by "AND". 

# 2.1. Build the string---------------------------------------------------------
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

# 2.2. Check all changes done automatically-------------------------------------
# helper: normalize terms so minor formatting differences don't hide matches
norm_term <- function(x) {
  x <- trimws(x)
  x <- tolower(x)
  x <- gsub("\\s+", " ", x)
  x
}

# Extract terms inside a boolean string:
#  - quoted phrases: "..."
#  - unquoted tokens (no spaces): e.g. FAD*, trawl*, longline*
extract_or_terms <- function(bool_string) {
  s <- bool_string
  
  # 1) grab quoted phrases
  quoted <- regmatches(s, gregexpr('"(?:\\\\.|[^"\\\\])*"', s, perl = TRUE))[[1]]
  quoted <- gsub('^"|"$', "", quoted)  # remove quotes
  
  # 2) remove quoted phrases from string so they don't interfere
  s2 <- gsub('"(?:\\\\.|[^"\\\\])*"', " ", s, perl = TRUE)
  
  # 3) split remaining by non-word-ish separators, keep wildcard tokens etc.
  tokens <- unlist(strsplit(s2, "[()]", perl = TRUE))
  tokens <- unlist(strsplit(paste(tokens, collapse=" "), "\\bAND\\b|\\bOR\\b", perl = TRUE))
  tokens <- trimws(unlist(strsplit(paste(tokens, collapse=" "), "\\s+", perl = TRUE)))
  
  # remove empties and stopwords
  tokens <- tokens[tokens != ""]
  tokens <- tokens[!tokens %in% c("and", "or")]
  
  # keep only plausible search terms (contains letter/digit or * or quotes removed already)
  tokens <- tokens[grepl("[a-z0-9\\*]", tokens)]
  
  unique(norm_term(c(quoted, tokens)))
}

# Input terms (your original intention)
in_terms <- unique(norm_term(unlist(rq1_groups)))

# Output terms (what write_search produced)
out_terms <- extract_or_terms(rq1_bool)

removed <- setdiff(in_terms, out_terms)
added   <- setdiff(out_terms, in_terms)

list(
  n_input = length(in_terms),
  n_output = length(out_terms),
  removed = sort(removed),
  added = sort(added)
)



# Change specific terms you want to keep despite that write_search() removes them:
#rq1_bool <- gsub(
#  "long\\s*[-–-]?\\s*line\\*",
#  'longline* OR "long-line*"',
#  rq1_bool,
#  perl = TRUE)

# Re-inject IUU into the impact block
rq1_bool <- sub(
  "\\)\\)\\s*$",
  ' OR IUU* OR AIS*))',
  rq1_bool
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
  " AND DT=(Article) AND PY=(1900-2025)"
)

# Scopus exclusions must be outside TITLE-ABS-KEY
scopus_rq1 <- paste0(
  "TITLE-ABS-KEY(", rq1_bool, ")",
  #" AND NOT TITLE-ABS-KEY(", exclude_block_scopus, ")",
  " AND DOCTYPE(ar) AND PUBYEAR < 2026"
)


cat("\n--- WoS RQ1 ---\n",wos_rq1, "\n") # 1879 #1887
writeClipboard(wos_rq1)

cat("\n--- Scopus RQ1 ---\n",scopus_rq1, "\n") # 1758 #1766
writeClipboard(scopus_rq1)

1871+1751 #3622
1872+1758 #3632



# Google scholar
# Not recommendable as it is not a bolean search-------------------------------
# 1) Make terms Scholar-friendly
to_scholar <- function(x) {
  x %>%
    unique() %>%
    str_trim() %>%
    .[. != ""] %>%
    str_replace_all("\\*", "") %>%                         # Scholar doesn't do WoS truncation
    ifelse(str_detect(., "\\s"), paste0('"', ., '"'), .)    # quote phrases
}

# 2) Build OR block
or_block <- function(x) paste(x, collapse = " OR ")

# ---- Prepare common blocks: ALL fleet + ALL region ----
fleet_block  <- paste0("(", or_block(to_scholar(fleet_terms)), ")")
region_block <- paste0("(", or_block(to_scholar(region_terms)), ")")
# ---- Split impact terms into your 4 sections ----
impact_effort <- c(
  "fishing effort", "fishing intensity", "fishing distribution",
  "fishing pressure", "fishing footprint", "fishing activit*",
  "spatial distribution", "spatial pattern*",
  "spatial analys*", "hotspot*", "effort distribution"
)

impact_iuu <- c(
  "IUU", "illegal fish*", "unreported fish*", "unregulated fish*", "fisheries crime"
)

impact_ghost <- c(
  "ghost gear", "lost fishing gear", "abandoned fishing gear",
  "derelict fishing gear", "abandoned, lost or otherwise discarded fishing gear"
)

impact_bycatch <- c(
  "megafauna",
  "elasmobranch*", "shark*", "batoid*", "skate*", "chondrichthyan*", "chimaera*", "holocephal*",
  "cetacean*", "dolphin*", "whale*", "porpoise*", "marine mammal*",
  "sea turtle*",
  "seabird*"
)

impact_blocks <- list(
  effort  = paste0("(", or_block(to_scholar(impact_effort)),  ")"),
  iuu     = paste0("(", or_block(to_scholar(impact_iuu)),     ")"),
  ghost   = paste0("(", or_block(to_scholar(impact_ghost)),   ")"),
  bycatch = paste0("(", or_block(to_scholar(impact_bycatch)), ")")
)

# ---- 3) Build final Scholar queries (one per section) ----
scholar_queries <- lapply(impact_blocks, function(imp) {
  paste(fleet_block, region_block, imp)
})

# If you truly want 4 strings:
scholar_queries <- scholar_queries[c("effort", "iuu", "ghost", "bycatch")]


# ---- 4) Print / inspect ----
names(scholar_queries)
nchar(unlist(scholar_queries))  # length check
cat(scholar_queries[["effort"]])
cat(scholar_queries[["iuu"]])
cat(scholar_queries[["ghost"]])
cat(scholar_queries[["bycatch"]])

