# -----------------------------------------------------------------------------

# Title:

# -----------------------------------------------------------------------------
# 07. Abstract-screening feedback
# -----------------------------------------------------------------------------

# Load the packages used to read Excel, reshape tables, draw figures and write workbooks.
library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(openxlsx)

# 1. Settings and input --------------------------------------------------------

# 1.1. Set repository routes (output folder)------------------------------------
# Keep the source workbook and feedback exports in separate locations.
screening_dir <- file.path(output_data, "abstract_screening")
feedback_dir <- file.path(screening_dir, "feedback_screening")
figure_dir <- file.path(feedback_dir, "figures")
screening_file <- file.path(screening_dir, "abstract_screening_final.xlsx")
# Create the feedback folders if they do not already exist.
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

# Record a fingerprint so we can check that the input workbook stayed intact.
input_hash <- unname(tools::md5sum(screening_file))

# 1.2. Load screening dataset---------------------------------------------------
# Read IDs and coded values as text so Excel types do not affect comparisons.
screening <- readxl::read_excel(screening_file, sheet = "final_screening",
                               col_types = "text")

# Compare these five coding fields. Keep reviewer notes as context in the exports.
coding_fields <- c("decision", "TA_exclCriteria", "Topic", "TaxaGroup", "fishingGear")

# List the columns needed from script 05, including the coding and notes columns for each reviewer slot.
required_columns <- c(
  "paperID", "title", "abstract", "keywords", "reviewer_1", "reviewer_2",
  "agreement_status", "disagreement_any_variable", "requires_adjudication", "n_reviewers",
  "apply_reviewer3", "adjudication_status", "final_decision",
  "TA_exclCriteria_final", "Topic_final", "TaxaGroup_final", "fishingGear_final",
  unlist(lapply(1:3, function(i) paste0(c(coding_fields, "notes"), "_reviewer_", i))))

# Stop early if the workbook is missing any column the report needs.
missing_columns <- setdiff(required_columns, names(screening))
if (length(missing_columns) > 0) {
  stop("Missing screening columns: ", paste(missing_columns, collapse = ", "),
       ". Regenerate the final workbook with the current script 05.")}

# Clean up spaces and check that each paper has a unique, non-empty ID.
screening$paperID <- stringr::str_squish(screening$paperID)
if (any(is.na(screening$paperID) | screening$paperID == "") || anyDuplicated(screening$paperID)) {
  stop("final_screening must contain one non-missing row per paperID.")}

# Use the initial reviewer count to separate the single-review and double-review groups.
screening$n_reviewers <- as.integer(screening$n_reviewers)
if (anyNA(screening$n_reviewers) || any(!screening$n_reviewers %in% c(1L, 2L))) {
  stop("Each paper must have one or two initial reviewers.")}

# 2. Prepare summaries ---------------------------------------------------------

# 2.1. Rules for summaries------------------------------------------------------
# Label how each paper reached Reviewer 3. These labels are used in the Excel summaries.
screening <- screening %>%
  dplyr::mutate(
    # An initial disagreement can be about the decision or any coding variable.
    initial_disagreement = agreement_status == "Disagreement" |
      (!is.na(disagreement_any_variable) & stringr::str_to_upper(disagreement_any_variable) == "TRUE"),
    initial_incomplete = agreement_status == "Incomplete",
    # Keep the manual review flag separate from the flag that applies Reviewer 3's values.
    additional_review = (!is.na(apply_reviewer3) & stringr::str_to_upper(apply_reviewer3) == "TRUE"),
    reviewer3_active = (!is.na(requires_adjudication) & stringr::str_to_upper(requires_adjudication) == "TRUE"),
    # Give combined cases their own label before checking the individual reasons.
    review_route = dplyr::case_when(
      (initial_disagreement | initial_incomplete) & additional_review ~
        "Initial issue + additional review",
      initial_disagreement ~ "Initial disagreement",
      initial_incomplete ~ "Incomplete decision",
      additional_review ~ "Additional review",
      TRUE ~ "No active review"))


# 2.2. Organise summaries-------------------------------------------------------
# Stack the two reviewer slots so both follow the same checks.
initial_reviews <- vector("list", 2)
for (i in 1:2) {
  # Copy the paper data and take the name and coding from the current reviewer slot.
  reviews <- screening
  reviews$reviewer <- reviews[[paste0("reviewer_", i)]]
  for (field in c(coding_fields, "notes")) {
    reviews[[paste0(field, "_initial")]] <- reviews[[paste0(field, "_reviewer_", i)]]}
  # Drop empty slots so a paper with one reviewer contributes only one initial evaluation.
  initial_reviews[[i]] <- reviews %>% dplyr::filter(!is.na(reviewer), stringr::str_squish(reviewer) != "")}

# Stack both slots and check that each paper and reviewer pair appears once.
reviewer_rows <- dplyr::bind_rows(initial_reviews)
if (nrow(reviewer_rows) == 0) stop("No named initial reviewers found.")
if (anyDuplicated(reviewer_rows[c("paperID", "reviewer")])) {
  stop("A paper/reviewer pair occurs twice in the initial slots.")}

# Completeness concerns the INITIAL evaluation, before Reviewer 3 intervenes.
# These reporting rules do not change the adjudication requirements in 05.
reviewer_rows <- reviewer_rows %>%
  dplyr::mutate(
    # Require a decision for every evaluation. The other fields depend on that reviewer's decision and topic.
    expected_decision = TRUE,
    expected_TA_exclCriteria = decision_initial %in% "Rejected",
    expected_Topic = decision_initial %in% "Accepted",
    expected_TaxaGroup = decision_initial %in% "Accepted" &
      !is.na(Topic_initial) &
      stringr::str_detect(stringr::str_to_lower(Topic_initial), "megafauna catch"),
    expected_fishingGear = decision_initial %in% "Accepted")


#2.3. Make comparisons----------------------------------------------------------
# Keep one row per paper, initial reviewer and field for the comparisons.
field_comparisons <- list()
for (field in coding_fields) {
  # Read the initial and Reviewer 3 values for the same field.
  original <- reviewer_rows[[paste0(field, "_initial")]]
  adjudicated <- reviewer_rows[[paste0(field, "_reviewer_3")]]
  # Check whether the field applies to the final decision and topic.
  applicable <- if (field == "decision") rep(TRUE, nrow(reviewer_rows)) else
    if (field == "TA_exclCriteria") reviewer_rows$final_decision %in% "Rejected" else
      if (field == "TaxaGroup") reviewer_rows$final_decision %in% "Accepted" &

      !is.na(reviewer_rows$Topic_final) &
      stringr::str_detect(stringr::str_to_lower(reviewer_rows$Topic_final), "megafauna catch") else
          reviewer_rows$final_decision %in% "Accepted"
  # Identify blanks before comparing the two reviews.
  original_blank <- is.na(original) | stringr::str_squish(original) == ""
  adjudicated_blank <- is.na(adjudicated) | stringr::str_squish(adjudicated) == ""
  supplied <- reviewer_rows$reviewer3_active & applicable & !adjudicated_blank

  # Compare non-blank selections without case, spacing or order differences.
  different <- rep(FALSE, length(original))
  for (row in which(supplied & !original_blank)) {
    original_items <- stringr::str_split_1(original[row], "\\s*[/;,]\\s*")
    reviewer3_items <- stringr::str_split_1(adjudicated[row], "\\s*[/;,]\\s*")
    original_items <- sort(unique(stringr::str_to_lower(stringr::str_squish(original_items))))
    reviewer3_items <- sort(unique(stringr::str_to_lower(stringr::str_squish(reviewer3_items))))
    different[row] <- paste(original_items, collapse = " / ") !=
      paste(reviewer3_items, collapse = " / ")
  }

  # Keep the initial requirement separate from the final value so gaps can be followed over time.
  expected <- reviewer_rows[[paste0("expected_", field)]]
  final_value <- reviewer_rows[[if (field == "decision") "final_decision" else paste0(field, "_final")]]
  # Record the original, Reviewer 3 and final values alongside the three reporting flags.
  field_comparisons[[field]] <- tibble::tibble(
    paperID = reviewer_rows$paperID, reviewer = reviewer_rows$reviewer,
    review_route = reviewer_rows$review_route, field = field,
    initial_value = original, reviewer3_value = adjudicated,
    final_value = final_value,
    final_applicable = applicable,
    expected = expected,
    # Flag an initial gap only when that reviewer was expected to fill the field.
    missing_initial = expected & original_blank,
    # Separate replacements of existing values from completions of empty cells.
    changed_value = different,
    completed_value = supplied & original_blank)
}

# Stack the comparisons across all five coding fields.
field_details <- dplyr::bind_rows(field_comparisons)


#2.4. Make summary--------------------------------------------------------------
# Summarise the field comparisons for each initial evaluation.
review_metrics <- field_details %>%
  dplyr::group_by(paperID, reviewer) %>%
  dplyr::summarise(
    # List the affected fields so the reviewer can see what changed or was missing.
    changed_fields = paste(field[changed_value], collapse = " | "),
    completed_fields = paste(field[completed_value], collapse = " | "),
    missing_fields_initial = paste(field[missing_initial], collapse = " | "),
    # Flag whether each initial evaluation had at least one change or completion.
    changed = any(changed_value), completed = any(completed_value),
    decision_changed = any(changed_value & field == "decision"),
    decision_completed = any(completed_value & field == "decision"),
    missing_initial = any(missing_initial), .groups = "drop"
  )
# Attach paper-level feedback flags to each initial evaluation.
reviewer_rows <- reviewer_rows %>%
  dplyr::left_join(review_metrics, by = c("paperID", "reviewer"))


# 3. Plot results---------------------------------------------------------------

# 3.1. Plot settings ---------------------------------------------------------
# Use the same fonts, spacing and legend placement across the meeting figures.
plot_theme <- theme_minimal(base_size = 13) +
  theme(panel.grid.minor = element_blank(), plot.title = element_text(face = "bold"),
        legend.position = "bottom", plot.margin = margin(12, 18, 12, 12))

# 3.2. Figure 1. Screening overall results--------------------------------------
# Count every paper once, including papers still awaiting a decision.
outcome_summary <- screening %>%
  dplyr::mutate(outcome = dplyr::case_when(
    final_decision == "Accepted" ~ "Accepted",
    final_decision == "Rejected" ~ "Rejected",
    TRUE ~ "Pending decision"
  )) %>% dplyr::count(outcome, name = "n_papers") %>%
  tidyr::complete(outcome = c("Accepted", "Rejected", "Pending decision"),
                  fill = list(n_papers = 0L))
stopifnot(sum(outcome_summary$n_papers) == nrow(screening))

# Keep only accepted and rejected papers in the pie chart.
overview_data <- outcome_summary %>%
  dplyr::filter(outcome %in% c("Accepted", "Rejected"), n_papers > 0) %>%
  dplyr::mutate(outcome = factor(outcome, levels = c("Accepted", "Rejected")))

# Show the count inside each slice and the total unique papers in the subtitle.
p_outcome <- ggplot(overview_data, aes(x = "", y = n_papers, fill = outcome)) +
  geom_col(width = 1, colour = "white") +
  geom_text(aes(label = format(n_papers, big.mark = ",")),
            position = position_stack(vjust = 0.5), colour = "white",
            fontface = "bold", size = 5) +
  coord_polar(theta = "y") +
  scale_fill_manual(values = c(Accepted = "#16816A", Rejected = "#C65151")) +
  labs(title = "Title and abstract screening",
       subtitle = paste(format(nrow(screening), big.mark = ","), "unique papers"),
       fill = NULL) +
  theme_void(base_size = 13) +
  theme(plot.title = element_text(face = "bold"),
        legend.position = "bottom",
        plot.margin = margin(12, 18, 12, 12))

# Display the figure and save PNG and PDF copies.
print(p_outcome)
ggsave(file.path(figure_dir, "figure_1_unique_paper_outcomes.png"), p_outcome,
       width = 11, height = 6, dpi = 300, bg = "white")
ggsave(file.path(figure_dir, "figure_1_unique_paper_outcomes.pdf"), p_outcome,
       width = 11, height = 6)


# 3.3. Figure 2a. Changes by number of initial reviewers ---------------------
# Use all papers in each reviewer group as the panel denominator.
figure2_groups <- c("Two initial reviewers", "One initial reviewer")
figure2_labels <- paste0(figure2_groups, " (N = ",
  c(sum(screening$n_reviewers == 2L), sum(screening$n_reviewers == 1L)), " papers)")
figure2_types <- c("Accepted / Rejected", "Rejection criterion", "Categories (Topic, taxa, gear)")

# Count the papers in each group and keep both groups even if one is empty.
figure2_totals <- screening %>%
  dplyr::mutate(reviewer_group = dplyr::if_else(n_reviewers == 2L,
                                               figure2_groups[1], figure2_groups[2])) %>%
  dplyr::count(reviewer_group, name = "n_total") %>%
  tidyr::complete(reviewer_group = figure2_groups, fill = list(n_total = 0L))

# Include changes and added values in both reviewer groups.
figure2_papers <- field_details %>%
  # Keep changed values and values added to fields required in the initial review.
  dplyr::filter(changed_value | (missing_initial & completed_value)) %>%
  dplyr::left_join(screening %>% dplyr::select(paperID, n_reviewers), by = "paperID") %>%
  dplyr::mutate(
    reviewer_group = dplyr::if_else(n_reviewers == 2L, figure2_groups[1], figure2_groups[2]),
    # Combine Topic, TaxaGroup and fishingGear into one category bar.
    change_type = dplyr::case_when(
      field == "decision" ~ figure2_types[1],
      field == "TA_exclCriteria" ~ figure2_types[2],
      TRUE ~ figure2_types[3]
    )
  ) %>%
  # Collapse multiple affected fields and reviewer rows into one count per paper and bar.
  dplyr::group_by(paperID, reviewer_group, change_type) %>%
  # When both actions occur in the same category, count the paper as changed.
  dplyr::summarise(changed = any(changed_value), .groups = "drop")

# Count changed papers and papers with only a filled gap, then add the panel totals.
figure2_summary <- figure2_papers %>%
  dplyr::group_by(reviewer_group, change_type) %>%
  dplyr::summarise(n_papers = sum(changed), n_filled = sum(!changed), .groups = "drop") %>%
  tidyr::complete(reviewer_group = figure2_groups, change_type = figure2_types,
                  fill = list(n_papers = 0L, n_filled = 0L)) %>%
  dplyr::left_join(figure2_totals, by = "reviewer_group") %>%
  dplyr::mutate(reviewer_group = factor(reviewer_group, levels = figure2_groups),
                panel = factor(reviewer_group, levels = figure2_groups, labels = figure2_labels),
                change_type = factor(change_type, levels = rev(figure2_types)))


# Make one row per bar segment so ggplot can colour changes and completions separately.
figure2_bars <- figure2_summary %>%
  tidyr::pivot_longer(c(n_papers, n_filled), names_to = "segment", values_to = "count") %>%
  dplyr::mutate(segment = factor(segment, levels = c("n_papers", "n_filled")))

# Draw the two groups in separate panels and label each bar with its combined count.
p_routes <- ggplot(figure2_bars, aes(x = change_type, y = count, fill = segment)) +
  geom_col(width = 0.65, position = position_stack(reverse = TRUE)) +
  coord_flip() + facet_wrap(~panel, ncol = 1) +
  geom_text(data = figure2_summary,
            aes(x = change_type, y = n_papers + n_filled, label = n_papers + n_filled),
            inherit.aes = FALSE, hjust = -0.2, fontface = "bold") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  scale_fill_manual(
    values = c(n_papers = "#486F91", n_filled = "#7D9BB5"),
    labels = c(n_papers = "Changed an existing value",
               n_filled = "Added a value")) +
  labs(
    title = "Reviewer 3 contributions",
    subtitle = "Changes and additions are shown for both initial reviewer groups",
    caption = "Each paper counts once per bar. Papers with both actions count as changed.",
    fill = NULL, x = NULL, y = "Unique papers") + plot_theme

# Display the figure and save PNG and PDF copies.
print(p_routes)

ggsave(file.path(figure_dir, "figure_2a_reviewer3_review_routes.png"), p_routes,
       width = 11, height = 8, dpi = 300, bg = "white")

ggsave(file.path(figure_dir, "figure_2a_reviewer3_review_routes.pdf"), p_routes,
       width = 11, height = 8)


# 3.4. Figure 2b. Changes by initial reviewer ----------------------------------

# Count changes and additions per initial reviewer for the plot and summary workbook.
reviewer_summary <- reviewer_rows %>%
  dplyr::group_by(reviewer) %>%
  dplyr::summarise(
    n_reviewed = dplyr::n(), n_changed = sum(changed),
    n_with_active_reviewer3 = sum(reviewer3_active),
    n_completed = sum(completed), n_missing = sum(missing_initial),
    n_decisions_changed = sum(decision_changed), n_decisions_completed = sum(decision_completed),
    n_intervened = sum(changed | completed),
    percent_changed = round(100 * n_changed / n_reviewed, 1),
    # Also report the change rate among papers where Reviewer 3 was active.
    percent_changed_of_active = dplyr::if_else(n_with_active_reviewer3 > 0,
      round(100 * n_changed / n_with_active_reviewer3, 1), NA_real_),
    percent_missing = round(100 * n_missing / n_reviewed, 1), .groups = "drop"
  )


# Split each reviewer's interventions into changes and additions only.
reviewer_bars <- reviewer_summary %>%
  dplyr::mutate(n_added_only = n_intervened - n_changed) %>%
  tidyr::pivot_longer(
    c(n_changed, n_added_only),
    names_to = "action",
    values_to = "n_papers") %>%
  dplyr::mutate(action = factor(action, levels = c("n_changed", "n_added_only")))

# Stack the two actions and label each bar with the share of papers affected.
p_reviewers <- ggplot(
  reviewer_bars,
  aes(x = reorder(reviewer, n_intervened), y = n_papers, fill = action)) +
  geom_col(width = 0.7, position = position_stack(reverse = TRUE)) +
  coord_flip() +
  geom_text(
    data = reviewer_summary,
    aes(
      x = reorder(reviewer, n_intervened),
      y = n_intervened,
      label = paste0(n_intervened, " / ", n_reviewed, " (", round(100 * n_intervened / n_reviewed, 1), "%)")),
    inherit.aes = FALSE, hjust = -0.1, size = 3.5) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.5))) +
  scale_fill_manual(
    values = c(n_changed = "#486F91", n_added_only = "#7D9BB5"),
    labels = c(n_changed = "Changed an existing value",
               n_added_only = "Added a missing value")) +
  labs(
    title = "Reviewer 3 contributions by initial reviewer",
    subtitle = "Labels show papers affected out of all papers reviewed by each person",
    x = NULL, y = "Papers with a Reviewer 3 contribution", fill = NULL,
    caption = "Each paper counts once per reviewer. Papers with both actions count as changed."
  ) + plot_theme

# Display the figure before exporting it.
print(p_reviewers)

ggsave(file.path(figure_dir, "figure_2b_reviewer3_changes_by_reviewer.png"), p_reviewers,
       width = 11, height = max(6, 0.35 * nrow(reviewer_summary)), dpi = 300, bg = "white")

ggsave(file.path(figure_dir, "figure_2b_reviewer3_changes_by_reviewer.pdf"), p_reviewers,
       width = 11, height = max(6, 0.35 * nrow(reviewer_summary)))

# 3.5. Figure 3. Missing fields by initial reviewer ----------------------------

# Only evaluations where a field was required enter its denominator.
missing_summary <- field_details %>%
  dplyr::group_by(reviewer, field) %>%
  dplyr::summarise(n_expected = sum(expected), n_missing = sum(missing_initial),
                   .groups = "drop") %>%
  dplyr::mutate(percent_missing = dplyr::if_else(
    n_expected > 0, round(100 * n_missing / n_expected, 1), NA_real_))

# Set the field order and use readable labels for the heatmap.
missing_plot_data <- missing_summary %>% dplyr::mutate(field = factor(field,
  levels = coding_fields, labels = c("Decision", "Exclusion criterion", "Topic",
                                     "Taxa group", "Fishing gear")))

# Colour by the percentage missing and show the numerator and denominator in each tile.
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

# Display the figure and save PNG and PDF copies.
print(p_missing)

ggsave(file.path(figure_dir, "figure_3_missing_fields_by_reviewer.png"), p_missing,
       width = 11, height = max(6, 0.35 * nrow(reviewer_summary)), dpi = 300, bg = "white")

ggsave(file.path(figure_dir, "figure_3_missing_fields_by_reviewer.pdf"), p_missing,
       width = 11, height = max(6, 0.35 * nrow(reviewer_summary)))

# 3.6. Figure 3b. What happened to the initial gaps? ---------------------------

# Solved means filled or no longer applicable in the final result.
# Blank means the field still applies and has no final value.
gap_totals <- field_details %>%
  dplyr::group_by(field) %>%
  dplyr::summarise(
    # Follow each original gap through three outcomes in the final result.
    initial = sum(missing_initial),
    filled = sum(missing_initial & final_applicable & !(is.na(final_value) | stringr::str_squish(final_value) == "")),
    no_longer_applicable = sum(missing_initial & !final_applicable),
    pending = sum(missing_initial & final_applicable & (is.na(final_value) | stringr::str_squish(final_value) == "")),
    .groups = "drop"
  ) %>%
  dplyr::mutate(solved = filled + no_longer_applicable, blank = pending)

# Put Solved and Blank in separate rows to draw them as stacked segments.
gap_bars <- gap_totals %>%
  tidyr::pivot_longer(c(solved, blank), names_to = "status", values_to = "count") %>%
  dplyr::mutate(status = factor(status, levels = c("solved", "blank"))) %>%
  dplyr::mutate(field = factor(field, levels = rev(coding_fields)))

# Draw the two outcomes in orange and white, with labels for nonzero segments.
p_gap_totals <- ggplot(gap_bars, aes(field, count, fill = status)) +
  geom_col(position = position_stack(reverse = TRUE), width = 0.65,
           colour = "#767676", linewidth = 0.25) +
  geom_text(aes(label = ifelse(count > 0, count, "")),
            position = position_stack(vjust = 0.5, reverse = TRUE), size = 3.5) +
  coord_flip() +
  scale_x_discrete(labels = c(decision = "Accepted / Rejected",
    TA_exclCriteria = "Rejection criterion", Topic = "Topic",
    TaxaGroup = "Taxa group", fishingGear = "Fishing gear")) +
  scale_fill_manual(values = c(solved = "#C48A32", blank = "#FFFFFF"),
                    labels = c(solved = "Solved", blank = "Blank")) +
  labs(title = "Missing fields across all initial reviews",
       subtitle = paste(sum(gap_totals$initial), "initial gaps across both reviewer groups"),
       x = NULL, y = "Fields", fill = NULL) + plot_theme

# Display the figure and save PNG and PDF copies.
print(p_gap_totals)

ggsave(file.path(figure_dir, "figure_3b_missing_fields_total.png"), p_gap_totals,
       width = 11, height = 6, dpi = 300, bg = "white")

ggsave(file.path(figure_dir, "figure_3b_missing_fields_total.pdf"), p_gap_totals,
       width = 11, height = 6)

# Check final completeness separately, including newly applicable fields.
# Count each paper and field once, even for papers with two reviewers.
final_missing <- field_details %>%
  dplyr::distinct(paperID, field, final_applicable, final_value) %>%
  dplyr::group_by(field) %>%
  dplyr::summarise(applicable = sum(final_applicable),
                   missing = sum(final_applicable & (is.na(final_value) | stringr::str_squish(final_value) == "")), .groups = "drop")

# 4. Individual reviewer feedback ---------------------------------------------

# 4.1. Prepare excel: comparison original reviewer vs. reviewer 3---------------
# Keep the citation fields and put the two values for each coding field side by side.
citation_columns <- c("paperID", "title", "abstract", "keywords", "authors", "year", "doi")
feedback_fields <- c("TA_decisionRev1", "TA_exclCriteria", "Topic", "TaxaGroup", "fishingGear")

# Keep only fields Reviewer 3 changed or filled for the specific initial reviewer.
# A field with the same value stays empty in both columns after widening.
feedback_rows <- field_details %>%
  dplyr::filter(changed_value | completed_value) %>%
  dplyr::transmute(
    reviewer, paperID,
    field = factor(field, levels = coding_fields, labels = feedback_fields),
    # When Reviewer 3 filled a blank, leave the original cell empty.
    original = dplyr::if_else(completed_value, NA_character_, initial_value),
    reviewer3 = reviewer3_value
  ) %>%
  # Keep one row per reviewer and paper, including columns for fields with no changes.
  tidyr::pivot_wider(
    id_cols = c(reviewer, paperID), names_from = field,
    values_from = c(original, reviewer3), names_glue = "{field}_{.value}",
    names_expand = TRUE
  ) %>%
  dplyr::left_join(screening %>% dplyr::select(dplyr::all_of(citation_columns)), by = "paperID") %>%
  dplyr::select(reviewer, dplyr::all_of(citation_columns),
                dplyr::all_of(c(rbind(paste0(feedback_fields, "_original"),
                                      paste0(feedback_fields, "_reviewer3")))))

# Use a separate filename for each reviewer and check for collisions after cleaning names.
reviewer_files <- reviewer_summary %>%
  dplyr::mutate(filename = paste0("feedback_", stringr::str_replace_all(
    reviewer, "[^A-Za-z0-9_-]", "_"), ".xlsx"))
if (anyDuplicated(tolower(reviewer_files$filename))) {
  stop("Reviewer names produce colliding filenames; use distinct reviewer identifiers.")
}

for (i in seq_len(nrow(reviewer_files))) {
  # The filename identifies the reviewer, so the sheet only needs paper and field columns.
  details <- feedback_rows %>%
    dplyr::filter(reviewer == reviewer_files$reviewer[i]) %>%
    dplyr::select(-reviewer)

  # Write the before-and-after comparisons to a single sheet with a frozen header.
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Field_details")
  openxlsx::writeData(wb, "Field_details", details, withFilter = TRUE,
                      headerStyle = openxlsx::createStyle(fgFill = "#173E50",
                        fontColour = "white", textDecoration = "bold"))
  openxlsx::freezePane(wb, "Field_details", firstRow = TRUE)
  openxlsx::setColWidths(wb, "Field_details", cols = seq_len(ncol(details)), widths = 30)
  openxlsx::setColWidths(wb, "Field_details",
                         cols = match(c("title", "abstract", "keywords"), names(details)),
                         widths = 60)

  # Highlight only the cells where Reviewer 3 supplied a different or new value.
  for (column in paste0(feedback_fields, "_reviewer3")) {
    rows <- which(!is.na(details[[column]])) + 1L
    if (length(rows) > 0) {
      openxlsx::addStyle(wb, "Field_details", openxlsx::createStyle(fontColour = "#C00000"),
                         rows = rows, cols = match(column, names(details)))
    }
  }

  # Save the new sheet layout under the same reviewer feedback filename.
  openxlsx::saveWorkbook(wb, file.path(feedback_dir, reviewer_files$filename[i]), overwrite = TRUE)
}

# 4.2. Export summary workbook -------------------------------------------------

# Distinct IDs, never the sum of reviewer-level counts for a two-reviewer paper.
paper_interventions <- reviewer_rows %>%
  dplyr::group_by(paperID, review_route) %>%
  dplyr::summarise(changed = any(changed), completed = any(completed), .groups = "drop")

# Count papers changed, completed, both, or with either intervention.
intervention_totals <- paper_interventions %>%
  dplyr::summarise(n_changed = sum(changed), n_completed = sum(completed),
                   n_both = sum(changed & completed), n_intervened = sum(changed | completed))

# Count changed and completed papers separately by the reason for Reviewer 3 review.
route_summary <- dplyr::bind_rows(
  paper_interventions %>% dplyr::filter(changed) %>%
    dplyr::count(review_route, name = "n_papers") %>%
    dplyr::mutate(intervention = "Changed an existing value"),
  paper_interventions %>% dplyr::filter(completed) %>%
    dplyr::count(review_route, name = "n_papers") %>%
    dplyr::mutate(intervention = "Completed a blank value"))

# Show zero counts for routes with no papers whenever there are interventions to report.
if (nrow(route_summary) > 0) {
  route_summary <- route_summary %>% tidyr::complete(
    # Give combined cases their own label before checking the individual reasons.
    review_route = c("Initial disagreement", "Incomplete decision", "Additional review",
                     "Initial issue + additional review"),
    intervention, fill = list(n_papers = 0L))
}

# Build the Decision_changes sheet to show how Reviewer 3 changed or supplied screening decisions.
decision_changes <- field_details %>%
  # Keep only Accepted/Rejected entries that Reviewer 3 changed or filled.
  dplyr::filter(field == "decision", changed_value | completed_value) %>%
  # Count each before/after pair within its review route. A blank initial value means the decision was filled.
  # The unit is an initial evaluation, so a paper with two reviewers can contribute twice.
  dplyr::count(review_route, initial_value, reviewer3_value, name = "n_initial_evaluations")

# Check that the source workbook has not changed before writing the summary.
stopifnot(identical(unname(tools::md5sum(screening_file)), input_hash))

# Write the report tables together with the source path and fingerprint.
openxlsx::write.xlsx(list(
  Source = data.frame(input_file = normalizePath(screening_file, winslash = "/"),
                      input_md5 = input_hash),
  Unique_outcomes = outcome_summary, Review_routes = route_summary,
  Figure2_changes = figure2_summary, Figure2_papers = figure2_papers,
  Gap_totals = gap_totals,
  Final_missing = final_missing,
  Intervention_totals = intervention_totals,
  Decision_changes = decision_changes,
  Reviewer_summary = reviewer_summary, Missing_fields = missing_summary,
  Paper_interventions = paper_interventions, Field_details = field_details,
  Reviewer_files = reviewer_files
), file.path(feedback_dir, "screening_feedback_summary.xlsx"), overwrite = TRUE)
message("Meeting figures and reviewer feedback saved in: ", feedback_dir)
