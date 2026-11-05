# -----------------------------------------------------------------------------
# 07. Meeting figures and individual abstract-screening feedback
# Run after script 05 (or 06), with output_data defined by the project setup.
# This script reads the final dataset; it never modifies screening inputs.
# -----------------------------------------------------------------------------

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(openxlsx)

# 1. Settings and input -------------------------------------------------------

screening_dir <- file.path(output_data, "abstract_screening")
feedback_dir <- file.path(screening_dir, "feedback_screening")
figure_dir <- file.path(feedback_dir, "figures")
screening_file <- file.path(screening_dir, "abstract_screening_final.xlsx")
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
input_hash <- unname(tools::md5sum(screening_file))

screening <- readxl::read_excel(screening_file, sheet = "final_screening",
                               col_types = "text")
coding_fields <- c("decision", "TA_exclCriteria", "Topic", "TaxaGroup", "fishingGear")
required_columns <- c(
  "paperID", "title", "abstract", "keywords", "reviewer_1", "reviewer_2",
  "agreement_status", "disagreement_any_variable", "requires_adjudication", "n_reviewers",
  "apply_reviewer3", "adjudication_status", "final_decision",
  "TA_exclCriteria_final", "Topic_final", "TaxaGroup_final", "fishingGear_final",
  unlist(lapply(1:3, function(i) paste0(c(coding_fields, "notes"), "_reviewer_", i)))
)
missing_columns <- setdiff(required_columns, names(screening))
if (length(missing_columns) > 0) {
  stop("Missing screening columns: ", paste(missing_columns, collapse = ", "),
       ". Regenerate the final workbook with the current script 05.")
}
screening$paperID <- stringr::str_squish(screening$paperID)
if (any(is.na(screening$paperID) | screening$paperID == "") || anyDuplicated(screening$paperID)) {
  stop("final_screening must contain one non-missing row per paperID.")
}
screening$n_reviewers <- as.integer(screening$n_reviewers)
if (anyNA(screening$n_reviewers) || any(!screening$n_reviewers %in% c(1L, 2L))) {
  stop("Each paper must have one or two initial reviewers.")
}

is_blank <- function(x) is.na(x) | stringr::str_squish(x) == ""
is_true <- function(x) !is.na(x) & stringr::str_to_upper(x) == "TRUE"
# Ignore case, surrounding spaces and selection order, as in script 05.
normalise_selection <- function(x) {
  vapply(x, function(value) {
    if (is_blank(value)) return(NA_character_)
    paste(sort(unique(stringr::str_to_lower(stringr::str_squish(
      unlist(stringr::str_split(value, "\\s*[/;,]\\s*")))))), collapse = " / ")
  }, character(1), USE.NAMES = FALSE)
}
has_megafauna <- function(x) {
  !is.na(x) & stringr::str_detect(stringr::str_to_lower(x), "megafauna catch")
}

screening <- screening %>%
  dplyr::mutate(
    initial_disagreement = agreement_status == "Disagreement" |
      is_true(disagreement_any_variable),
    initial_incomplete = agreement_status == "Incomplete",
    additional_review = is_true(apply_reviewer3),
    reviewer3_active = is_true(requires_adjudication),
    review_route = dplyr::case_when(
      (initial_disagreement | initial_incomplete) & additional_review ~
        "Initial issue + additional review",
      initial_disagreement ~ "Initial disagreement",
      initial_incomplete ~ "Incomplete decision",
      additional_review ~ "Additional review",
      TRUE ~ "No active review"
    )
  )

# 2. One row per initial reviewer and paper ----------------------------------

reviewer_rows <- dplyr::bind_rows(lapply(1:2, function(i) {
  d <- screening
  d$reviewer <- d[[paste0("reviewer_", i)]]
  for (field in c(coding_fields, "notes")) {
    d[[paste0(field, "_initial")]] <- d[[paste0(field, "_reviewer_", i)]]
  }
  d %>% dplyr::filter(!is_blank(reviewer))
}))
if (nrow(reviewer_rows) == 0) stop("No named initial reviewers found.")
if (anyDuplicated(reviewer_rows[c("paperID", "reviewer")])) {
  stop("A paper/reviewer pair occurs twice in the initial slots.")
}

# Completeness concerns the INITIAL evaluation, before Reviewer 3 intervenes.
# These reporting rules do not change the adjudication requirements in 05.
reviewer_rows <- reviewer_rows %>%
  dplyr::mutate(
    expected_decision = TRUE,
    expected_TA_exclCriteria = decision_initial %in% "Rejected",
    expected_Topic = decision_initial %in% "Accepted",
    expected_TaxaGroup = decision_initial %in% "Accepted" & has_megafauna(Topic_initial),
    expected_fishingGear = decision_initial %in% "Accepted"
  )

field_details <- dplyr::bind_rows(lapply(coding_fields, function(field) {
  original <- reviewer_rows[[paste0(field, "_initial")]]
  adjudicated <- reviewer_rows[[paste0(field, "_reviewer_3")]]
  applicable <- if (field == "decision") rep(TRUE, nrow(reviewer_rows)) else
    if (field == "TA_exclCriteria") reviewer_rows$final_decision %in% "Rejected" else
      if (field == "TaxaGroup") reviewer_rows$final_decision %in% "Accepted" &
        has_megafauna(reviewer_rows$Topic_final) else
          reviewer_rows$final_decision %in% "Accepted"
  supplied <- reviewer_rows$reviewer3_active & applicable & !is_blank(adjudicated)
  different <- !is_blank(original) &
    normalise_selection(original) != normalise_selection(adjudicated)
  expected <- reviewer_rows[[paste0("expected_", field)]]
  tibble::tibble(
    paperID = reviewer_rows$paperID, reviewer = reviewer_rows$reviewer,
    review_route = reviewer_rows$review_route, field = field,
    initial_value = original, reviewer3_value = adjudicated,
    expected = expected,
    missing_initial = expected & is_blank(original),
    changed_value = supplied & dplyr::coalesce(different, FALSE),
    completed_value = supplied & is_blank(original)
  )
}))

review_metrics <- field_details %>%
  dplyr::group_by(paperID, reviewer) %>%
  dplyr::summarise(
    changed_fields = paste(field[changed_value], collapse = " | "),
    completed_fields = paste(field[completed_value], collapse = " | "),
    missing_fields_initial = paste(field[missing_initial], collapse = " | "),
    changed = any(changed_value), completed = any(completed_value),
    decision_changed = any(changed_value & field == "decision"),
    decision_completed = any(completed_value & field == "decision"),
    missing_initial = any(missing_initial), .groups = "drop"
  )
reviewer_rows <- reviewer_rows %>%
  dplyr::left_join(review_metrics, by = c("paperID", "reviewer"))

reviewer_summary <- reviewer_rows %>%
  dplyr::group_by(reviewer) %>%
  dplyr::summarise(
    n_reviewed = dplyr::n(), n_changed = sum(changed),
    n_with_active_reviewer3 = sum(reviewer3_active),
    n_completed = sum(completed), n_missing = sum(missing_initial),
    n_decisions_changed = sum(decision_changed), n_decisions_completed = sum(decision_completed),
    n_intervened = sum(changed | completed),
    percent_changed = round(100 * n_changed / n_reviewed, 1),
    percent_changed_of_active = dplyr::if_else(n_with_active_reviewer3 > 0,
      round(100 * n_changed / n_with_active_reviewer3, 1), NA_real_),
    percent_missing = round(100 * n_missing / n_reviewed, 1), .groups = "drop"
  )
missing_summary <- field_details %>%
  dplyr::group_by(reviewer, field) %>%
  dplyr::summarise(n_expected = sum(expected), n_missing = sum(missing_initial),
                   .groups = "drop") %>%
  dplyr::mutate(percent_missing = dplyr::if_else(
    n_expected > 0, round(100 * n_missing / n_expected, 1), NA_real_))

# Distinct IDs, never the sum of reviewer-level counts for a two-reviewer paper.
paper_interventions <- reviewer_rows %>%
  dplyr::group_by(paperID, review_route) %>%
  dplyr::summarise(changed = any(changed), completed = any(completed), .groups = "drop")
intervention_totals <- paper_interventions %>%
  dplyr::summarise(n_changed = sum(changed), n_completed = sum(completed),
                   n_both = sum(changed & completed), n_intervened = sum(changed | completed))
route_summary <- dplyr::bind_rows(
  paper_interventions %>% dplyr::filter(changed) %>%
    dplyr::count(review_route, name = "n_papers") %>%
    dplyr::mutate(intervention = "Changed an existing value"),
  paper_interventions %>% dplyr::filter(completed) %>%
    dplyr::count(review_route, name = "n_papers") %>%
    dplyr::mutate(intervention = "Completed a blank value")
)
if (nrow(route_summary) > 0) {
  route_summary <- route_summary %>% tidyr::complete(
    review_route = c("Initial disagreement", "Incomplete decision", "Additional review",
                     "Initial issue + additional review"),
    intervention, fill = list(n_papers = 0L))
}
decision_changes <- field_details %>%
  dplyr::filter(field == "decision", changed_value | completed_value) %>%
  dplyr::count(review_route, initial_value, reviewer3_value, name = "n_initial_evaluations")

# Figure 2a: the full two-reviewer control subset versus single-reviewer papers.
figure2_groups <- c("Two initial reviewers", "One initial reviewer")
figure2_labels <- paste0(figure2_groups, " (N = ",
  c(sum(screening$n_reviewers == 2L), sum(screening$n_reviewers == 1L)), " papers)")
figure2_types <- c("Accepted / Rejected", "Rejection criterion", "Categories (Topic, taxa, gear)")
figure2_totals <- screening %>%
  dplyr::mutate(reviewer_group = dplyr::if_else(n_reviewers == 2L,
                                               figure2_groups[1], figure2_groups[2])) %>%
  dplyr::count(reviewer_group, name = "n_total") %>%
  tidyr::complete(reviewer_group = figure2_groups, fill = list(n_total = 0L))
figure2_papers <- field_details %>%
  dplyr::filter(changed_value) %>%
  dplyr::left_join(screening %>% dplyr::select(paperID, n_reviewers), by = "paperID") %>%
  dplyr::mutate(
    reviewer_group = dplyr::if_else(n_reviewers == 2L, figure2_groups[1], figure2_groups[2]),
    change_type = dplyr::case_when(
      field == "decision" ~ figure2_types[1],
      field == "TA_exclCriteria" ~ figure2_types[2],
      TRUE ~ figure2_types[3]
    )
  ) %>% dplyr::distinct(paperID, reviewer_group, change_type)
figure2_summary <- figure2_papers %>%
  dplyr::count(reviewer_group, change_type, name = "n_papers") %>%
  tidyr::complete(reviewer_group = figure2_groups, change_type = figure2_types,
                  fill = list(n_papers = 0L)) %>%
  dplyr::left_join(figure2_totals, by = "reviewer_group") %>%
  dplyr::mutate(reviewer_group = factor(reviewer_group, levels = figure2_groups),
                panel = factor(reviewer_group, levels = figure2_groups, labels = figure2_labels),
                change_type = factor(change_type, levels = rev(figure2_types)))
outcome_summary <- screening %>%
  dplyr::mutate(outcome = dplyr::case_when(
    final_decision == "Accepted" ~ "Accepted",
    final_decision == "Rejected" ~ "Rejected",
    TRUE ~ "Pending decision"
  )) %>% dplyr::count(outcome, name = "n_papers") %>%
  tidyr::complete(outcome = c("Accepted", "Rejected", "Pending decision"),
                  fill = list(n_papers = 0L))
stopifnot(sum(outcome_summary$n_papers) == nrow(screening))

# 3. Meeting figures ---------------------------------------------------------

plot_theme <- theme_minimal(base_size = 13) +
  theme(panel.grid.minor = element_blank(), plot.title = element_text(face = "bold"),
        legend.position = "bottom", plot.margin = margin(12, 18, 12, 12))
save_figure <- function(plot, name, width = 11, height = 6) {
  print(plot)
  ggsave(file.path(figure_dir, paste0(name, ".png")), plot,
         width = width, height = height, dpi = 300, bg = "white")
  ggsave(file.path(figure_dir, paste0(name, ".pdf")), plot,
         width = width, height = height)
}
overview_data <- dplyr::bind_rows(
  tibble::tibble(outcome = "Unique papers", n_papers = nrow(screening)),
  outcome_summary %>% dplyr::filter(n_papers > 0)
) %>% dplyr::mutate(outcome = factor(outcome,
  levels = c("Unique papers", "Accepted", "Rejected", "Pending decision")))
p_outcome <- ggplot(overview_data, aes(x = outcome, y = n_papers, fill = outcome)) +
  geom_col(width = 0.65) +
  geom_text(aes(label = n_papers), vjust = -0.4, fontface = "bold", size = 5) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  scale_fill_manual(values = c("Unique papers" = "#173E50",
                               Accepted = "#16816A", Rejected = "#C65151",
                               "Pending decision" = "#A0A0A0")) +
  labs(title = "Title and abstract screening",
       subtitle = paste(format(nrow(screening), big.mark = ","), "unique papers"),
       x = NULL, y = "Unique papers", fill = NULL) + plot_theme +
  theme(legend.position = "none")
save_figure(p_outcome, "figure_1_unique_paper_outcomes")

p_routes <- ggplot(figure2_summary,
                  aes(x = change_type, y = n_papers, fill = reviewer_group)) +
  geom_col(width = 0.65) + coord_flip() + facet_wrap(~panel, ncol = 1) +
  geom_text(aes(label = n_papers), hjust = -0.2, fontface = "bold") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  scale_fill_manual(values = c("Two initial reviewers" = "#486F91",
                               "One initial reviewer" = "#C48A32")) +
  labs(title = "Changes made by Reviewer 3",
       subtitle = "Existing values changed; blank-field completions are reported separately",
       caption = "N includes every paper in the group. Bars count changed papers; change types can overlap.",
       x = NULL, y = "Unique papers") + plot_theme + theme(legend.position = "none")
save_figure(p_routes, "figure_2a_reviewer3_review_routes", height = 8)

p_reviewers <- ggplot(reviewer_summary,
  aes(x = reorder(reviewer, n_changed), y = n_changed)) +
  geom_col(fill = "#486F91", width = 0.7) + coord_flip() +
  geom_text(aes(label = paste0(n_changed, " / ", n_reviewed, " (", percent_changed, "%)")),
            hjust = -0.1, size = 3.5) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.5))) +
  labs(title = "Reviewer 3 changes by initial reviewer",
       subtitle = "Any coding field; labels: papers changed / papers reviewed (percentage)",
       x = NULL, y = "Papers with an existing value changed",
       caption = "Completions of blank values are reported separately in the summary workbook.") + plot_theme
save_figure(p_reviewers, "figure_2b_reviewer3_changes_by_reviewer",
            height = max(6, 0.35 * nrow(reviewer_summary)))

missing_plot_data <- missing_summary %>% dplyr::mutate(field = factor(field,
  levels = coding_fields, labels = c("Decision", "Exclusion criterion", "Topic",
                                     "Taxa group", "Fishing gear")))
p_missing <- ggplot(missing_plot_data, aes(x = field, y = reviewer, fill = percent_missing)) +
  geom_tile(colour = "white", linewidth = 0.5) +
  geom_text(aes(label = ifelse(n_expected == 0, "n/a",
                               paste0(n_missing, "/", n_expected))), size = 3.5) +
  scale_fill_gradient(low = "#F4F1E8", high = "#B63D37", limits = c(0, 100),
                      na.value = "#E0E0E0", name = "Missing (%)") +
  labs(title = "Completeness of the initial screening",
       subtitle = "Missing / applicable evaluations; before Reviewer 3",
       x = NULL, y = NULL,
       caption = "Decision: all; criterion: Rejected; Topic/gear: Accepted; taxa: Accepted Megafauna catch.") +
  plot_theme
save_figure(p_missing, "figure_3_missing_fields_by_reviewer",
            height = max(6, 0.35 * nrow(reviewer_summary)))

# 4. Compact reviewer workbooks, with explicit field-level comparisons ---------

feedback_columns <- c("paperID", "title", "abstract", "keywords", "authors", "year", "doi",
  "reviewer_3", "apply_reviewer3",
  "reviewer", "review_route", "adjudication_status", "changed_fields", "completed_fields",
  "missing_fields_initial", paste0(c(coding_fields, "notes"), "_initial"),
  paste0(c(coding_fields, "notes"), "_reviewer_3"),
  "final_decision", "TA_exclCriteria_final", "Topic_final", "TaxaGroup_final", "fishingGear_final")
feedback_rows <- reviewer_rows %>%
  dplyr::filter(changed | completed | missing_initial) %>%
  dplyr::select(dplyr::any_of(feedback_columns))
reviewer_files <- reviewer_summary %>%
  dplyr::mutate(filename = paste0("feedback_", stringr::str_replace_all(
    reviewer, "[^A-Za-z0-9_-]", "_"), ".xlsx"))
if (anyDuplicated(tolower(reviewer_files$filename))) {
  stop("Reviewer names produce colliding filenames; use distinct reviewer identifiers.")
}
for (i in seq_len(nrow(reviewer_files))) {
  name <- reviewer_files$reviewer[i]
  details <- field_details %>% dplyr::filter(reviewer == name,
    changed_value | completed_value | missing_initial)
  wb <- openxlsx::createWorkbook()
  tables <- list(
    Summary = reviewer_summary %>% dplyr::filter(reviewer == name),
    Papers = feedback_rows %>% dplyr::filter(reviewer == name),
    Field_details = details,
    Missing_summary = missing_summary %>% dplyr::filter(reviewer == name)
  )
  for (sheet in names(tables)) {
    openxlsx::addWorksheet(wb, sheet)
    openxlsx::writeData(wb, sheet, tables[[sheet]], withFilter = TRUE,
                         headerStyle = openxlsx::createStyle(fgFill = "#173E50",
                           fontColour = "white", textDecoration = "bold"))
    openxlsx::freezePane(wb, sheet, firstRow = TRUE)
    openxlsx::setColWidths(wb, sheet, cols = seq_len(ncol(tables[[sheet]])), widths = 20)
    for (field in intersect(c("title", "abstract", "keywords"), names(tables[[sheet]]))) {
      openxlsx::setColWidths(wb, sheet, cols = match(field, names(tables[[sheet]])), widths = 60)
    }
    if (sheet == "Field_details") {
      openxlsx::setColWidths(wb, sheet, cols = match(c("initial_value", "reviewer3_value"),
                                                    names(details)), widths = 45)
    }
  }
  # Flags and before/after values remain readable without relying on colour.
  if (nrow(details) > 0) {
    changed_rows <- which(details$changed_value | details$completed_value) + 1
    missing_rows <- which(details$missing_initial) + 1
    if (length(changed_rows)) openxlsx::addStyle(wb, "Field_details",
      openxlsx::createStyle(fontColour = "#C00000"),
      rows = changed_rows, cols = match("reviewer3_value", names(details)), gridExpand = TRUE)
    if (length(missing_rows)) openxlsx::addStyle(wb, "Field_details",
      openxlsx::createStyle(fgFill = "#FFF2CC"),
      rows = missing_rows, cols = match("initial_value", names(details)), gridExpand = TRUE)
  }
  openxlsx::saveWorkbook(wb, file.path(feedback_dir, reviewer_files$filename[i]), overwrite = TRUE)
}

stopifnot(identical(unname(tools::md5sum(screening_file)), input_hash))
openxlsx::write.xlsx(list(
  Source = data.frame(input_file = normalizePath(screening_file, winslash = "/"),
                      input_md5 = input_hash),
  Unique_outcomes = outcome_summary, Review_routes = route_summary,
  Figure2_changes = figure2_summary, Figure2_papers = figure2_papers,
  Intervention_totals = intervention_totals,
  Decision_changes = decision_changes,
  Reviewer_summary = reviewer_summary, Missing_fields = missing_summary,
  Paper_interventions = paper_interventions, Field_details = field_details,
  Reviewer_files = reviewer_files
), file.path(feedback_dir, "screening_feedback_summary.xlsx"), overwrite = TRUE)
message("Meeting figures and reviewer feedback saved in: ", feedback_dir)
