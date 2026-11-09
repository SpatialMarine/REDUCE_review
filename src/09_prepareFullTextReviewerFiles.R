# -----------------------------------------------------------------------------

# Title:

#-------------------------------------------------------------------------------
# 09. Prepare individual full-text screening workbooks 
#-------------------------------------------------------------------------------

library(readxl)
library(dplyr)

# 1. Input and output paths -----------------------------------------------------

# 1.1. Read the assignment workbook from script 08 -----------------------------

assignment_file <- file.path(output_data, "full_text_screening", "split_fullText_screening.xlsx")
template_file <- file.path(input_data, "REDUCE_extraction_template.xlsx")
reviewer_dir <- file.path(output_data, "full_text_screening", "by_reviewer")

# 2. Prepare the articles and reviewer codes -----------------------------------

# 2.1. Keep bibliography and final abstract-screening classifications ----------

paper_columns <- c("paperID", "title", "abstract", "keywords", "authors", "year", "journal",
                   "doi", "Topic_standardised", "TaxaGroup_standardised", "fishingGear_standardised")
reviewer_columns <- c("full_text_reviewer_1", "full_text_reviewer_2")
papers <- read_excel(assignment_file, sheet = "Full_text_papers") %>%
  select(all_of(c(paper_columns, reviewer_columns))) %>%
  mutate(paperID = trimws(as.character(paperID)))

# Each paper must have a first reviewer and any second reviewer must be different.
stopifnot(!anyNA(papers$paperID), all(nzchar(papers$paperID)), !anyDuplicated(papers$paperID),
          !anyNA(papers$full_text_reviewer_1),
          all(is.na(papers$full_text_reviewer_2) | papers$full_text_reviewer_1 != papers$full_text_reviewer_2))

# 2.2. Match the full reviewer names to the original screening codes ------------

reviewer_codes <- setNames(
  c("DRG", "PGU", "CL", "ISM", "DFF", "TM", "ABC", "NPS", "AEP", "DK", "LNH", "JOB", "CS", "GA", "EM"),
  c("David Ruiz-Garc\u00eda", "Paola Gabasa", "Clara Lerebourg", "Ignacio de Saint-Malo Zamacola", "Diego Fern\u00e1ndez-Fern\u00e1ndez", "Teresa Milit\u00e3o", "Ana Carneiro", "N\u00faria Pati\u00f1o Sevillano", "Alejandro Espada-Pastor", "David M. Kaplan", "Leia Navarro-Herrero", "Jazel Ouled-Cheikh", "Catarina N. S. Silva", "Gill Ainsworth", "Esther Mollier")
)
assigned_reviewers <- sort(unique(na.omit(c(papers$full_text_reviewer_1, papers$full_text_reviewer_2))))
unknown_reviewers <- setdiff(assigned_reviewers, names(reviewer_codes))

# Stop before writing files if an assigned reviewer has no code.
if (length(unknown_reviewers) > 0) {
  stop("Missing reviewer codes for: ", paste(unknown_reviewers, collapse = ", "))
}

# 2.3. Standardise DOI URLs while retaining blank values -----------------------

# Remove a resolver URL or DOI prefix before attaching the standard HTTPS resolver.
doi <- trimws(as.character(papers$doi))
doi <- sub("^(https?://(dx\\.)?doi\\.org/|doi:[[:space:]]*)", "", doi, ignore.case = TRUE)
papers$doi <- ifelse(!is.na(doi) & nzchar(doi), paste0("https://doi.org/", doi), NA_character_)

# 3. Build and export one workbook per reviewer --------------------------------

# 3.1. Read the template headers and check the export paths ---------------------

# Locate the prefilled fields by name in the second header row.
template_columns <- names(read_excel(template_file, sheet = "dataExtraction", skip = 1, n_max = 0))
export_columns <- match(c(paper_columns, "rev1_name"), template_columns)
stopifnot(!anyNA(export_columns), identical(excel_sheets(template_file)[2], "dataExtraction"))

# Check all paths before writing so a rerun cannot overwrite completed reviews.
files <- file.path(reviewer_dir, paste0("full_text_", reviewer_codes[assigned_reviewers], ".xlsx"))
if (any(file.exists(files))) {
  stop("Reviewer workbooks already exist: ", paste(basename(files[file.exists(files)]), collapse = ", "))
}
dir.create(reviewer_dir, recursive = TRUE, showWarnings = FALSE)

# Unpack the template once. Rewriting only its data sheet preserves drawings and Excel validations.
template_dir <- tempfile("reviewer_template_")
template_parts <- unzip(template_file, list = TRUE)$Name
unzip(template_file, exdir = template_dir)
sheet_file <- file.path(template_dir, "xl", "worksheets", "sheet2.xml")
sheet_xml <- paste(readLines(sheet_file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# Keep the existing headings and insert rows before the end of the worksheet data.
rows_end <- regexpr("</sheetData>", sheet_xml, fixed = TRUE)[1]
stopifnot(rows_end > 0L, !grepl('<row r="([3-9]|[0-9]{2,})"', sheet_xml))
sheet_top <- substr(sheet_xml, 1L, rows_end - 1L)
sheet_bottom <- substring(sheet_xml, rows_end)

# 3.2. Fill the template with each reviewer's assigned papers -------------------

# Escape text for Excel's XML, preserving Unicode and line breaks in abstracts.
escape_xml <- function(text) {
  # Excel's XML cannot store control characters other than tabs and line breaks.
  text <- gsub("[\\x01-\\x08\\x0B\\x0C\\x0E-\\x1F]", "", enc2utf8(text), perl = TRUE)
  text <- gsub("&", "&amp;", enc2utf8(text), fixed = TRUE)
  text <- gsub("<", "&lt;", text, fixed = TRUE)
  gsub(">", "&gt;", text, fixed = TRUE)
}

# Keep the column references in worksheet order for every article.
columns <- order(export_columns)
excel_columns <- openxlsx::int2col(export_columns)
last_column <- openxlsx::int2col(length(template_columns))

for (i in seq_along(assigned_reviewers)) {
  reviewer <- assigned_reviewers[i]
  code <- unname(reviewer_codes[reviewer])

  # Keep one initial row per assigned paper, including both assignment roles.
  screening <- papers %>%
    filter(full_text_reviewer_1 == reviewer | full_text_reviewer_2 == reviewer) %>%
    select(all_of(paper_columns)) %>%
    mutate(rev1_name = code)

  # Keep rows within the template's filter and validation ranges.
  stopifnot(nrow(screening) <= 10000L)

  # Write only populated fields, ordered by their position in the template.
  rows <- character(nrow(screening))
  for (row in seq_len(nrow(screening))) {
    excel_row <- row + 2L
    cells <- character(length(columns))
    for (j in columns) {
      # Leave missing values and all review and extraction fields empty.
      value <- screening[[j]][row]
      if (is.na(value)) next

      # Use a clickable Excel formula for DOI and preserve the year as a number.
      ref <- paste0(excel_columns[j], excel_row)
      if (names(screening)[j] == "doi") {
        link <- escape_xml(value)
        formula <- paste0('HYPERLINK("', gsub('"', '""', link, fixed = TRUE), '")')
        cells[j] <- paste0('<c r="', ref, '" t="str"><f>', formula, '</f><v>', link, '</v></c>')
      } else if (is.numeric(value)) {
        cells[j] <- paste0('<c r="', ref, '"><v>', value, '</v></c>')
      } else {
        cells[j] <- paste0('<c r="', ref, '" t="inlineStr"><is><t xml:space="preserve">',
                           escape_xml(as.character(value)), '</t></is></c>')
      }
    }

    # Append the populated cells as a single row without modifying the template headers.
    rows[row] <- paste0('<row r="', excel_row, '">', paste0(cells[columns], collapse = ""), '</row>')
  }

  # Update the used range and package the untouched template parts with the filled sheet.
  dimension <- paste0('<dimension ref="A1:', last_column)
  top <- sub(paste0(dimension, '2"'), paste0(dimension, nrow(screening) + 2L, '"'), sheet_top, fixed = TRUE)
  writeLines(enc2utf8(paste0(top, paste0(rows, collapse = ""), sheet_bottom)), sheet_file, useBytes = TRUE)
  staged_file <- tempfile("reviewer_", fileext = ".xlsx")
  zip::zipr(staged_file, template_parts[!endsWith(template_parts, "/")], root = template_dir, include_directories = FALSE, mode = "mirror")

  # Publish the completed workbook only if the destination is still free.
  saved <- file.copy(staged_file, files[i], overwrite = FALSE)
  unlink(staged_file)
  if (!saved) stop("Could not write reviewer workbook: ", files[i])
}

# Remove the unpacked working copy after all reviewer files have been written.
unlink(template_dir, recursive = TRUE)
