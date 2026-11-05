# Run from the repository root: Rscript tests/test_screening_feedback.R
library(openxlsx)
library(readxl)
root <- tempfile("screening-feedback-")
dir.create(file.path(root, "abstract_screening"), recursive = TRUE)
pdf(file.path(root, "test_plots.pdf"))
fields <- c("decision", "TA_exclCriteria", "Topic", "TaxaGroup", "fishingGear", "notes")
make_paper <- function(id) {
  d <- data.frame(paperID = as.character(id), title = paste("Paper", id),
    abstract = "Synthetic abstract", keywords = "test", authors = "Test", year = "2026",
    doi = paste0("test/", id), reviewer_1 = "A", reviewer_2 = NA_character_,
    n_reviewers = 1L,
    reviewer_3 = "DRG", agreement_status = "Accepted", disagreement_any_variable = FALSE,
    requires_adjudication = FALSE, apply_reviewer3 = FALSE,
    adjudication_status = "No longer required", final_decision = "Accepted")
  for (i in 1:3) for (f in fields) d[[paste0(f, "_reviewer_", i)]] <- NA_character_
  for (f in c("TA_exclCriteria", "Topic", "TaxaGroup", "fishingGear")) d[[paste0(f, "_final")]] <- NA_character_
  d$decision_reviewer_1 <- "Accepted"
  d
}
d <- do.call(rbind, lapply(1:9, make_paper))
d$Topic_reviewer_1 <- c("Megafauna catch", NA, NA, "Fishing effort", "Megafauna catch",
                        NA, "Ghost gear / Fishing effort", "Megafauna catch", NA)
d$fishingGear_reviewer_1 <- c("Trawl", NA, NA, "Trawl", "Trawl", NA,
                              "Trawl / Longline", "Trawl", NA)
d$TaxaGroup_reviewer_1 <- c("Chondrichthyans", NA, NA, NA, NA, NA, NA, "Marine mammals", NA)
d$decision_reviewer_1[c(2,9)] <- "Rejected"
d$TA_exclCriteria_reviewer_1[2] <- "LOCATION"
d$reviewer_1[c(4,5)] <- "B"
d$reviewer_1[c(6,9)] <- "C"
d$decision_reviewer_1[6] <- NA
d$agreement_status[c(1,6)] <- c("Disagreement", "Incomplete")
d$reviewer_2[1] <- "B"
d$n_reviewers[1] <- 2L
d$decision_reviewer_2[1] <- "Rejected"
d$TA_exclCriteria_reviewer_2[1] <- "LOCATION"
d$requires_adjudication[c(1,2,3,6,7,9)] <- TRUE
d$apply_reviewer3[c(2,3,7,9)] <- TRUE
d$decision_reviewer_3[c(1,2,3,8,9)] <- c("Rejected", "Accepted", "Accepted", "Rejected", "Rejected")
d$TA_exclCriteria_reviewer_3[c(1,9)] <- c("LOCATION", "GEAR")
d$Topic_reviewer_3[c(2,3,7)] <- c("Fishing effort", "Megafauna catch", "fishing effort; ghost gear")
d$TaxaGroup_reviewer_3[3] <- "Chondrichthyans"
d$fishingGear_reviewer_3[c(2,3,7)] <- c("Trawl", "Trawl", "Longline / Trawl")
d$final_decision[c(1,6,9)] <- c("Rejected", NA, "Rejected")
d$Topic_final <- d$Topic_reviewer_1
d$Topic_final[c(1,2,3,6,9)] <- c(NA, "Fishing effort", "Megafauna catch", NA, NA)
input <- file.path(root, "abstract_screening/abstract_screening_final.xlsx")
openxlsx::write.xlsx(list(final_screening = d), input)
hash <- tools::md5sum(input)
run_report <- function() {
  env <- new.env(); env$output_data <- root
  eval(parse("src/07_screeningFeedback.R"), envir = env); env
}
e <- run_report()
figure2_count <- function(group, type) {
  e$figure2_summary$n_papers[e$figure2_summary$reviewer_group == group &
                              e$figure2_summary$change_type == type]
}
stopifnot(sum(e$outcome_summary$n_papers) == 9,
  e$outcome_summary$n_papers[e$outcome_summary$outcome == "Accepted"] == 6,
  e$outcome_summary$n_papers[e$outcome_summary$outcome == "Rejected"] == 2,
  e$outcome_summary$n_papers[e$outcome_summary$outcome == "Pending decision"] == 1,
  nrow(e$reviewer_rows) == 10,
  sum(e$paper_interventions$changed) == 2,
  sum(e$paper_interventions$completed) == 4,
  e$intervention_totals$n_intervened == 4,
  nrow(e$figure2_summary) == 6,
  figure2_count("Two initial reviewers", "Accepted / Rejected") == 1,
  figure2_count("One initial reviewer", "Accepted / Rejected") == 1,
  all(e$figure2_summary$n_total[e$figure2_summary$reviewer_group == "Two initial reviewers"] == 1),
  all(e$figure2_summary$n_total[e$figure2_summary$reviewer_group == "One initial reviewer"] == 8),
  sum(e$figure2_summary$n_papers) == 2,
  sum(e$field_details$missing_initial) == 5,
  e$reviewer_summary$n_changed[e$reviewer_summary$reviewer == "A"] == 2,
  e$reviewer_summary$n_with_active_reviewer3[e$reviewer_summary$reviewer == "A"] == 4,
  !any(e$field_details$changed_value[e$field_details$paperID %in% c("7", "8")]),
  !any(e$field_details$missing_initial[e$field_details$paperID == "4"]),
  e$field_details$missing_initial[e$field_details$paperID == "5" & e$field_details$field == "TaxaGroup"],
  !e$field_details$expected[e$field_details$paperID == "3" & e$field_details$field == "TaxaGroup"],
  e$field_details$completed_value[e$field_details$paperID == "3" & e$field_details$field == "TaxaGroup"],
  !any(e$field_details$expected[e$field_details$paperID == "6" & e$field_details$field != "decision"]),
  nrow(e$feedback_rows[e$feedback_rows$paperID == "1", ]) == 1,
  all(c("5", "6", "9") %in% e$feedback_rows$paperID),
  identical(as.character(tools::md5sum(input)), as.character(hash)))
files <- list.files(e$feedback_dir, pattern = "^feedback_.*xlsx$", full.names = TRUE)
stopifnot(length(files) == 3,
  all(c("Summary", "Papers", "Field_details", "Missing_summary") %in% readxl::excel_sheets(files[1])),
  length(list.files(e$figure_dir, pattern = "png$")) == 4,
  length(list.files(e$figure_dir, pattern = "pdf$")) == 4)
again <- run_report()
stopifnot(identical(e$field_details, again$field_details),
          identical(e$reviewer_summary, again$reviewer_summary))

# Zero interventions, no missing fields, and an empty per-reviewer feedback table.
clean <- d[4, ]; clean$paperID <- "clean"
openxlsx::write.xlsx(list(final_screening = clean), input, overwrite = TRUE)
empty <- run_report()
stopifnot(nrow(empty$route_summary) == 0, nrow(empty$feedback_rows) == 0,
          nrow(empty$figure2_summary) == 6, sum(empty$figure2_summary$n_papers) == 0,
          file.exists(file.path(empty$feedback_dir, "feedback_B.xlsx")))

# Group by the initial reviewer count, even if those reviewers agreed.
# Multiple category edits and two initial reviewers must not duplicate a bar.
special <- d[1, ]
special$paperID <- "multi"
special$apply_reviewer3 <- TRUE
special$agreement_status <- "Accepted"
special$final_decision <- "Accepted"
special$decision_reviewer_2 <- "Accepted"
special$decision_reviewer_3 <- "Accepted"
special$Topic_reviewer_2 <- special$Topic_reviewer_1
special$Topic_reviewer_3 <- "Ghost gear"
special$fishingGear_reviewer_2 <- special$fishingGear_reviewer_1
special$fishingGear_reviewer_3 <- "Longline"
special$Topic_final <- "Ghost gear"
criterion_case <- special
criterion_case$paperID <- "criterion"
criterion_case$final_decision <- "Rejected"
criterion_case$decision_reviewer_1 <- "Rejected"
criterion_case$decision_reviewer_2 <- "Rejected"
criterion_case$decision_reviewer_3 <- "Rejected"
criterion_case$TA_exclCriteria_reviewer_1 <- "NOTOPIC"
criterion_case$TA_exclCriteria_reviewer_2 <- "LOCATION"
criterion_case$TA_exclCriteria_reviewer_3 <- "GEAR"
openxlsx::write.xlsx(list(final_screening = rbind(special, criterion_case)), input, overwrite = TRUE)
multi <- run_report()
stopifnot(nrow(multi$figure2_papers) == 2,
  all(multi$figure2_papers$reviewer_group == "Two initial reviewers"),
  multi$figure2_papers$change_type[multi$figure2_papers$paperID == "multi"] ==
    "Categories (Topic, taxa, gear)",
  multi$figure2_papers$change_type[multi$figure2_papers$paperID == "criterion"] ==
    "Rejection criterion",
  sum(multi$figure2_summary$n_papers) == 2)
dev.off()
cat("Screening feedback regression tests passed.\n")
