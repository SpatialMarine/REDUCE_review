# -----------------------------------------------------------------------------

# Title:

#-------------------------------------------------------------------------------
# 09. Prepare individual full-text screening workbooks 
#-------------------------------------------------------------------------------

library(readxl)
library(dplyr)
library(openxlsx)

# 1. Input and output paths -----------------------------------------------------

# 1.1. Read the assignment workbook from script 08 -----------------------------

assignment_file <- file.path(output_data, "full_text_screening", "split_fullText_screening.xlsx")
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

# 3.1. Define the options for the three dropdown columns ------------------------

dropdown_options <- list(
  rev1_name = c("ABC", "AEP", "BB", "CL", "CS", "DFF", "DK", "DM", "DRG", "EM", "GA",
                "ISM", "JB", "JCB", "JOB", "LNH", "MC", "NPS", "PGU", "TM"),
  FT_decisionRev1 = c("Accepted", "Rejected"),
  FT_exclCriteria_rev1 = c("LANGUAGE", "DOCUMENT", "NOTOPIC", "LOCATION", "GEAR", "TAXA", "STUDY_TYPE")
)
files <- file.path(reviewer_dir, paste0("full_text_", reviewer_codes[assigned_reviewers], ".xlsx"))

# Check all paths before writing so a rerun cannot overwrite completed reviews.
if (any(file.exists(files))) {
  stop("Reviewer workbooks already exist: ", paste(basename(files[file.exists(files)]), collapse = ", "))
}
dir.create(reviewer_dir, recursive = TRUE, showWarnings = FALSE)

# 3.2. Write the assigned papers, DOI links and per-row dropdowns ---------------

for (i in seq_along(assigned_reviewers)) {
  reviewer <- assigned_reviewers[i]
  code <- unname(reviewer_codes[reviewer])

  # Both assignment roles enter the same sheet, with one row per assigned paper.
  screening <- papers %>%
    filter(full_text_reviewer_1 == reviewer | full_text_reviewer_2 == reviewer) %>%
    select(all_of(paper_columns)) %>%
    mutate(rev_AI = NA_character_, FT_decisionAI = NA_character_, FT_exclCriteria_AI = NA_character_,
           notes_AI = NA_character_, rev1_name = code, FT_decisionRev1 = NA_character_, FT_exclCriteria_rev1 = NA_character_,
           notes = NA_character_)

  # Write the screening sheet first and keep the column headings visible.
  workbook <- createWorkbook()
  addWorksheet(workbook, "Full_text_screening")
  writeData(workbook, "Full_text_screening", screening, withFilter = TRUE)
  freezePane(workbook, "Full_text_screening", firstRow = TRUE)

  # Write DOI values as native Excel hyperlinks, leaving missing cells blank.
  for (row in which(!is.na(screening$doi))) {
    link <- structure(screening$doi[row], class = "hyperlink")
    writeData(workbook, "Full_text_screening", link, startCol = match("doi", names(screening)),
              startRow = row + 1L, colNames = FALSE)
  }

  # Name each range so Excel can use options stored on a different worksheet.
  addWorksheet(workbook, "dropdown")
  writeData(workbook, "dropdown", t(names(dropdown_options)), colNames = FALSE)
  for (column in seq_along(dropdown_options)) {
    field <- names(dropdown_options)[column]
    options <- dropdown_options[[column]]
    writeData(workbook, "dropdown", options, startCol = column, startRow = 2, colNames = FALSE)
    createNamedRegion(workbook, "dropdown", cols = column, rows = seq_along(options) + 1L, name = field)

    # Reuse the human decision and exclusion lists for the corresponding AI columns.
    fields <- switch(field,
      FT_decisionRev1 = c(field, "FT_decisionAI"),
      FT_exclCriteria_rev1 = c(field, "FT_exclCriteria_AI"),
      field
    )

    # Apply each list to all article rows in the matching column.
    for (review_field in fields) {
      dataValidation(workbook, "Full_text_screening", cols = match(review_field, names(screening)),
                     rows = seq_len(nrow(screening)) + 1L, type = "list", value = field,
                     allowBlank = TRUE, showErrorMsg = TRUE)
    }
  }

  # Give longer text fields room to read and save without replacing any workbook.
  setColWidths(workbook, "Full_text_screening", cols = seq_len(ncol(screening)), widths = 22)
  setColWidths(workbook, "Full_text_screening", cols = match(c("title", "abstract", "notes_AI", "notes"), names(screening)),
               widths = 55)
  setColWidths(workbook, "dropdown", cols = seq_along(dropdown_options), widths = 24)
  saveWorkbook(workbook, files[i], overwrite = FALSE)
}
