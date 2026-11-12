# -----------------------------------------------------------------------------
# 10. Report abstract-screening changes to each original reviewer
# -----------------------------------------------------------------------------

library(readxl)
library(dplyr)
library(stringr)
library(openxlsx)

# 1. Input and output paths ----------------------------------------------------

screening_file <- file.path(output_data, "abstract_screening", "abstract_screening_final.xlsx")
report_dir <- file.path(output_data, "abstract_screening", "feedback_screening", "reviewer_updates")

# 2. Read the original evaluations and consolidated screening ------------------

# 2.1. Check the input columns and unique paper IDs ----------------------------

# Use the same consolidated source and original reviewer slots as script 07.
input_hash <- unname(tools::md5sum(screening_file))
screening <- read_excel(screening_file, sheet = "final_screening", col_types = "text")

# Define the fields required for the original-to-final comparisons.
coding_fields <- c("decision", "TA_exclCriteria", "Topic", "TaxaGroup", "fishingGear")
final_columns <- c("final_decision", paste0(coding_fields[-1], "_final"))
review_columns <- character()
for (slot in 1:3) {
  # Include the same coding fields and notes for every reviewer slot.
  review_columns <- c(review_columns, paste0(c(coding_fields, "notes"), "_reviewer_", slot))
}

# Combine publication identifiers, adjudication controls and reviewer columns.
required_columns <- c(
  "paperID", "title", "abstract", "keywords", "doi", "reviewer_1", "reviewer_2",
  "requires_adjudication", "adjudication_status", final_columns, review_columns
)
missing_columns <- setdiff(required_columns, names(screening))

# Check the schema before selecting reviewer-specific fields.
if (length(missing_columns) > 0) {
  # Regenerate the consolidated input if the earlier pipeline lacks these fields.
  stop("Missing screening columns: ", paste(missing_columns, collapse = ", "))
}

# Reject ambiguous IDs before joining the two original reviewer slots.
screening$paperID <- str_squish(screening$paperID)

# Each publication must have a single unambiguous source row.
if (any(is.na(screening$paperID) | screening$paperID == "") || anyDuplicated(screening$paperID)) {
  stop("final_screening must contain one non-missing row per paperID.")
}

# Report completed, active adjudications and leave unresolved cases in script 05.
screening <- screening %>%
  mutate(reviewer3_active = coalesce(str_to_upper(requires_adjudication) == "TRUE", FALSE),
         reviewer3_resolved = reviewer3_active & coalesce(adjudication_status == "Resolved", FALSE))

# Report how many active adjudications are still unresolved.
pending_count <- sum(screening$reviewer3_active & !screening$reviewer3_resolved)
if (pending_count > 0) {
  # Pending adjudications have no completed outcome to present as final.
  message("Excluded ", pending_count, " unresolved Reviewer 3 article(s) from the change reports.")
}

# 2.2. Put each original reviewer beside the final values ----------------------

# A two-reviewer article belongs in both reports, using each reviewer's own values.
initial_slots <- vector("list", 2)
for (i in 1:2) {
  # Select the original values from the matching slot without altering their text.
  reviews <- screening
  reviews$reviewer <- str_squish(reviews[[paste0("reviewer_", i)]])

  # Carry the coding fields and notes from this original reviewer slot.
  for (field in c(coding_fields, "notes")) {
    reviews[[paste0(field, "_original")]] <- reviews[[paste0(field, "_reviewer_", i)]]
  }

  # Retain only named initial reviewers from the current slot.
  initial_slots[[i]] <- reviews %>% filter(!is.na(reviewer), reviewer != "")
}

# Combine the slots and validate the paper-reviewer key.
reviewer_rows <- bind_rows(initial_slots)
if (nrow(reviewer_rows) == 0 || anyDuplicated(reviewer_rows[c("paperID", "reviewer")])) {
  stop("Expected at least one evaluation and one row per original reviewer and paperID.")
}

# 3. Identify changes and additions -------------------------------------------

# 3.1. Compare the five coding fields -----------------------------------------

# Track the two types of intervention for cell highlighting and article selection.
changed_cells <- matrix(FALSE, nrow(reviewer_rows), length(coding_fields))
added_cells <- matrix(FALSE, nrow(reviewer_rows), length(coding_fields))
final_applicable <- matrix(TRUE, nrow(reviewer_rows), length(coding_fields))
for (i in seq_along(coding_fields)) {
  # Apply the same decision- and topic-dependent requirements as script 07.
  field <- coding_fields[i]
  original <- reviewer_rows[[paste0(field, "_original")]]
  final <- reviewer_rows[[final_columns[i]]]

  # Determine which fields still apply to the consolidated outcome.
  applicable <- switch(
    field,
    decision = rep(TRUE, nrow(reviewer_rows)),
    TA_exclCriteria = reviewer_rows$final_decision %in% "Rejected",
    TaxaGroup = reviewer_rows$final_decision %in% "Accepted" &
      coalesce(str_detect(str_to_lower(reviewer_rows$Topic_final), "megafauna catch"), FALSE),
    reviewer_rows$final_decision %in% "Accepted"
  )
  final_applicable[, i] <- applicable

  # Clear the displayed final value when the field ceased to apply after adjudication.
  final[!applicable] <- NA_character_

  # Compare selections as sets using script 07's separator, case and ordering rule.
  original_key <- character(length(original))
  final_key <- character(length(final))
  for (row in seq_along(original)) {
    # Normalise both selections locally while retaining their original export text.
    original_items <- str_split_1(coalesce(original[row], ""), "\\s*[/;,]\\s*")
    final_items <- str_split_1(coalesce(final[row], ""), "\\s*[/;,]\\s*")
    original_items <- sort(unique(str_to_lower(str_squish(original_items))))
    final_items <- sort(unique(str_to_lower(str_squish(final_items))))
    original_key[row] <- paste(original_items[nzchar(original_items)], collapse = " / ")
    final_key[row] <- paste(final_items[nzchar(final_items)], collapse = " / ")
  }

  # Distinguish replacements from additions for resolved Reviewer 3 interventions.
  active <- reviewer_rows$reviewer3_resolved
  changed_cells[, i] <- active & nzchar(original_key) & original_key != final_key
  added_cells[, i] <- active & !nzchar(original_key) & nzchar(final_key)
}

# 3.2. Highlight notes within articles selected by coding changes --------------

# Compare note text with spacing normalised, keeping its case and punctuation.
original_note <- coalesce(str_squish(reviewer_rows$notes_original), "")
reviewer3_note <- coalesce(str_squish(reviewer_rows$notes_reviewer_3), "")
note_updated <- reviewer_rows$reviewer3_resolved & nzchar(reviewer3_note) &
  original_note != reviewer3_note
note_changed <- note_updated & nzchar(original_note)
note_added <- note_updated & !nzchar(original_note)

# Include an article only when Reviewer 3 changed or completed a coding field.
include_article <- rowSums(changed_cells | added_cells) > 0
reports <- reviewer_rows[include_article, ]
changed_cells <- changed_cells[include_article, , drop = FALSE]
added_cells <- added_cells[include_article, , drop = FALSE]
final_applicable <- final_applicable[include_article, , drop = FALSE]
note_changed <- note_changed[include_article]
note_added <- note_added[include_article]

# 4. Prepare one single-sheet workbook per reviewer ---------------------------

# 4.1. Check output names before writing any reports ---------------------------

# Reviewer codes come from the original abstract-screening evaluations.
reviewer_codes <- sort(unique(reviewer_rows$reviewer))
safe_codes <- str_replace_all(reviewer_codes, "[^A-Za-z0-9_-]", "_")
report_files <- file.path(report_dir, paste0("reviewer_changes_", safe_codes, ".xlsx"))

# Keep every destination free before staging the reports.
if (anyDuplicated(tolower(report_files)) || any(file.exists(report_files))) {
  stop("Reviewer report names collide or already exist. Choose an empty report_dir.")
}

# Export to a temporary folder first so formatting errors do not publish partial reports.
staging_dir <- tempfile("reviewer_changes_")
dir.create(staging_dir)

# 4.2. Define the paired columns and shared styles ----------------------------

column_labels <- c(
  "Paper ID", "Title", "Abstract", "Keywords",
  "Original decision", "Final decision", "Original criterion", "Final criterion",
  "Original topic", "Final topic", "Original taxa", "Final taxa",
  "Original gear", "Final gear", "Your original note", "Reviewer 3 note"
)
widths <- c(11, 54, 86, 38, rep(23, 10), 64, 64)
sheet_name <- "Review changes"
title_style <- createStyle(fontSize = 16, textDecoration = "bold", fontColour = "#173E50")
group_style <- createStyle(fgFill = "#173E50", fontColour = "white", textDecoration = "bold",
                          halign = "center", valign = "center")
header_style <- createStyle(fgFill = "#DCE9EF", textDecoration = "bold", wrapText = TRUE,
                           valign = "center")
body_style <- createStyle(fontSize = 10, wrapText = TRUE, valign = "top")
changed_style <- createStyle(fgFill = "#FCE4D6", fontColour = "#9C3500")
added_style <- createStyle(fgFill = "#DDEBF7", fontColour = "#1F4E78")
link_style <- createStyle(fontColour = "#0563C1", textDecoration = "underline",
                         wrapText = TRUE, valign = "top", fontSize = 10)

for (reviewer_index in seq_along(reviewer_codes)) {
  # Sort the reviewer's selected articles by numeric ID, with a text fallback.
  code <- reviewer_codes[reviewer_index]
  selected <- which(reports$reviewer == code)
  selected <- selected[order(suppressWarnings(as.numeric(reports$paperID[selected])),
                             reports$paperID[selected], na.last = TRUE)]
  details <- reports[selected, ]

  # Keep every paired field visible, including the unchanged values for context.
  values <- details %>% select(paperID, title, abstract, keywords)
  for (i in seq_along(coding_fields)) {
    original <- details[[paste0(coding_fields[i], "_original")]]
    final <- details[[final_columns[i]]]
    final[!final_applicable[selected, i]] <- "Not applicable"
    values[[paste0(coding_fields[i], "_original")]] <- original
    values[[paste0(coding_fields[i], "_final")]] <- final
  }

  # Append the original and adjudication notes after the five comparison blocks.
  values$notes_original <- details$notes_original
  values$notes_reviewer3 <- details$notes_reviewer_3
  names(values) <- column_labels

  # Create the single worksheet and its base font.
  wb <- createWorkbook()
  addWorksheet(wb, sheet_name, gridLines = FALSE)
  modifyBaseFont(wb, fontName = "Aptos", fontSize = 10)

  # Add the reviewer title.
  writeData(wb, sheet_name, paste("Abstract-screening changes", code), startRow = 1, colNames = FALSE)
  mergeCells(wb, sheet_name, cols = 1:16, rows = 1)
  addStyle(wb, sheet_name, title_style, rows = 1, cols = 1)

  # Explain the meaning of the highlighted cells.
  legend <- paste("Orange = changed or no longer applicable. Blue = added.",
                  "Empty original cells were blank. Unchanged fields provide context.")
  writeData(wb, sheet_name, legend, startRow = 2, colNames = FALSE)
  mergeCells(wb, sheet_name, cols = 1:16, rows = 2)

  # Identify the source and number of included articles.
  source_note <- paste(nrow(values), "articles with updates.",
                       "Final values come from abstract_screening_final.xlsx after active, resolved Reviewer 3 review.")
  writeData(wb, sheet_name, source_note, startRow = 3, colNames = FALSE)
  mergeCells(wb, sheet_name, cols = 1:16, rows = 3)

  # Group the paired columns above the flat, filterable header.
  group_starts <- c(1, 5, 7, 9, 11, 13, 15)
  group_ends <- c(4, 6, 8, 10, 12, 14, 16)
  group_labels <- c("Publication", "Decision", "Exclusion criterion", "Topic", "Taxa group", "Fishing gear", "Notes")
  for (i in seq_along(group_starts)) {
    # Merge only the visual block labels, leaving row 5 usable for filters.
    writeData(wb, sheet_name, group_labels[i], startRow = 4, startCol = group_starts[i], colNames = FALSE)
    mergeCells(wb, sheet_name, cols = group_starts[i]:group_ends[i], rows = 4)
  }

  # Write the table and format its headers.
  addStyle(wb, sheet_name, group_style, rows = 4, cols = 1:16, gridExpand = TRUE)
  writeData(wb, sheet_name, values, startRow = 5, withFilter = TRUE, headerStyle = header_style)

  # Keep identifiers visible while scrolling and size the columns and header rows.
  freezePane(wb, sheet_name, firstActiveRow = 6, firstActiveCol = 3)
  setColWidths(wb, sheet_name, cols = 1:16, widths = widths)
  setRowHeights(wb, sheet_name, rows = c(1, 2, 3, 4, 5), heights = c(28, 22, 22, 24, 31))

  if (nrow(values) > 0) {
    # Wrap all source text and fit ordinary abstracts within Excel's row-height limit.
    data_rows <- seq_len(nrow(values)) + 5L
    addStyle(wb, sheet_name, body_style, rows = data_rows, cols = 1:16, gridExpand = TRUE)

    # Estimate wrapped text height for each displayed column and article.
    line_counts <- matrix(1L, nrow(values), length(widths))
    for (i in seq_along(widths)) {
      # Allow for padding when estimating the visible text width.
      text_width <- max(8L, floor(widths[i] * 0.9))

      # Estimate each cell's line count without splitting the formatting into helpers.
      for (row in seq_len(nrow(values))) {
        # Estimate wrapped lines from the actual displayed text in each cell.
        text <- coalesce(as.character(values[[i]][row]), "")
        line_counts[row, i] <- max(1L, length(strwrap(text, width = text_width)))
      }
    }

    # Respect Excel's maximum row height while keeping the complete cell values.
    row_heights <- pmin(409, pmax(50, apply(line_counts, 1, max) * 13 + 10))
    setRowHeights(wb, sheet_name, rows = data_rows, heights = row_heights)

    # Make the title itself clickable while retaining the supplied title text.
    doi <- str_trim(coalesce(details$doi, ""))
    doi <- sub("^(https?://(dx\\.)?doi\\.org/|doi:[[:space:]]*)", "", doi, ignore.case = TRUE)
    links <- which(grepl("^10\\.[0-9]{4,9}/[^[:space:]]+$", doi) &
                     !is.na(details$title) & nzchar(details$title))

    # Write the DOI formula directly in each linked title.
    for (row in links) {
      # Escape quotation marks in the hyperlink and displayed title.
      url <- gsub('"', '""', paste0("https://doi.org/", doi[row]), fixed = TRUE)
      label <- gsub('"', '""', details$title[row], fixed = TRUE)
      formula <- paste0('HYPERLINK("', url, '","', label, '")')
      writeFormula(wb, sheet_name, formula, startCol = 2, startRow = data_rows[row])
    }

    # Format only the titles with a valid DOI link.
    if (length(links) > 0) {
      addStyle(wb, sheet_name, link_style, rows = data_rows[links], cols = 2, stack = TRUE)
    }

    # Highlight only final cells that differ from this reviewer's original evaluation.
    for (i in seq_along(coding_fields)) {
      changed <- data_rows[changed_cells[selected, i]]
      added <- data_rows[added_cells[selected, i]]

      # Mark replaced values in orange.
      if (length(changed) > 0) {
        addStyle(wb, sheet_name, changed_style, rows = changed, cols = 4 + 2 * i, stack = TRUE)
      }

      # Mark newly supplied values in blue.
      if (length(added) > 0) {
        addStyle(wb, sheet_name, added_style, rows = added, cols = 4 + 2 * i, stack = TRUE)
      }
    }

    # Keep the two notes side by side and highlight the supplied Reviewer 3 rationale.
    changed <- data_rows[note_changed[selected]]
    added <- data_rows[note_added[selected]]

    # Mark revised rationales in orange.
    if (length(changed) > 0) {
      addStyle(wb, sheet_name, changed_style, rows = changed, cols = 16, stack = TRUE)
    }

    # Mark newly supplied rationales in blue.
    if (length(added) > 0) {
      addStyle(wb, sheet_name, added_style, rows = added, cols = 16, stack = TRUE)
    }
  } else {
    # Give reviewers with no interventions a usable report with the same columns.
    writeData(wb, sheet_name, "No coding changes from active, resolved Reviewer 3 review.",
              startRow = 6, colNames = FALSE)
    mergeCells(wb, sheet_name, cols = 1:16, rows = 6)
  }

  # Stage each workbook before publishing any of the reviewer reports.
  staged_file <- file.path(staging_dir, basename(report_files[reviewer_index]))
  saveWorkbook(wb, staged_file, overwrite = FALSE)

  # Remove openxlsx's unused drawing links from these text-only workbooks.
  package_dir <- tempfile("reviewer_report_package_")
  package_parts <- unzip(staged_file, list = TRUE)$Name
  unzip(staged_file, exdir = package_dir)
  rels_file <- file.path(package_dir, "xl", "worksheets", "_rels", "sheet1.xml.rels")
  rels <- paste(readLines(rels_file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  rels <- gsub('<Relationship[^>]+Type="[^"]+/(drawing|vmlDrawing)"[^>]*/>', "", rels)
  writeLines(rels, rels_file, useBytes = TRUE)
  zip::zipr(staged_file, package_parts[!endsWith(package_parts, "/")], root = package_dir,
            include_directories = FALSE, mode = "mirror")
  unlink(package_dir, recursive = TRUE)
}

# 4.3. Publish the completed reports ------------------------------------------

# Confirm that creating the reports left the source workbook intact.
if (!identical(input_hash, unname(tools::md5sum(screening_file)))) {
  stop("The screening source changed while the reports were being prepared.")
}
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

# Recheck destinations immediately before copying the staged files.
if (any(file.exists(report_files))) {
  stop("Reviewer report destination changed during export.")
}

# Publish the completed reviewer reports only after every destination has passed.
for (i in seq_along(report_files)) {
  # Copy only to a free destination and retain staged outputs if publication fails.
  saved <- file.copy(file.path(staging_dir, basename(report_files[i])), report_files[i], overwrite = FALSE)

  # Retain the staging folder if publishing a workbook fails.
  if (!saved) {
    stop("Could not write reviewer report: ", report_files[i])
  }
}

# Remove the temporary staging folder after successful publication.
unlink(staging_dir, recursive = TRUE)

# Report the destination after all workbooks have been saved.
message("Saved ", length(report_files), " single-sheet reviewer reports in ", report_dir)
