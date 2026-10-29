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
cat("Reviewer 3 regression tests passed.\n")
