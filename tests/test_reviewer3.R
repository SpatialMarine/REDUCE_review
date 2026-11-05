# Run from the repository root: Rscript tests/test_reviewer3.R
# Synthetic workbooks only; no project screening files are modified.
library(writexl)
library(readxl)

script <- readLines("src/05_summariseAbstractScreening.R")
# Exercise all data processing and Excel exports, without rendering figures.
figure_start <- grep("^# 6. Figures", script)
figure_end <- grep("^# 7. Prepare", script)
script <- script[-seq(figure_start, figure_end - 1)]
run_screening <- function(input, output) {
  env <- new.env()
  env$input_data <- input
  env$output_data <- output
  suppressWarnings(eval(parse(text = script), envir = env))
  env
}

root <- tempfile("reviewer3-tests-")
input <- file.path(root, "input")
output <- file.path(root, "output")
done <- file.path(input, "abstracts_byReviewer", "Done")
dir.create(done, recursive = TRUE)

review <- function(id, reviewer, decision, topic = NA_character_,
                   taxa = NA_character_, gear = NA_character_, criterion = NA_character_) {
  data.frame(
    paperID = id, rev1_name = reviewer, TA_decisionRev1 = decision,
    TA_exclCriteria_rev1 = criterion, Topic = topic, TaxaGroup = taxa,
    fishingGear = gear, notes = NA_character_, title = paste("Paper", id),
    abstract = "Synthetic abstract", keywords = "test", authors = "Test",
    year = "2026", journal = "Test", volume = "1", issue = "1",
    start_page = "1", end_page = "2", doi = "test", Language = "English",
    document_type = "Article", source = "test"
  )
}
rows <- do.call(rbind, list(
  review("1", "A", "Accepted"), review("1", "B", "Accepted"),
  review("2", "A", "Accepted", "x"), review("2", "B", "Accepted", "y"),
  review("3", "A", "Accepted"), review("3", "B", "Rejected"),
  review("4", "A", "Rejected", criterion = "x"),
  review("4", "B", "Rejected", criterion = "y"),
  review("5", "A", NA_character_, "old"),
  review("6", "A", "Accepted"), review("6", "B", NA_character_),
  review("7", "A", "Rejected"), review("7", "B", "Rejected"),
  review("8", "A", "Accepted", "x", "fish", "net"),
  review("8", "B", "Accepted", "y", "bird", "line"),
  review("9", "A", "Accepted", "x"), review("9", "B", "Rejected", "y"),
  review("10", "A", "Rejected", criterion = "x"),
  review("10", "B", NA_character_, criterion = "y"),
  review("11", "A", "Accepted", "single topic"),
  review("12", "A", "Rejected", criterion = "single criterion")
))
write_xlsx(list(screening = rows), file.path(done, "reviews.xlsx"))
first <- run_screening(input, output)
stopifnot(nrow(first$historical_adjudications) == 0,
          all(c("5", "6", "10") %in% first$required_adjudication_ids),
          !any(c("11", "12") %in% first$required_adjudication_ids),
          first$final_screening$adjudication_status[1] == "No longer required")

manual <- first$final_screening[, first$adjudication_columns]
manual$decision_reviewer_3[match(c("3", "5", "6", "9", "10"), manual$paperID)] <-
  c("Accepted", "Accepted", "Rejected", "Rejected", "Rejected")
manual$Topic_reviewer_3[match(c("2", "5", "8"), manual$paperID)] <-
  c("resolved", "new", "resolved")
manual$TA_exclCriteria_reviewer_3[manual$paperID == "10"] <- "new criterion"
# Inactive and absent papers must retain their previous answers in the workbook.
manual$decision_reviewer_3[manual$paperID == "7"] <- "Accepted"
historical <- manual[manual$paperID == "7", ]
historical$paperID <- "99"
manual <- rbind(manual, historical)
write_xlsx(list(final_screening = manual), first$reviewer3_file)
original_hash <- tools::md5sum(first$reviewer3_file)
second <- run_screening(input, output)
get <- function(id, field) second$final_screening[[field]][match(id, second$final_screening$paperID)]
stopifnot(
  get("2", "adjudication_status") == "Resolved",
  is.na(get("2", "decision_reviewer_3")),
  get("3", "adjudication_status") == "Resolved",
  get("4", "pending_fields") == "TA_exclCriteria",
  get("5", "final_decision") == "Accepted", get("5", "Topic_final") == "new",
  get("6", "final_decision") == "Rejected",
  get("7", "final_decision") == "Rejected", is.na(get("7", "decision_reviewer_3")),
  get("8", "pending_fields") == "TaxaGroup | fishingGear",
  get("9", "adjudication_status") == "Resolved", is.na(get("9", "Topic_final")),
  get("10", "TA_exclCriteria_final") == "new criterion",
  get("11", "agreement_status") == "Accepted",
  get("11", "final_decision") == "Accepted",
  get("11", "Topic_final") == "single topic",
  !get("11", "requires_adjudication"), get("11", "pending_fields") == "",
  get("12", "agreement_status") == "Rejected",
  get("12", "final_decision") == "Rejected",
  get("12", "TA_exclCriteria_final") == "single criterion",
  !get("12", "requires_adjudication"), get("12", "pending_fields") == "",
  identical(as.character(tools::md5sum(first$reviewer3_file)), as.character(original_hash)),
  second$current_adjudications$decision_reviewer_3[second$current_adjudications$paperID == "7"] == "Accepted",
  second$historical_adjudications$paperID == "99"
)
for (file in c(second$reviewer3_updated_file,
               file.path(second$output_dir, "abstract_screening_summary.xlsx"),
               file.path(second$output_dir, "abstract_screening_final.xlsx"))) {
  stopifnot("adjudication_pending" %in% excel_sheets(file),
            nrow(read_excel(file, sheet = "adjudication_pending")) == 2)
}
third <- run_screening(input, output)
stopifnot(identical(second$final_screening, third$final_screening),
          identical(second$reviewer3_updated, third$reviewer3_updated))

# Adopt the updated workbook as manual input and verify retained history.
file.copy(second$reviewer3_updated_file, second$reviewer3_file, overwrite = TRUE)
fourth <- run_screening(input, output)
stopifnot(identical(second$reviewer3_updated, fourth$reviewer3_updated))

# All papers have just one initial reviewer: pivot still supplies slot 2.
write_xlsx(list(screening = rows[rows$paperID %in% c("5", "11", "12"), ]),
           file.path(done, "reviews.xlsx"))
single <- run_screening(input, file.path(root, "single-output"))
stopifnot(identical(single$final_screening$agreement_status,
                    c("Incomplete", "Accepted", "Rejected")),
          identical(single$required_adjudication_ids, "5"),
          identical(single$adjudication_pending$paperID, "5"),
          single$final_screening$pending_fields[1] == "decision_reviewer_3")

# Explicit additional reviews do not depend on initial reviewer disagreement.
extra_rows <- do.call(rbind, list(
  review("13", "A", "Rejected", "old topic", "retained taxa", "Trawl", "LOCATION"),
  review("14", "A", "Accepted", "old topic", "old taxa", "Trawl"),
  review("15", "A", "Accepted"),
  review("16", "A", "Rejected", criterion = "LOCATION"),
  review("17", "A", "Rejected"), review("17", "B", "Rejected")
))
write_xlsx(list(screening = extra_rows), file.path(done, "reviews.xlsx"))
extra_output <- file.path(root, "additional-output")
template <- run_screening(input, extra_output)
manual <- template$final_screening[, c(template$adjudication_columns, "apply_reviewer3")]
manual$apply_reviewer3 <- c("true", "TRUE", "TRUE", "", "FALSE")
manual$decision_reviewer_3 <- c("Accepted", "Rejected", NA, "Accepted", "Accepted")
manual$Topic_reviewer_3[1] <- "new topic"
manual$TA_exclCriteria_reviewer_3[2] <- "GEAR"
manual$notes_reviewer_3[1] <- "additional review note"
write_xlsx(list(final_screening = manual), template$reviewer3_file)
hash <- tools::md5sum(template$reviewer3_file)
extra <- run_screening(input, extra_output)
get_extra <- function(id, field) extra$final_screening[[field]][match(id, extra$final_screening$paperID)]
stopifnot(
  setequal(extra$required_adjudication_ids, c("13", "14", "15")),
  get_extra("13", "final_decision") == "Accepted",
  get_extra("13", "Topic_final") == "new topic",
  get_extra("13", "TaxaGroup_final") == "retained taxa",
  get_extra("13", "fishingGear_final") == "Trawl",
  is.na(get_extra("13", "TA_exclCriteria_final")),
  get_extra("13", "notes_reviewer_3") == "additional review note",
  get_extra("13", "decision_reviewer_1") == "Rejected",
  get_extra("13", "TA_exclCriteria_reviewer_1") == "LOCATION",
  get_extra("13", "adjudication_status") == "Resolved",
  get_extra("13", "adjudication_reason") == "Additional manual review",
  get_extra("14", "final_decision") == "Rejected",
  get_extra("14", "TA_exclCriteria_final") == "GEAR",
  is.na(get_extra("14", "Topic_final")),
  get_extra("15", "adjudication_status") == "Pending decision",
  get_extra("15", "pending_fields") == "decision_reviewer_3",
  get_extra("16", "final_decision") == "Rejected",
  !get_extra("16", "apply_reviewer3"),
  get_extra("17", "final_decision") == "Rejected",
  identical(as.character(tools::md5sum(template$reviewer3_file)), as.character(hash))
)
for (file in c(extra$reviewer3_updated_file,
               file.path(extra$output_dir, "abstract_screening_summary.xlsx"),
               file.path(extra$output_dir, "abstract_screening_final.xlsx"))) {
  pending <- read_excel(file, sheet = "adjudication_pending")
  stopifnot(identical(pending$paperID, "15"),
            "apply_reviewer3" %in% names(read_excel(file, sheet = "final_screening")))
}
again <- run_screening(input, extra_output)
stopifnot(identical(extra$final_screening, again$final_screening),
          identical(extra$reviewer3_updated, again$reviewer3_updated))
file.copy(extra$reviewer3_updated_file, extra$reviewer3_file, overwrite = TRUE)
adopted <- run_screening(input, extra_output)
stopifnot(identical(extra$final_screening, adopted$final_screening),
          identical(extra$reviewer3_updated, adopted$reviewer3_updated))

# A paired unanimous result can also be overridden, but only explicitly.
manual$apply_reviewer3[manual$paperID == "17"] <- "TRUE"
write_xlsx(list(final_screening = manual), template$reviewer3_file)
paired <- run_screening(input, extra_output)
stopifnot(paired$final_screening$final_decision[paired$final_screening$paperID == "17"] == "Accepted")

# Invalid controls fail clearly; a flag is not silently interpreted as FALSE.
manual$apply_reviewer3[1] <- "yes"
write_xlsx(list(final_screening = manual), template$reviewer3_file)
error <- tryCatch(run_screening(input, extra_output), error = identity)
stopifnot(inherits(error, "error"), grepl("apply_reviewer3 must contain", conditionMessage(error)))

# Reject output/input collisions before touching the manual workbook.
collision_script <- append(script,
  'reviewer3_file <- file.path(output_dir, "abstract_screening_reviewer3_updated.xlsx")',
  after = grep("^# A manual input must never", script) - 1)
env <- new.env()
env$input_data <- input
env$output_data <- extra_output
hash <- tools::md5sum(extra$reviewer3_updated_file)
error <- tryCatch(eval(parse(text = collision_script), envir = env), error = identity)
stopifnot(inherits(error, "error"), grepl("must be separate", conditionMessage(error)),
          identical(as.character(tools::md5sum(extra$reviewer3_updated_file)), as.character(hash)))
cat("Reviewer 3 regression tests passed, including explicit additional reviews.\n")
