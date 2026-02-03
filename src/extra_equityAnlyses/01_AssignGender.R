# -----------------------------------------------------------------------------

# Title:

#--------------------------------------------------------------------------------
# 01. Determine the ratio men:women in the author list
#--------------------------------------------------------------------------------

library(readr)
library(dplyr)
library(readxl)
library(writexl)
library(stringr)
library(tidyr)
library(stringi)

#install.packages("gender")
library(gender)

# 1. Open name dataset:
path <- "C:/Users/david/Downloads/publication-list.xlsx"
df <- read_excel(path, sheet = 1)

# clean names for a particular row:
row_i <- 60  # <- chose the row: 
#1 (Bates et al 2021), 
#3 (Sequeira et al. 2025)
#15 (McMahon et al. 2021)
#24 (Tintoré et al. 2019)
#37 (Mazaris et al. 2023)
#46 (Tintoré et al. 2013)
#60 (VanCompernolle et al. 2025)



names_row <- df %>%
  slice(row_i) %>%                                # 1) select row
  pull(`Author full names`) %>%                   # 2) extract all names
  str_squish() %>%
  str_split("\\s*;\\s*") %>%                      # 3) separate authors
  unlist() %>%
  tibble(author_raw = .) %>%
  filter(author_raw != "") %>%
  mutate(
    # 4) remove ID
    author_no_id = str_remove(author_raw, "\\s*\\([^\\)]*\\).*?$"),
    # 5) Eliminate surname
    given_block  = str_trim(str_extract(author_no_id, "(?<=,\\s).*")),
    # 6) keep name
    first_name   = str_extract(given_block, "^[^\\s]+")
  ) %>%
  select(first_name)

# There are some names with accents and so that need to be standardised:
names_row <- names_row %>%
  mutate(first_name_ascii = stri_trans_general(first_name, "Latin-ASCII"))

#Check:
#View(names_row)
head(names_row)

# Gender prediction table (with probabilities of belonging to each gender)
gender_raw <- gender(names_row$first_name_ascii, method = "ssa") %>%
  as_tibble()

# Cleaned up version with only the final decision:
gender_lookup <- gender_raw %>%
  group_by(name) %>%
  slice(1) %>%          # keep one prediction per name
  ungroup() %>%
  mutate(
    genero = case_when(
      gender == "male"   ~ "masculino",
      gender == "female" ~ "femenino",
      TRUE ~ "indefinido"
    )
  ) %>%
  select(first_name = name, genero)

names_row_gender <- names_row %>%
  left_join(gender_lookup, by = "first_name")

names_row_gender

# If there are unresolved you can tag them with unknown and then search one by one:
names_row_gender <- names_row_gender %>%
  mutate(genero = if_else(is.na(genero), "unknown", genero))

# Check unresolved:
unresolved <- names_row_gender %>%
  filter(genero == "unknown") %>%
  distinct(first_name) %>%
  arrange(first_name)

# Add manually:
manual_gender <- tibble::tribble(
  ~first_name,          ~genero,
  "Angélica",           "femenino",
  "Aroha",              "femenino",
  "Cloé",               "femenino",
  "Dobromir",           "masculino",
  "Egide",              "masculino",
  "Frédéric",           "masculino",
  "Guojun",             "masculino",
  "Hanspeter",          "masculino",
  "Iacopo",             "masculino",
  "Jessleena",          "femenino",
  "Joël",               "masculino",
  "Ku'ulei",            "femenino",
  "Manor",              "masculino",
  "Matthias-Claudio",   "masculino",
  "Mengistu",           "masculino",
  "Miqkayla",           "femenino",
  "Ofer",               "masculino",
  "Paulson",            "masculino",
  "Qiang",              "masculino",
  "Sangdon",            "masculino",
  "Shmulik",            "masculino",
  "Stoyan",             "masculino",
  "Takanao",            "masculino",
  "Thibaud",            "masculino",
  "Volen",              "masculino",
  "Víctor",             "masculino",
  "Xiangliang",         "masculino",
  "Yigael",             "masculino",
  "Yuhang",             "masculino",
  "Zuania",             "femenino",
  "Çağan",              "masculino",
  "Cerren",             "femenino",
  "Dinusha",            "femenino",
  "Shengjie",           "masculino",
  "Hyomin",             "femenino",
  "Jaein",              "femenino",
  "Zhu",                "masculino",
  "Shahar",             "masculino",
  "Ogen",               "masculino",
  "Gentile",            "masculino",
  "Mohlamatsane",       "masculino",
  "Breyl",              "femenino",
  "Adhith",           "masculino",
  "Akinori",          "masculino",
  "André",            "masculino",
  "António",          "masculino",
  "César",            "masculino",
  "Dení",             "masculino",
  "Haritz",           "masculino",
  "Iván",             "masculino",
  "Jean-Baptiste",    "masculino",
  "Jean-Benoit",      "masculino",
  "Jean-Claude",      "masculino",
  "Jesús",            "masculino",
  "José",             "masculino",
  "Mary-Anne",        "femenino",
  "Mirjam",           "femenino",
  "Mónica",           "femenino",
  "Mônica",           "femenino",
  "Ohiana",           "femenino",
  "Ramón",            "masculino",
  "Solène",           "femenino",
  "Katsufumi",        "masculino", 
  "Vardis",           "masculino",
  "Joaquín",         "masculino",
  "Lluis",           "masculino",
  "Svitlana",        "femenino",
  "Vlado",           "masculino",
  "Gianandrea",      "masculino",
  "Lorinc",          "masculino",
  "Begoña",          "femenino",
  "Pierre-Marie",    "masculino",
  "Simón",           "masculino",
  "Inmaculada",      "femenino",
  "Agustín",         "masculino",
  "Gianmaria",       "masculino",
  "Sarantis",        "masculino",
  "Slim",            "masculino",
  "Toste",            "masculino",
  "Abdulmaula",    "masculino",
  "Bektaş",        "masculino",
  "Charalampos",   "masculino",
  "Charikleia",    "femenino",
  "Costanza",      "femenino",
  "Doğan",         "masculino",
  "Drosos",        "masculino",
  "Hedia",         "femenino",
  "Imed",          "masculino",
  "Lobna",         "femenino",
  "Manel",         "masculino",
  "Nabigha",       "femenino",
  "Yakup",         "masculino",
  "Aránzazu",    "femenino",
  "Benjamín",    "masculino",
  "Bàrbara",     "femenino",
  "Enric",       "masculino",
  "Lluís",       "masculino",
  "Luís",        "masculino",
  "Sebastián",   "masculino",
  "Simó",        "masculino",
  "Temel",       "masculino",
  "Tomeu",       "masculino",
  "Asunción",      "femenino",
  "Elitza",        "femenino",
  "Elpis",         "femenino",
  "Erpur",         "masculino",
  "Katsufumi",     "masculino",
  "Kazuoki",       "masculino",
  "Klemens",       "masculino",
  "Kwang-Ming",    "masculino",
  "Philippine",    "femenino",
  "Séverine",      "femenino",
  "Tilen",         "masculino",
  "Tomonari",      "masculino",
  "Tânia",         "femenino",
  "Øystein",       "masculino",
  "Nyimale",       "femenino",
)

names_row_gender_filled <- names_row_gender %>%
  left_join(manual_gender, by = "first_name", suffix = c("", "_manual")) %>%
  mutate(
    genero = if_else(
      genero == "unknown" & !is.na(genero_manual),
      genero_manual,
      genero
    )
  ) %>%
  select(-genero_manual)
names_row_gender_filled

# Count how many of each:
names_row_gender_filled %>%
  count(genero)
