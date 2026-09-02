# -----------------------------------------------------------------------------

# Title:

#--------------------------------------------------------------------------------
# 04. Split abstract list among participants
#--------------------------------------------------------------------------------
library(readxl)
library(dplyr)
library(openxlsx)
library(writexl)

# 1. Load paper list------------------------------------------------------------
list <- read_excel(  file.path(input_data, "rm_duplicates", "paperList.xlsx"))
head(list)

trial <- read_excel(  file.path(input_data, "rm_duplicates", "CriteriaTrial_DRG_completed.xlsm"), sheet = 2)
head(trial)

# Merge results from trial:
list_updated <- list %>%
  left_join(
    trial %>%
      select(
        paperID,
        rev1_name,
        TA_decisionRev1,
        TA_exclCriteria_rev1,
        `notes (column only available in this trial)`,
        Topic,
        TaxaGroup),
    by = "paperID")


# 2. Split them by participants-------------------------------------------------
reviewers <- c(
  "DFF", "ISM", "LNH", "NPS", "PGU", "TM", "EM", "JOB",
  "DRG", "CS", "ABC", "AEP", "GA", "DK", "CL")

length(reviewers)
# 15

set.seed(123)
papers <- list_updated  # or your object name

n_papers <- nrow(papers)
n_papers

n_reviewers <- length(reviewers)
n_reviewers

# Number of papers to double-review
n_overlap <- round(n_papers * 0.25)

# Randomise paper order, but keep existing rev1_name where present
papers_split <- papers %>%
  slice_sample(prop = 1)

# Identify papers without assigned reviewer
missing_rev1 <- is.na(papers_split$rev1_name) | papers_split$rev1_name == ""

# Current workload from already assigned papers
current_load <- table(
  factor(papers_split$rev1_name[!missing_rev1], levels = reviewers)
)

# Assign only missing rev1_name, balancing total workload
for(i in which(missing_rev1)) {
  
  chosen_reviewer <- reviewers[which.min(current_load)]
  
  papers_split$rev1_name[i] <- chosen_reviewer
  
  current_load[chosen_reviewer] <- current_load[chosen_reviewer] + 1
}

# Select 25% of papers for second review
overlap_ids <- sample(papers_split$paperID, n_overlap)

# Add second reviewer
papers_split <- papers_split %>%
  mutate(
    rev2_name = NA_character_
  )

# Track workload for reviewer 2
rev2_load <- setNames(rep(0, n_reviewers), reviewers)

for (id in overlap_ids) {
  
  rev1 <- papers_split$rev1_name[papers_split$paperID == id]
  
  possible_rev2 <- reviewers[reviewers != rev1]
  
  # Choose reviewer with lowest current rev2 load
  chosen_rev2 <- possible_rev2[which.min(rev2_load[possible_rev2])]
  
  papers_split$rev2_name[papers_split$paperID == id] <- chosen_rev2
  
  rev2_load[chosen_rev2] <- rev2_load[chosen_rev2] + 1
}

workload <- bind_rows(
  papers_split %>% 
    filter(!is.na(rev1_name)) %>% 
    count(reviewer = rev1_name),
  
  papers_split %>% 
    filter(!is.na(rev2_name)) %>% 
    count(reviewer = rev2_name)
) %>%
  group_by(reviewer) %>%
  summarise(total_abstracts = sum(n), .groups = "drop") %>%
  arrange(reviewer)

workload

# Check overlap
pair_overlap <- papers_split %>%
  filter(!is.na(rev2_name)) %>%
  count(rev1_name, rev2_name, name = "n_shared") %>%
  arrange(desc(n_shared))

pair_overlap

n_papers
n_overlap
sum(!is.na(papers_split$rev2_name))


# Export dataset by reviewer
reviewer_datasets <- lapply(reviewers, function(r) {
  papers_split %>%
    filter(rev1_name == r | rev2_name == r) %>%
    mutate(
      rev1_name = r,
      rev2_name = NA_character_
    )
})

names(reviewer_datasets) <- reviewers
reviewer_datasets[["DRG"]]


# Export
output_dir <- file.path(input_data, "abstracts_byReviewer")
dir.create(output_dir, showWarnings = FALSE)

for(r in reviewers){
  
  df <- papers_split %>%
    filter(rev1_name == r | rev2_name == r) %>%
    
    # Make all assignments appear as reviewer 1
    mutate(
      rev1_name = r
    ) %>%
    
    # Rename long notes column
    rename(
      notes = `notes (column only available in this trial)`
    ) %>%
    
    # Remove rev2 column
    select(-rev2_name)
  
  write_xlsx(
    df,
    file.path(output_dir, paste0("Abstracts_", r, ".xlsx"))
  )
}


# 3. Add other extra spreadsheets-----------------------------------------------
# Copy the "dropDown" and "Criteria" worksheets from the template workbook
# (CriteriaTrial_DRG.xlsm) into every reviewer workbook, preserving formatting,
# data validation, drop-down lists, conditional formatting, etc.
#
# This script uses Microsoft Excel through PowerShell, so Excel must be
# installed on the computer.


# Define input and output folders
# Folder containing all reviewer workbooks
reviewer_dir <- file.path(input_data, "abstracts_byReviewer")

# Template workbook containing the worksheets to copy
criteria_file <- file.path(input_data, "CriteriaTrial/CriteriaTrial_DRG.xlsm")

# Output folder (original files are left untouched)
output_dir <- file.path(input_data, "abstracts_byReviewer_withCriteria")
dir.create(output_dir, showWarnings = FALSE)

# Recreate output folder
unlink(output_dir, recursive = TRUE)
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Find reviewer files
reviewer_files <- list.files(
  reviewer_dir,
  pattern = "^Abstracts_.*\\.xlsx$",
  full.names = TRUE
)

# Safety checks
stopifnot(file.exists(criteria_file))
stopifnot(length(reviewer_files) > 0)

# Convert paths for PowerShell
criteria_file_ps  <- normalizePath(criteria_file, winslash = "\\", mustWork = TRUE)
output_dir_ps <- normalizePath(output_dir, winslash = "\\", mustWork = FALSE)
reviewer_files_ps <- normalizePath(reviewer_files, winslash = "\\", mustWork = TRUE)


# Build PowerShell script
ps_code <- c(
  paste0("$criteria_file = '", criteria_file_ps, "'"),
  paste0("$output_dir = '", output_dir_ps, "'"),
  "$files = @(",
  paste0("'", reviewer_files_ps, "'", collapse = ",\n"),
  ")",
  "$sheets_to_copy = @('dropDown', 'Criteria')",
  "",
  "$excel = New-Object -ComObject Excel.Application",
  "$excel.Visible = $false",
  "$excel.DisplayAlerts = $false",
  "",
  "$template_wb = $excel.Workbooks.Open($criteria_file)",
  "",
  "foreach ($file in $files) {",
  "  Write-Host 'Processing:' $file",
  "",
  "  $out_file = Join-Path $output_dir (Split-Path $file -Leaf)",
  "  Copy-Item $file $out_file -Force",
  "",
  "  $target_wb = $excel.Workbooks.Open($out_file)",
  "",
  "  foreach ($sh in $sheets_to_copy) {",
  "",
  "    foreach ($ws in @($target_wb.Worksheets)) {",
  "      if ($ws.Name -eq $sh) { $ws.Delete() }",
  "    }",
  "",
  "    $after_sheet = $target_wb.Worksheets.Item($target_wb.Worksheets.Count)",
  "    $template_wb.Worksheets.Item($sh).Copy([System.Type]::Missing, $after_sheet)",
  "    $excel.ActiveSheet.Name = $sh",
  "",
  "  }",
  "",
  "  $target_wb.Save()",
  "  $target_wb.Close($false)",
  "}",
  "",
  "$template_wb.Close($false)",
  "$excel.Quit()"
)

# Write and run PowerShell script
ps_script <- file.path(tempdir(), "copy_excel_sheets.ps1")
writeLines(ps_code, ps_script)

system2(
  "powershell",
  args = c("-ExecutionPolicy", "Bypass", "-File", shQuote(ps_script))
)

# Check output
list.files(output_dir)




# 4. Add the dropdown option----------------------------------------------------
output_dir <- file.path(input_data, "abstracts_byReviewer_withCriteria")

files <- list.files(
  output_dir,
  pattern = "^Abstracts_.*\\.xlsx$",
  full.names = TRUE
)

for (f in files) {
  
  message("Adding dropdowns to: ", basename(f))
  
  wb <- loadWorkbook(f)
  
  # Sheet where reviewers will work
  main_sheet <- names(wb)[1]
  
  # Read headers from first row
  headers <- read.xlsx(f, sheet = main_sheet, rows = 1, colNames = FALSE)
  headers <- as.character(headers[1, ])
  
  # Add fishingGear column if it does not exist
  if (!"fishingGear" %in% headers) {
    data_main <- read.xlsx(f, sheet = main_sheet)
    data_main$fishingGear <- NA
    
    removeWorksheet(wb, main_sheet)
    addWorksheet(wb, main_sheet)
    writeData(wb, main_sheet, data_main)
    
    headers <- names(data_main)
  }
  
  # Reload workbook after possible rewrite
  saveWorkbook(wb, f, overwrite = TRUE)
  wb <- loadWorkbook(f)
  headers <- names(read.xlsx(f, sheet = main_sheet))
  
  # Identify columns
  col_decision <- which(headers == "TA_decisionRev1")
  col_excl     <- which(headers == "TA_exclCriteria_rev1")
  col_topic    <- which(headers == "Topic")
  col_taxa     <- which(headers == "TaxaGroup")
  col_gear     <- which(headers == "fishingGear")
  
  # Number of rows to apply dropdowns to
  n_rows <- nrow(read.xlsx(f, sheet = main_sheet)) + 1
  
  # Apply dropdowns using ranges from dropDown sheet
  dataValidation(wb, main_sheet,
                 cols = col_decision,
                 rows = 2:n_rows,
                 type = "list",
                 value = "'dropDown'!$B$3:$B$4")
  
  dataValidation(wb, main_sheet,
                 cols = col_excl,
                 rows = 2:n_rows,
                 type = "list",
                 value = "'dropDown'!$C$3:$C$9")
  
  dataValidation(wb, main_sheet,
                 cols = col_topic,
                 rows = 2:n_rows,
                 type = "list",
                 value = "'dropDown'!$E$3:$E$6")
  
  dataValidation(wb, main_sheet,
                 cols = col_taxa,
                 rows = 2:n_rows,
                 type = "list",
                 value = "'dropDown'!$F$3:$F$6")
  
  dataValidation(wb, main_sheet,
                 cols = col_gear,
                 rows = 2:n_rows,
                 type = "list",
                 value = "'dropDown'!$G$3:$G$5")
  
  saveWorkbook(wb, f, overwrite = TRUE)
}




# 5. Add format also the sheet1-------------------------------------------------
template_file <- file.path(
  input_data,
  "abstracts_byReviewer_withCriteria",
  "Abstracts_ABC.xlsx"   # or whichever file has the correct header
)

files <- list.files(
  output_dir,
  pattern = "^Abstracts_.*\\.xlsx$",
  full.names = TRUE
)

stopifnot(file.exists(template_file))
stopifnot(length(files) > 0)

# Read template workbook
template_file_ps <- normalizePath(template_file, winslash = "\\", mustWork = TRUE)
files_ps <- normalizePath(files, winslash = "\\", mustWork = TRUE)

ps_code <- c(
  paste0("$template_file = '", template_file_ps, "'"),
  "$files = @(",
  paste0("'", files_ps, "'", collapse = ",\n"),
  ")",
  "",
  "$excel = New-Object -ComObject Excel.Application",
  "$excel.Visible = $false",
  "$excel.DisplayAlerts = $false",
  "",
  "$template_wb = $excel.Workbooks.Open($template_file)",
  "$template_ws = $template_wb.Worksheets.Item(1)",
  "",
  "foreach ($file in $files) {",
  "  if ($file -eq $template_file) { continue }",
  "",
  "  Write-Host 'Formatting:' $file",
  "",
  "  $target_wb = $excel.Workbooks.Open($file)",
  "  $target_ws = $target_wb.Worksheets.Item(1)",
  "",
  "  # Copy formatting from rows 1 and 2",
  "  $template_ws.Rows('1:2').Copy()",
  "  $target_ws.Rows('1:2').PasteSpecial(-4122)",  # xlPasteFormats
  "",
  "  # Copy column widths",
  "  $template_ws.Rows('1:2').Copy()",
  "  $target_ws.Rows('1:2').PasteSpecial(8)",      # xlPasteColumnWidths
  "",
  "  # Copy row heights",
  "  $target_ws.Rows.Item(1).RowHeight = $template_ws.Rows.Item(1).RowHeight",
  "  $target_ws.Rows.Item(2).RowHeight = $template_ws.Rows.Item(2).RowHeight",
  "",
  "  $target_wb.Save()",
  "  $target_wb.Close($false)",
  "}",
  "",
  "$template_wb.Close($false)",
  "$excel.Quit()"
)

ps_script <- file.path(tempdir(), "copy_header_style.ps1")
writeLines(ps_code, ps_script)

system2(
  "powershell",
  args = c("-ExecutionPolicy", "Bypass", "-File", shQuote(ps_script))
)
