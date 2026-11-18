# -----------------------------------------------------------------------------

# Title:

# -----------------------------------------------------------------------------
# 11. PRISMA counts and editable PowerPoint workflow
# -----------------------------------------------------------------------------
# This script reads project inputs without modifying them.
# To test safely, set options(reduce.prisma.output_dir = tempfile("prisma-")) first.

library(readxl)
library(stringr)

# 1. Input and output paths ----------------------------------------------------

# Load project paths created by src/0_setup.R before reading any input.
if (!exists("input_data") || !exists("output_data")) stop("Load src/0_setup.R first.")
# Load the Scopus and Web of Science RIS exports used for identification.
ris_files <- file.path(input_data, "RIS", c("scopus.ris", "wos1.ris", "wos2.ris"))
# Load the deduplicated bibliographic list created by the existing REDUCE workflow.
paper_file <- file.path(input_data, "rm_duplicates", "paperList.xlsx")
# Load final title/abstract decisions.
screening_file <- file.path(output_data, "abstract_screening", "abstract_screening_final.xlsx")
# Load optional manual corrections for unclassified abstract exclusions.
correction_file <- file.path(output_data, "abstract_screening_exclusion_assignments.xlsx")
# Locate reviewer workbooks and PDF trackers for the full-text stage.
reviewer_dir <- file.path(output_data, "full_text_screening", "by_reviewer")
# Load the full-text assignment roster used to identify expected reviewers.
assignment_file <- file.path(output_data, "full_text_screening", "split_fullText_screening.xlsx")
# Load the optional report-to-study mapping needed to count unique studies.
study_map_file <- file.path(input_data, "prisma_study_map.csv")
# Define the folder for CSV audits and the editable PowerPoint.
export_dir <- getOption("reduce.prisma.output_dir", file.path(output_data, "PRISMA"))
# Show the result of this block.
message("\n--- Input paths ---")
print(c(ris_files, paper_file, screening_file, correction_file, reviewer_dir, assignment_file, study_map_file, export_dir))

# A report is one paperID; an optional paperID/studyID map links multiple reports of one study.
# Missing map entries keep the study count pending rather than equating reports with studies.
export_ppt <- getOption("reduce.prisma.export_ppt", TRUE)

# 2. Identification and duplicate removal -------------------------------------

# 2.1. Read complete raw RIS records before any importer deduplication ----------

# Read TY/ER record boundaries directly; some importers remove within-file duplicates.
# These field and DOI rules reproduce script 02, including its title fallback.
raw_records <- list()
for (file in ris_files) {
  # Decode the BOM and require a complete, non-nested sequence of RIS records.
  if (!file.exists(file)) stop("Missing RIS file: ", file)
  lines <- readLines(file, warn = FALSE, encoding = "UTF-8")
  lines <- sub("^\ufeff", "", lines)
  starts <- which(grepl("^TY  -", lines))
  ends <- which(grepl("^ER  -", lines))
  if (!length(starts) || length(starts) != length(ends) || any(starts >= ends) ||
      (length(starts) > 1 && any(starts[-1] <= ends[-length(ends)]))) {
    stop("Unbalanced or nested RIS boundaries: ", file)
  }

  # Keep every exported record, including duplicates, with its original file position.
  records <- data.frame(source_file = basename(file), source_record = seq_along(starts),
                        database = if (grepl("scopus", basename(file))) "Scopus" else "Web of Science",
                        doi = NA_character_, title = NA_character_)
  for (i in seq_along(starts)) {
    # Use the same DOI and title tags as the original RIS exports.
    entry <- lines[seq.int(starts[i], ends[i])]
    doi_line <- grep("^DO  -", entry, value = TRUE)
    title_line <- grep("^(TI|T1)  -", entry, value = TRUE)
    if (length(doi_line)) records$doi[i] <- paste(sub("^DO  - ?", "", doi_line), collapse = " and ")
    if (length(title_line)) records$title[i] <- paste(sub("^(TI|T1)  - ?", "", title_line), collapse = " and ")
  }
  raw_records[[basename(file)]] <- records
}
raw_records <- do.call(rbind, raw_records)
rownames(raw_records) <- NULL

# Show the result of this block.
message("\n--- Raw RIS records loaded ---")
message("Rows: ", nrow(raw_records), " | Columns: ", ncol(raw_records))
print(utils::head(raw_records, 3))

# Load the saved post-deduplication paper list for reconciliation.
papers <- readxl::read_excel(paper_file, col_types = "text")
required <- c("paperID", "doi", "title")
if (!all(required %in% names(papers))) stop("paperList lacks: ", paste(setdiff(required, names(papers)), collapse = ", "))
if (anyNA(papers$paperID) || anyDuplicated(papers$paperID)) stop("paperList needs unique, non-missing paperID values.")
key_tables <- list(raw_records, as.data.frame(papers))
for (i in seq_along(key_tables)) {
  # Apply the DOI cleaning and ASCII title fallback used in src/02_Handling_RIS.R.
  x <- key_tables[[i]]
  doi <- stringr::str_to_lower(stringr::str_trim(x$doi))
  doi <- sub("^doi\\s*:\\s*", "", doi)
  doi <- sub("^https?://(dx\\.)?doi\\.org/", "", doi)
  doi <- sub("[\\s\\.;,\\)]+$", "", doi, perl = TRUE)
  title <- stringr::str_squish(stringr::str_to_lower(x$title))
  title <- stringr::str_replace_all(title, "[^a-z0-9\\s]", "")
  x$dedup_key <- ifelse(!is.na(doi) & doi != "", doi, title)
  if (anyNA(x$dedup_key) || any(x$dedup_key == "")) stop("A record has neither DOI nor usable title.")
  key_tables[[i]] <- x
}
raw_records <- key_tables[[1]]
papers <- key_tables[[2]]
# Show the result of this block.
message("\n--- DOI/title keys normalised ---")
message("Rows: ", nrow(papers), " | Columns: ", ncol(papers))
print(utils::head(papers[c("paperID", "doi", "dedup_key")], 3))

# 2.2. Reconcile duplicates against the actual screening population ------------

# Stop rather than interpreting unexplained differences as duplicate removals.
raw_records$duplicate_removed <- duplicated(raw_records$dedup_key)
raw_keys <- unique(raw_records$dedup_key)
if (anyDuplicated(papers$dedup_key) || !setequal(raw_keys, papers$dedup_key)) {
  stop("RIS keys do not reconcile with paperList.xlsx. Check changed RIS inputs or deduplication rules; no PRISMA totals exported.")
}
raw_records$paperID <- papers$paperID[match(raw_records$dedup_key, papers$dedup_key)]
database_counts <- as.data.frame(table(raw_records$database), stringsAsFactors = FALSE)
names(database_counts) <- c("database", "records")
n_identified <- nrow(raw_records)
n_duplicates <- sum(raw_records$duplicate_removed)
n_screened <- nrow(papers)
stopifnot(n_identified - n_duplicates == n_screened)
# Show the result of this block.
message("\n--- Identification reconciled ---")
print(database_counts, row.names = FALSE)
message("Identified: ", n_identified, " | duplicates: ", n_duplicates, " | after deduplication: ", n_screened)

# 3. Title and abstract screening ---------------------------------------------

# 3.1. Read final human decisions and optional script-06 corrections -----------

# Count each screened paper once; no reviewer rows or AI suggestions enter this denominator.
screening <- readxl::read_excel(screening_file, sheet = "final_screening", col_types = "text")
required <- c("paperID", "final_decision", "TA_exclCriteria_final")
if (!all(required %in% names(screening))) stop("Missing final screening columns.")
if (anyNA(screening$paperID) || anyDuplicated(screening$paperID) ||
    !setequal(screening$paperID, papers$paperID)) stop("Screening IDs do not match the post-deduplication list.")
screening$criterion <- screening$TA_exclCriteria_final
# Show the result of this block.
message("\n--- Abstract-screening workbook loaded ---")
message("Rows: ", nrow(screening), " | Columns: ", ncol(screening))
print(utils::head(screening[c("paperID", "final_decision", "criterion")], 3))

# Apply only saved manual corrections, using the precedence in script 06.
if (file.exists(correction_file)) {
  corrections <- readxl::read_excel(correction_file, sheet = "exclusion_assignments", col_types = "text")
  required <- c("paperID", "TA_exclCriteria_assignment")
  if (!all(required %in% names(corrections)) || anyDuplicated(corrections$paperID)) stop("Invalid exclusion correction workbook.")
  values <- corrections$TA_exclCriteria_assignment[match(screening$paperID, corrections$paperID)]
  use <- !is.na(values) & stringr::str_squish(values) != ""
  screening$criterion[use] <- values[use]
}

# Standardise spelling only; preserve one exclusion reason per paper for additive counts.
criteria <- c("LANGUAGE", "DOCUMENT", "NOTOPIC", "LOCATION", "GEAR", "TAXA", "STUDY_TYPE")
screening$criterion <- gsub("-", "_", stringr::str_to_upper(stringr::str_squish(screening$criterion)))
screening$final_decision <- stringr::str_squish(screening$final_decision)
if (anyNA(screening$final_decision) || any(!screening$final_decision %in% c("Accepted", "Rejected"))) {
  stop("Title/abstract screening is incomplete; resolve pending decisions before reporting a completed flow.")
}
rejected <- screening$final_decision == "Rejected"
if (anyNA(screening$criterion[rejected]) || any(!screening$criterion[rejected] %in% criteria)) {
  stop("A rejected abstract lacks one recognised exclusion reason. Resolve it without double-counting reasons.")
}
ta_exclusions <- data.frame(criterion = criteria, n = as.integer(table(factor(screening$criterion[rejected], levels = criteria))))
n_ta_excluded <- sum(rejected)
sought_ids <- screening$paperID[!rejected]
n_sought <- length(sought_ids)
stopifnot(n_screened == n_ta_excluded + n_sought, sum(ta_exclusions$n) == n_ta_excluded)
# Show the result of this block.
message("\n--- Title/abstract screening completed ---")
print(ta_exclusions, row.names = FALSE)
message("Screened: ", n_screened, " | excluded: ", n_ta_excluded, " | sought for retrieval: ", n_sought)

# 4. Retrieval and full-text eligibility --------------------------------------

# 4.1. Reconcile PDF trackers across reviewer folders --------------------------

# A copied PDF for a second reviewer does not constitute a second retrieved report.
tracker_files <- list.files(file.path(reviewer_dir, "Papers"), "^PDF_tracker_.*\\.xlsx$", recursive = TRUE, full.names = TRUE)
tracker_rows <- list()
for (file in tracker_files) {
  # Locate the actual header underneath the tracker's introductory panel.
  header <- suppressMessages(readxl::read_excel(file, sheet = "PDF tracker", col_names = FALSE, n_max = 20, col_types = "text"))
  header_row <- which(as.character(header[[1]]) == "Paper ID")
  if (length(header_row) != 1) stop("Cannot locate tracker header: ", file)
  x <- readxl::read_excel(file, sheet = "PDF tracker", skip = header_row - 1, col_types = "text")
  required <- c("Paper ID", "PDF in folder?", "PDF path relative to this folder", "PDF verification")
  if (!all(required %in% names(x))) stop("Tracker columns changed: ", file)

  # Require a real local PDF for Yes; No is a retrieval status, not an eligibility rejection.
  paths <- file.path(dirname(file), x[["PDF path relative to this folder"]])
  tracker_rows[[file]] <- data.frame(paperID = x[["Paper ID"]], tracker = file,
    reported = stringr::str_squish(x[["PDF in folder?"]]),
    verification = stringr::str_squish(x[["PDF verification"]]),
    path = paths, exists = file.exists(paths))
}
trackers <- if (length(tracker_rows)) do.call(rbind, tracker_rows) else data.frame(paperID = character())
# Show the result of this block.
message("\n--- PDF trackers loaded ---")
message("Rows: ", nrow(trackers), " | Columns: ", ncol(trackers))
print(utils::head(trackers, 3))
retrieval <- data.frame(paperID = sought_ids, status = "Pending verification", verified = FALSE)
for (i in seq_along(sought_ids)) {
  # Any available copy resolves retrieval; contradictory, missing or stale entries remain pending.
  x <- trackers[which(trackers$paperID == sought_ids[i]), , drop = FALSE]
  if (!nrow(x)) next
  available <- !is.na(x$reported) & x$reported == "Yes" & x$exists
  if (any(available)) {
    retrieval$status[i] <- "Retrieved"
    retrieval$verified[i] <- any(available & !is.na(x$verification) & x$verification == "Verified")
  } else if (all(!is.na(x$reported) & x$reported == "No")) {
    retrieval$status[i] <- "Not retrieved"
  }
}

# Only publish total retrieval counts once every sought paper has a resolved status.
retrieval_complete <- all(retrieval$status != "Pending verification")
n_not_retrieved_recorded <- sum(retrieval$status == "Not retrieved")
n_retrieval_pending <- sum(retrieval$status == "Pending verification")
n_not_retrieved <- if (retrieval_complete) sum(retrieval$status == "Not retrieved") else NA_integer_
n_available <- if (retrieval_complete) n_sought - n_not_retrieved else NA_integer_
# Show the result of this block.
message("\n--- Retrieval status calculated ---")
message("Rows: ", nrow(retrieval), " | Columns: ", ncol(retrieval))
print(utils::head(retrieval, 3))
print(table(retrieval$status, useNA = "always"))

# 4.2. Collapse result rows into independent human paper/reviewer assessments ---

# Never substitute FT_decisionAI for the human decision required by the protocol.
review_files <- list.files(reviewer_dir, "^full_text_[A-Z]+\\.xls[mx]$", full.names = TRUE)
review_rows <- list()
ai_ids <- character()
for (file in review_files) {
  # Locate paperID below the workbook's grouped column headings.
  header <- suppressMessages(readxl::read_excel(file, sheet = "dataExtraction", col_names = FALSE, n_max = 10, col_types = "text"))
  header_row <- which(as.character(header[[1]]) == "paperID")
  if (length(header_row) != 1) stop("Cannot locate extraction header: ", file)
  x <- readxl::read_excel(file, sheet = "dataExtraction", skip = header_row - 1, col_types = "text")
  required <- c("paperID", "rev1_name", "FT_decisionRev1", "FT_exclCriteria_rev1", "FT_decisionAI")
  if (!all(required %in% names(x))) stop("Missing review columns: ", file)

  # Ignore blank template rows; retain all result rows to detect inconsistent paper decisions.
  x <- x[!is.na(x$paperID) & x$paperID %in% sought_ids, ]
  ai_ids <- union(ai_ids, x$paperID[x$FT_decisionAI %in% c("Accepted", "Rejected")])
  review_rows[[file]] <- data.frame(paperID = x$paperID, reviewer = x$rev1_name,
    decision = stringr::str_squish(x$FT_decisionRev1),
    criterion = gsub("-", "_", stringr::str_to_upper(stringr::str_squish(x$FT_exclCriteria_rev1))),
    file = file)
}
reviews <- if (length(review_rows)) do.call(rbind, review_rows) else data.frame(paperID = character())
# Show the result of this block.
message("\n--- Human full-text review rows loaded ---")
message("Rows: ", nrow(reviews), " | Columns: ", ncol(reviews))
print(utils::head(reviews, 3))

# Use the assignment roster so a missing second-reviewer workbook cannot imply consensus.
assignments <- readxl::read_excel(assignment_file, sheet = "Full_text_papers", col_types = "text")
required <- c("paperID", "full_text_reviewer_1", "full_text_reviewer_2")
if (!all(required %in% names(assignments)) || anyDuplicated(assignments$paperID) ||
    !setequal(assignments$paperID, sought_ids)) stop("Full-text assignments do not match the sought reports.")
# Show the result of this block.
message("\n--- Full-text assignment roster loaded ---")
message("Rows: ", nrow(assignments), " | Columns: ", ncol(assignments))
print(utils::head(assignments[required], 3))
eligibility <- data.frame(paperID = sought_ids, decision = NA_character_, criterion = NA_character_, issue = "No human assessment")
for (i in seq_along(sought_ids)) {
  # All assigned human assessments and linked result rows must agree before consolidation.
  x <- reviews[which(reviews$paperID == sought_ids[i]), , drop = FALSE]
  if (!nrow(x)) next
  expected <- unlist(assignments[assignments$paperID == sought_ids[i], required[-1]], use.names = FALSE)
  expected <- expected[!is.na(expected) & trimws(expected) != ""]
  if (!setequal(expected, unique(x$reviewer))) {
    eligibility$issue[i] <- "Assigned reviewer assessment missing or unexpected reviewer"
    next
  }
  if (anyNA(x$reviewer) || anyNA(x$decision) || any(!x$decision %in% c("Accepted", "Rejected"))) {
    eligibility$issue[i] <- "Pending human decision"
    next
  }
  if (length(unique(x$decision)) != 1) {
    eligibility$issue[i] <- "Human decisions conflict"
    next
  }
  if (x$decision[1] == "Rejected" && (anyNA(x$criterion) ||
      any(!x$criterion %in% criteria) || length(unique(x$criterion)) != 1)) {
    eligibility$issue[i] <- "Missing or conflicting human exclusion reason"
    next
  }
  if (x$decision[1] == "Accepted" && any(!is.na(x$criterion) & x$criterion != "")) {
    eligibility$issue[i] <- "Accepted report has an exclusion reason"
    next
  }

  # Keep missing retrieval or PDF checks visible even when an eligibility decision is populated.
  if (retrieval$status[i] != "Retrieved" || !retrieval$verified[i]) {
    eligibility$issue[i] <- "Human decision present; retrieval/PDF check unresolved"
    next
  }
  eligibility$decision[i] <- x$decision[1]
  eligibility$criterion[i] <- if (x$decision[1] == "Rejected") x$criterion[1] else NA_character_
  eligibility$issue[i] <- "Resolved"
}
# Show the result of this block.
message("\n--- Human full-text eligibility assessed ---")
message("Rows: ", nrow(eligibility), " | Columns: ", ncol(eligibility))
print(utils::head(eligibility, 3))
print(table(eligibility$issue, useNA = "always"))

# Publish final full-text totals only when all available reports have resolved human decisions.
available_ids <- retrieval$paperID[retrieval$status == "Retrieved"]
ft_complete <- retrieval_complete && all(!is.na(eligibility$decision[match(available_ids, eligibility$paperID)]))
n_assessed <- if (ft_complete) n_available else NA_integer_
n_ft_excluded <- if (ft_complete) sum(eligibility$decision %in% "Rejected") else NA_integer_
n_included_reports <- if (ft_complete) sum(eligibility$decision %in% "Accepted") else NA_integer_
ft_exclusions <- data.frame(criterion = criteria, n = NA_integer_)
if (ft_complete) {
  # Count one primary human exclusion reason per report, independently of extraction rows.
  ft_exclusions$n <- as.integer(table(factor(eligibility$criterion[eligibility$decision %in% "Rejected"], levels = criteria)))
  stopifnot(n_assessed == n_ft_excluded + n_included_reports, sum(ft_exclusions$n) == n_ft_excluded)
}
# Show the result of this block.
message("\n--- Full-text exclusion summary ---")
print(ft_exclusions, row.names = FALSE)
message("Full-text complete: ", ft_complete, " | assessed: ", if (is.na(n_assessed)) "Pending" else n_assessed, " | included reports: ", if (is.na(n_included_reports)) "Pending" else n_included_reports)

# Count underlying studies only from an explicit mapping; publications are not always studies.
n_included_studies <- NA_integer_
if (ft_complete && n_included_reports == 0) n_included_studies <- 0L
if (ft_complete && n_included_reports > 0 && file.exists(study_map_file)) {
  # Require a complete, unique report-to-study mapping for all included reports.
  study_map <- read.csv(study_map_file, colClasses = "character", check.names = FALSE)
  if (!all(c("paperID", "studyID") %in% names(study_map)) || anyDuplicated(study_map$paperID)) stop("Invalid prisma_study_map.csv.")
  included_ids <- eligibility$paperID[eligibility$decision %in% "Accepted"]
  study_ids <- study_map$studyID[match(included_ids, study_map$paperID)]
  if (!anyNA(study_ids) && all(trimws(study_ids) != "")) n_included_studies <- length(unique(study_ids))
}
message("Unique included studies: ", if (is.na(n_included_studies)) "Pending" else n_included_studies, " (requires a complete paperID/studyID map)")

# 5. Export auditable counts --------------------------------------------------

# Keep unknown totals as NA in tables and Pending in the figure; never present them as zero.
counts <- data.frame(stage = c("Databases", "Records identified", "Duplicate records removed",
  "Records screened", "Records excluded (title/abstract)", "Reports sought for retrieval",
  "Reports not retrieved", "Reports available for assessment", "Reports assessed for eligibility",
  "Reports excluded (full text)", "Reports of included studies", "Studies included in review"),
  n = c(2, n_identified, n_duplicates, n_screened, n_ta_excluded, n_sought,
        n_not_retrieved, n_available, n_assessed, n_ft_excluded, n_included_reports, n_included_studies))
counts$status <- ifelse(is.na(counts$n), "Pending", "Calculated")
counts$note <- ""
counts$note[counts$stage == "Reports not retrieved"] <- paste0(n_not_retrieved_recorded,
  " recorded not retrieved; ", n_retrieval_pending, " reports have unresolved retrieval status.")
counts$note[counts$stage == "Studies included in review"] <- "Unique underlying studies require a complete paperID/studyID map."
dir.create(export_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(counts, file.path(export_dir, "PRISMA_counts.csv"), row.names = FALSE, na = "")
write.csv(database_counts, file.path(export_dir, "PRISMA_databases.csv"), row.names = FALSE)
write.csv(raw_records, file.path(export_dir, "PRISMA_record_audit.csv"), row.names = FALSE)
write.csv(ta_exclusions, file.path(export_dir, "PRISMA_abstract_exclusions.csv"), row.names = FALSE)
write.csv(ft_exclusions, file.path(export_dir, "PRISMA_full_text_exclusions.csv"), row.names = FALSE, na = "")
write.csv(retrieval, file.path(export_dir, "PRISMA_retrieval_audit.csv"), row.names = FALSE)
write.csv(eligibility, file.path(export_dir, "PRISMA_human_eligibility_audit.csv"), row.names = FALSE, na = "")
print(counts, row.names = FALSE)
print(ta_exclusions, row.names = FALSE)
# Show the result of this block.
message("\n--- CSV audit files written ---")
message("CSV output directory: ", export_dir)

# 6. Editable PowerPoint figure -----------------------------------------------

# 6.1. Prepare the official PRISMA flow and clearly separate AI assistance ------

# Native OOXML objects remain editable in PowerPoint; no drawing is rasterised.
if (export_ppt && !requireNamespace("zip", quietly = TRUE)) {
  stop("Counts were exported. The R package 'zip' is required for PowerPoint export.")
}
if (export_ppt) {
  # Format all unknown values explicitly and keep exclusion labels in protocol order.
  # Format slide counts and label unresolved totals.
  slide_counts <- c(n_identified = n_identified, n_duplicates = n_duplicates, n_screened = n_screened,
    n_ta_excluded = n_ta_excluded, n_sought = n_sought, n_not_retrieved = n_not_retrieved,
    n_assessed = n_assessed, n_available = n_available, n_ft_excluded = n_ft_excluded,
    n_included_studies = n_included_studies, n_included_reports = n_included_reports)
  slide_labels <- setNames(format(slide_counts, big.mark = ",", scientific = FALSE, trim = TRUE), names(slide_counts))
  slide_labels[is.na(slide_counts)] <- "Pending"
  ta_lines <- paste0(ta_exclusions$criterion, " (n = ", ta_exclusions$n, ")", collapse = "\n")
  ft_lines <- if (ft_complete) paste0(ft_exclusions$criterion, " (n = ", ft_exclusions$n, ")", collapse = "\n") else "Reasons and counts pending\nhuman full-text screening"
  database_lines <- paste0(database_counts$database, " (n = ", format(database_counts$records, big.mark = ",", trim = TRUE), ")", collapse = "\n")
  ai_text <- paste0("AI assistance and human oversight\n\n",
    "Title/abstract counts use final human decisions in the adjudicated dataset.\n\n",
    "Full-text protocol: AI screens reports and extracts provisional data for AI-accepted reports.\n\n",
    "The assigned human reviewer checks eligibility and extraction and records an independent decision.\n\n",
    "Only human decisions enter final PRISMA counts. Disagreements remain pending.\n\n",
    "AI full-text decisions recorded: ", length(ai_ids), " unique reports. This is not the final inclusion count.")

  # 6.2. Draw native objects on a single landscape slide -----------------------

  # Use a 14-by-10-inch slide with native DrawingML objects and a blank layout.
  ppt <- character()
  shape_id <- 1L

  # Escape dynamic text before it enters the XML package.
  xml_text <- function(x) {
    # Replace XML control characters in source labels without changing their displayed meaning.
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x
  }

  # One helper keeps native text-box formatting consistent across all diagram nodes.
  add_box <- function(ppt, label, x, y, w, h, fill = "E6EFF6", size = 13, colour = "17364D", bold = FALSE) {
    # Keep each diagram node as one shape containing editable text paragraphs.
    shape_id <<- shape_id + 1L
    paragraphs <- paste0('<a:p><a:pPr algn="ctr"/><a:r><a:rPr lang="en-US" sz="', size * 100,
      '" b="', as.integer(bold), '"><a:solidFill><a:srgbClr val="', colour,
      '"/></a:solidFill><a:latin typeface="Arial"/></a:rPr><a:t>',
      xml_text(strsplit(label, "\n", fixed = TRUE)[[1]]), '</a:t></a:r></a:p>', collapse = "")
    shape <- paste0('<p:sp><p:nvSpPr><p:cNvPr id="', shape_id, '" name="Node ', shape_id,
      '"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="', round(x * 914400),
      '" y="', round(y * 914400), '"/><a:ext cx="', round(w * 914400), '" cy="', round(h * 914400),
      '"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val="', fill,
      '"/></a:solidFill><a:ln w="12700"><a:solidFill><a:srgbClr val="34556C"/></a:solidFill></a:ln></p:spPr>',
      '<p:txBody><a:bodyPr wrap="square" anchor="ctr" lIns="50000" rIns="50000" tIns="25000" bIns="25000"/>',
      '<a:lstStyle/>', paragraphs, '</p:txBody></p:sp>')
    c(ppt, shape)
  }

  # Native line shapes connect the official identification, screening and inclusion stages.
  add_arrow <- function(ppt, x, y, w, h, horizontal = FALSE) {
    # Use native connectors with an arrowhead, rather than an arrow character.
    shape_id <<- shape_id + 1L
    if (!horizontal) {
      x <- x + w / 2
      w <- 0
    } else {
      y <- y + h / 2
      h <- 0
    }
    connector <- paste0('<p:cxnSp><p:nvCxnSpPr><p:cNvPr id="', shape_id,
      '" name="Arrow ', shape_id, '"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr>',
      '<p:spPr><a:xfrm><a:off x="', round(x * 914400), '" y="', round(y * 914400),
      '"/><a:ext cx="', round(w * 914400), '" cy="', round(h * 914400),
      '"/></a:xfrm><a:prstGeom prst="line"><a:avLst/></a:prstGeom><a:ln w="19050">',
      '<a:solidFill><a:srgbClr val="34556C"/></a:solidFill><a:tailEnd type="triangle"/></a:ln></p:spPr></p:cxnSp>')
    c(ppt, connector)
  }

  # Keep the official flow topology; report counts of records rather than calling them registers.
  ppt <- add_box(ppt, "REDUCE systematic review | PRISMA 2020", 0.2, 0.1, 13.6, 0.55, "17364D", 22, "FFFFFF", TRUE)
  ppt <- add_box(ppt, "Identification of studies via databases", 0.9, 0.85, 8.5, 0.4, "D6E5F0", 14, bold = TRUE)
  ppt <- add_box(ppt, paste0("Records identified from databases (n = 2)\nTotal records (n = ", slide_labels[["n_identified"]], ")\n", database_lines), 0.9, 1.5, 4, 1.2)
  ppt <- add_box(ppt, paste0("Records removed before screening:\nDuplicate records (n = ", slide_labels[["n_duplicates"]], ")\nNo other pre-screening removal inferred"), 5.6, 1.5, 3.8, 1.2, "F2F2F2")
  ppt <- add_arrow(ppt, 4.9, 1.85, 0.7, 0.4, TRUE)
  ppt <- add_arrow(ppt, 2.4, 2.7, 0.8, 0.4)
  ppt <- add_box(ppt, paste0("Records screened\n(title and abstract)\n(n = ", slide_labels[["n_screened"]], ")"), 0.9, 3.2, 4, 0.95)
  ppt <- add_box(ppt, paste0("Records excluded (n = ", slide_labels[["n_ta_excluded"]], ")\n", ta_lines), 5.6, 3.0, 3.8, 1.85, "F2F2F2", 12)
  ppt <- add_arrow(ppt, 4.9, 3.45, 0.7, 0.4, TRUE)
  ppt <- add_arrow(ppt, 2.4, 4.15, 0.8, 0.4)
  ppt <- add_box(ppt, paste0("Reports sought for retrieval\n(n = ", slide_labels[["n_sought"]], ")"), 0.9, 4.9, 4, 0.75)
  ppt <- add_box(ppt, paste0("Reports not retrieved (n = ", slide_labels[["n_not_retrieved"]], ")\n", n_not_retrieved_recorded,
    " recorded; ", n_retrieval_pending, " pending checks"), 5.6, 5.0, 3.8, 0.7, "F2F2F2", 12)
  ppt <- add_arrow(ppt, 4.9, 5.05, 0.7, 0.4, TRUE)
  ppt <- add_arrow(ppt, 2.4, 5.65, 0.8, 0.4)
  ppt <- add_box(ppt, paste0("Reports assessed for eligibility\n(n = ", slide_labels[["n_assessed"]], ")\nAvailable for assessment: ", slide_labels[["n_available"]]), 0.9, 6.15, 4, 1)
  ppt <- add_box(ppt, paste0("Reports excluded (n = ", slide_labels[["n_ft_excluded"]], ")\n", ft_lines), 5.6, 6.15, 3.8, 1.85, "F2F2F2", 12)
  ppt <- add_arrow(ppt, 4.9, 6.4, 0.7, 0.4, TRUE)
  ppt <- add_arrow(ppt, 2.4, 7.15, 0.8, 0.4)
  ppt <- add_box(ppt, paste0("Studies included in review (n = ", slide_labels[["n_included_studies"]], ")\nReports of included studies (n = ", slide_labels[["n_included_reports"]], ")"), 0.9, 8.1, 4, 1, "D6E8DD", 13, bold = TRUE)
  ppt <- add_box(ppt, ai_text, 10, 1.5, 3.7, 6.5, "EEF5F0", 13)

  # Include source attribution and clarify that retrieval does not equal completed eligibility assessment.
  footer <- paste0("Adapted from Page MJ et al. BMJ 2021;372:n71. doi:10.1136/bmj.n71 | CC BY 4.0\n",
    "Pending = incomplete or unresolved. Retrieved reports are available for assessment, not necessarily assessed.\n",
    "Study counts require input/prisma_study_map.csv (paperID, studyID). Inputs read on ", Sys.Date(), ".")
  ppt <- add_box(ppt, footer, 0.2, 9.25, 13.6, 0.65, "FFFFFF", 9)

  # 6.3. Package the slide, master, layout and theme as a standard .pptx --------

  # Keep XML scaffolding together; the visible content is defined in section 6.2.
  ns <- 'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"'
  group <- '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
  colour_map <- '<p:clrMap accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" bg1="lt1" bg2="lt2" folHlink="folHlink" hlink="hlink" tx1="dk1" tx2="dk2"/>'
  rel_ns <- 'http://schemas.openxmlformats.org/package/2006/relationships'
  rel_base <- 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/'
  xml_files <- list()
  xml_files[['[Content_Types].xml']] <- paste0('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>',
    '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>',
    '<Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
    '<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>',
    '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>',
    '<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/></Types>')
  xml_files[['_rels/.rels']] <- paste0('<Relationships xmlns="', rel_ns, '"><Relationship Id="rId1" Type="', rel_base, 'officeDocument" Target="ppt/presentation.xml"/></Relationships>')
  xml_files[['ppt/presentation.xml']] <- paste0('<p:presentation ', ns, '><p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId2"/></p:sldMasterIdLst><p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst><p:sldSz cx="12801600" cy="9144000"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>')
  xml_files[['ppt/_rels/presentation.xml.rels']] <- paste0('<Relationships xmlns="', rel_ns, '"><Relationship Id="rId1" Type="', rel_base, 'slide" Target="slides/slide1.xml"/><Relationship Id="rId2" Type="', rel_base, 'slideMaster" Target="slideMasters/slideMaster1.xml"/></Relationships>')
  xml_files[['ppt/slides/slide1.xml']] <- paste0('<p:sld ', ns, '><p:cSld><p:spTree>', group, paste(ppt, collapse = ''), '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>')
  xml_files[['ppt/slides/_rels/slide1.xml.rels']] <- paste0('<Relationships xmlns="', rel_ns, '"><Relationship Id="rId1" Type="', rel_base, 'slideLayout" Target="../slideLayouts/slideLayout1.xml"/></Relationships>')
  xml_files[['ppt/slideLayouts/slideLayout1.xml']] <- paste0('<p:sldLayout ', ns, ' type="blank" preserve="1"><p:cSld name="Blank"><p:spTree>', group, '</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>')
  xml_files[['ppt/slideLayouts/_rels/slideLayout1.xml.rels']] <- paste0('<Relationships xmlns="', rel_ns, '"><Relationship Id="rId1" Type="', rel_base, 'slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>')
  xml_files[['ppt/slideMasters/slideMaster1.xml']] <- paste0('<p:sldMaster ', ns, '><p:cSld><p:spTree>', group, '</p:spTree></p:cSld>', colour_map, '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles></p:sldMaster>')
  xml_files[['ppt/slideMasters/_rels/slideMaster1.xml.rels']] <- paste0('<Relationships xmlns="', rel_ns, '"><Relationship Id="rId1" Type="', rel_base, 'slideLayout" Target="../slideLayouts/slideLayout1.xml"/><Relationship Id="rId2" Type="', rel_base, 'theme" Target="../theme/theme1.xml"/></Relationships>')

  # Supply explicit theme colours/fonts so the slide is portable between Office installations.
  theme_colours <- c(dk1 = "000000", lt1 = "FFFFFF", dk2 = "17364D", lt2 = "F2F2F2", accent1 = "34556C", accent2 = "4472C4", accent3 = "70AD47", accent4 = "FFC000", accent5 = "5B9BD5", accent6 = "A5A5A5", hlink = "0563C1", folHlink = "954F72")
  theme_colours <- paste0('<a:', names(theme_colours), '><a:srgbClr val="', theme_colours, '"/></a:', names(theme_colours), '>', collapse = '')
  fill_styles <- '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
  line_styles <- '<a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:prstDash val="solid"/></a:ln>'
  xml_files[['ppt/theme/theme1.xml']] <- paste0('<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="REDUCE"><a:themeElements><a:clrScheme name="REDUCE">', theme_colours,
    '</a:clrScheme><a:fontScheme name="Arial"><a:majorFont><a:latin typeface="Arial"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont><a:minorFont><a:latin typeface="Arial"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme>',
    '<a:fmtScheme name="REDUCE"><a:fillStyleLst>', paste(rep(fill_styles, 3), collapse = ''), '</a:fillStyleLst><a:lnStyleLst>', paste(rep(line_styles, 3), collapse = ''), '</a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst>', paste(rep(fill_styles, 3), collapse = ''), '</a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>')

  # Write the package in a temporary folder, then export one editable PowerPoint.
  package_dir <- tempfile("prisma-pptx-")
  dir.create(package_dir)
  for (part in names(xml_files)) {
    # Create only the directories required by the current OOXML part.
    path <- file.path(package_dir, part)
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeLines(enc2utf8(paste0('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>', xml_files[[part]])), path, useBytes = TRUE)
  }
  zip::zipr(file.path(export_dir, "REDUCE_PRISMA_workflow.pptx"), files = names(xml_files), root = package_dir, include_directories = FALSE, mode = "mirror")
  unlink(package_dir, recursive = TRUE)
  message("Editable PowerPoint saved in: ", export_dir)
}
