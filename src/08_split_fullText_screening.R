# -----------------------------------------------------------------------------

# Title:

#--------------------------------------------------------------------------------
# 08. Assign full-text screening reviewers
#--------------------------------------------------------------------------------

library(readxl)
library(dplyr)
library(openxlsx)
library(ggplot2)

# 1. Input and output paths -----------------------------------------------------

# 1.1. Read the output of script 06 and write a separate assignment workbook ----

screening_file <- file.path(output_data, "full_text_screening", "accepted_full_text_all.xlsx")
assignment_file <- file.path(output_data, "full_text_screening", "split_fullText_screening.xlsx")

figure_dir <- file.path(output_data, "full_text_screening", "assignment_figures")

# 2. Prepare the assignment groups ---------------------------------------------

# 2.1. Keep the bibliography and final abstract-screening classifications -----

paper_columns <- c("paperID", "title", "abstract", "keywords", "authors", "year", "journal",
                   "doi", "Language", "source", "final_decision", "Topic_standardised",
                   "TaxaGroup_standardised", "fishingGear_standardised")
papers <- read_excel(screening_file, sheet = "accepted_papers") %>%
  select(all_of(paper_columns)) %>%
  rename(abstract_screening_decision = final_decision) %>%
  mutate(paperID = trimws(as.character(paperID))) %>%
  arrange(paperID)

# Each accepted paper must enter the allocation exactly once.
stopifnot(nrow(papers) == 326L, !anyNA(papers$paperID), all(nzchar(papers$paperID)),
          !anyDuplicated(papers$paperID), all(papers$abstract_screening_decision %in% "Accepted"))

# 2.2. Use one topic per paper for workload accounting --------------------------

# For papers with several labels, use the provisional priority agreed for the workload.
# Keep all source labels unchanged in the exported paper table.
topics <- c("Megafauna catch", "Ghost gear", "IUU fishing", "Fishing effort")
papers$topic <- NA_character_
for (topic in rev(topics)) {
  # A higher-priority topic takes precedence over any previously assigned topic.
  papers$topic[grepl(topic, papers$Topic_standardised, fixed = TRUE)] <- topic
}
stopifnot(!anyNA(papers$topic))

# 2.3. Name the reviewers and define the megafauna groups -----------------------

reviewers <- c("David Ruiz-García", "Paola Gabasa", "Clara Lerebourg", "Ignacio de Saint-Malo Zamacola",
               "Diego Fernández-Fernández", "Teresa Militão", "Ana Carneiro", "Núria Patiño Sevillano",
               "Alejandro Espada-Pastor", "David M. Kaplan", "Leia Navarro-Herrero", "Jazel Ouled-Cheikh",
               "Catarina N. S. Silva", "Gill Ainsworth", "Esther Mollier")
megafauna <- which(papers$topic == "Megafauna catch")
taxon <- papers$TaxaGroup_standardised
gear <- papers$fishingGear_standardised
unknown_taxon <- megafauna[is.na(taxon[megafauna]) | taxon[megafauna] == "Unclassified"]

# 3. Assign the first reviewer -------------------------------------------------

# 3.1. Allocate clear megafauna groups before sharing the flexible papers -------

primary <- rep(NA_integer_, nrow(papers))
turtles <- megafauna[grepl("Sea turtles", taxon[megafauna], fixed = TRUE)]
mixed_turtles <- turtles[taxon[turtles] != "Sea turtles"]
primary[turtles] <- 4L
primary[mixed_turtles] <- 13L

# Reserve the mammal and bird lots for the relevant specialists.
mammals <- setdiff(megafauna[grepl("Marine mammals", taxon[megafauna], fixed = TRUE)], turtles)
primary[mammals] <- 5L
birds <- megafauna[which(taxon[megafauna] == "Seabirds")]
stopifnot(length(birds) == 38L)
set.seed(20261106)
primary[sample(birds)] <- rep(6:8, c(13, 13, 12))

# Share seven longline papers with Clara, then balance the uncoded gear within the taxon.
sharks <- megafauna[which(taxon[megafauna] == "Chondrichthyans")]
longline <- sharks[which(gear[sharks] == "Longline")]
primary[sharks[which(gear[sharks] %in% c("Trawl", "Longline, Trawl"))]] <- 1L
primary[longline] <- 2L
primary[sample(longline, 7)] <- 3L
primary[sharks[which(gear[sharks] == "Purse seine")]] <- 3L

# Keep Esther's provisional megafauna lot to records with clear purse-seine or FAD signals.
# These titles and abstracts were flagged for the pilot. The source gear remains unchanged.
esther_ids <- c("296", "548", "881", "1019", "1769")
esther_rows <- match(esther_ids, papers$paperID)
stopifnot(!anyNA(esther_rows), all(esther_rows %in% sharks))
primary[esther_rows] <- 15L

# Assign each remaining shark paper to the least-loaded chondrichthyan reviewer.
for (row in sharks[is.na(primary[sharks])]) {
  load <- tabulate(primary, nbins = length(reviewers))
  primary[row] <- which.min(load[1:3])
}

# 3.2. Share papers with no taxon equally across the megafauna team ------------

# Distribute the extra papers to the reviewers with the lightest first-review loads.
team <- c(1:8, 13L, 15L)
team <- team[order(tabulate(primary, nbins = length(reviewers))[team])]
primary[sample(unknown_taxon)] <- rep(team, length.out = length(unknown_taxon))

# 3.3. Fill the agreed first-review quotas for the other three topics -----------

quotas <- list("Fishing effort" = c("9" = 18, "10" = 18, "11" = 11, "12" = 20),
               "IUU fishing" = c("9" = 5, "10" = 5, "11" = 5, "13" = 16, "14" = 17),
               "Ghost gear" = c("11" = 5, "15" = 8))

for (topic in names(quotas)) {
  # Shuffle within each topic so the allocation does not depend on workbook row order.
  rows <- which(papers$topic == topic)
  quota <- quotas[[topic]]
  stopifnot(length(rows) == sum(quota))
  primary[sample(rows)] <- rep(as.integer(names(quota)), quota)
}
stopifnot(!anyNA(primary))

# 4. Assign the second reviewer ------------------------------------------------

# 4.1. Set the number of double reviews in each topic ---------------------------

# Allocate 82 double reviews proportionally, using the largest remainders.
target <- round(nrow(papers) * 0.25)
topic_sizes <- table(factor(papers$topic, levels = topics))
exact <- target * as.numeric(topic_sizes) / nrow(papers)
overlap <- floor(exact)
extra <- order(exact - overlap, decreasing = TRUE)[seq_len(target - sum(overlap))]
overlap[extra] <- overlap[extra] + 1L

# 4.2. Select distinct reviewer pairs while balancing total workload ------------

# Use the reviewers already assigned to each topic, so a second review does not create a new tiny lot.
second <- rep(NA_integer_, nrow(papers))
load <- tabulate(primary, nbins = length(reviewers))
shuffled <- sample(seq_len(nrow(papers)))

for (i in seq_along(topics)) {
  # Track coverage by taxon and gear within each topic when choosing among eligible papers.
  rows <- shuffled[papers$topic[shuffled] == topics[i]]
  group <- paste(taxon, gear)
  covered <- character()

  for (j in seq_len(overlap[i])) {
    # Prefer a reviewer with a lower combined load who can read a different paper in this topic.
    available <- rows[is.na(second[rows])]
    eligible <- sort(unique(primary[rows]))
    candidates_by_reviewer <- vector("list", length(reviewers))
    for (reviewer in eligible) {
      # Reviewers can only double-review someone else's paper.
      candidates <- available[primary[available] != reviewer]
      if (topics[i] == "Megafauna catch") {
        # Use the same taxon teams for second readings. Unclassified papers can go to any team member.
        taxon_candidates <- switch(as.character(reviewer),
          "1" = sharks, "2" = sharks, "3" = sharks,
          "4" = turtles, "5" = megafauna[grepl("Marine mammals", taxon[megafauna], fixed = TRUE)],
          "6" = birds, "7" = birds, "8" = birds, "13" = turtles,
          "15" = sharks[which(gear[sharks] == "Purse seine")])
        candidates <- intersect(candidates, union(taxon_candidates, unknown_taxon))
      }
      candidates_by_reviewer[[reviewer]] <- candidates
    }
    eligible <- eligible[lengths(candidates_by_reviewer)[eligible] > 0L]
    stopifnot(length(eligible) > 0L)
    reviewer <- eligible[which.min(load[eligible])]

    # Spread overlap across strata before reusing a taxon and gear combination.
    candidates <- candidates_by_reviewer[[reviewer]]
    row <- candidates[which.min(vapply(group[candidates], function(g) sum(covered == g), integer(1)))]
    second[row] <- reviewer
    load[reviewer] <- load[reviewer] + 1L
    covered <- c(covered, group[row])
  }
}

# 5. Check and export the assignment -------------------------------------------

# 5.1. Count both reading rounds by person and topic ----------------------------

workload <- bind_rows(
  tibble(reviewer = reviewers[primary], topic = papers$topic, round = "Primary"),
  tibble(reviewer = reviewers[second], topic = papers$topic, round = "Second") %>%
    filter(!is.na(reviewer))
) %>%
  group_by(reviewer, topic) %>%
  summarise(n_primary = sum(round == "Primary"), n_second = sum(round == "Second"), .groups = "drop") %>%
  mutate(n_total = n_primary + n_second)

# Every paper has a first reviewer. Exactly 82 have a different second reviewer.
stopifnot(sum(workload$n_primary) == nrow(papers), sum(workload$n_second) == target,
          all(is.na(second) | second != primary), all(workload$n_total >= 5L))

# 5.2. Count each reading in one topic, gear and taxon column ------------------

# Use separate categories for multiple labels and for missing classifications.
gear_labels <- c("Longline", "Purse seine", "Trawl")
gear_headers <- c("n_longline", "n_purse_seine", "n_trawl", "n_multi_gear", "n_gear_unclassified")
gear_index <- case_when(
  grepl(",", gear, fixed = TRUE) ~ 4L,
  TRUE ~ coalesce(match(gear, gear_labels), 5L)
)

taxon_labels <- c("Chondrichthyans", "Sea turtles", "Seabirds", "Marine mammals")
taxon_headers <- c("n_chondrichthyan", "n_seaturtle", "n_seabird", "n_marinemammal",
                   "n_multi_taxon", "n_taxon_unclassified")
taxon_index <- case_when(
  grepl(",", taxon, fixed = TRUE) ~ 5L,
  TRUE ~ coalesce(match(taxon, taxon_labels), 6L)
)

# Store one row per reviewer and paper assignment, including both reading rounds.
readings <- tibble(
  reviewer = c(reviewers[primary], reviewers[second]),
  topic = rep(papers$topic, 2),
  gear = rep(gear_index, 2),
  taxon = rep(taxon_index, 2)
) %>% filter(!is.na(reviewer))

# Put the requested topic groups in display order and sum both reading rounds.
display_topics <- c("Megafauna catch", "IUU fishing", "Fishing effort", "Ghost gear")
topic_headers <- c("n_megafauna_catch", "n_IUU", "n_fishing_effort", "n_ghost_gear")
total_counts <- tabulate(match(readings$reviewer, reviewers), nbins = length(reviewers))
workload_cells <- data.frame(reviewer = reviewers, n_total = total_counts)
topic_spans <- rep(length(gear_headers), length(display_topics))
topic_spans[1] <- length(gear_headers) * length(taxon_headers)

# Build the columns in the same order as the merged headers below.
for (topic in display_topics) {
  for (gear_id in seq_along(gear_headers)) {
    # Only the megafauna group is split by taxon.
    gear_readings <- readings %>% filter(.data$topic == .env$topic, .data$gear == gear_id)
    if (topic == "Megafauna catch") {
      for (taxon_id in seq_along(taxon_headers)) {
        # Count this taxon and gear combination once per reading.
        ids <- gear_readings$reviewer[gear_readings$taxon == taxon_id]
        workload_cells[[ncol(workload_cells) + 1L]] <- tabulate(match(ids, reviewers), nbins = length(reviewers))
      }
    } else {
      # Count this gear once per reading for the other topics.
      ids <- gear_readings$reviewer
      workload_cells[[ncol(workload_cells) + 1L]] <- tabulate(match(ids, reviewers), nbins = length(reviewers))
    }
  }
}

# Confirm that the detailed cells add up to the reviewer totals and the project total.
stopifnot(all(rowSums(workload_cells[-c(1, 2)]) == workload_cells$n_total),
          sum(workload_cells$n_total) == nrow(papers) + target)

# 5.3. Export the paper list and the workload with merged headers ---------------

# Keep the classifications used for assignments and omit the two redundant source fields.
full_text_papers <- papers %>%
  select(-topic, -Language, -abstract_screening_decision) %>%
  mutate(full_text_reviewer_1 = reviewers[primary], full_text_reviewer_2 = reviewers[second])

# Protect any existing workbook that is already in use.
if (file.exists(assignment_file)) {
  stop("Assignment workbook already exists: ", assignment_file)
}

workbook <- createWorkbook()
addWorksheet(workbook, "Full_text_papers")
writeData(workbook, "Full_text_papers", full_text_papers, withFilter = TRUE)
freezePane(workbook, "Full_text_papers", firstRow = TRUE)

# Keep reviewer names and totals visible while scrolling through the breakdown.
addWorksheet(workbook, "Workload")
writeData(workbook, "Workload", workload_cells, startRow = 4, colNames = FALSE)
freezePane(workbook, "Workload", firstActiveRow = 4, firstActiveCol = 3)
setColWidths(workbook, "Workload", cols = 1, widths = 36)
setColWidths(workbook, "Workload", cols = 2:ncol(workload_cells), widths = 22)

# Merge the reviewer and total headers vertically across all three header rows.
for (column in 1:2) {
  writeData(workbook, "Workload", names(workload_cells)[column], startCol = column)
  mergeCells(workbook, "Workload", cols = column, rows = 1:3)
}

# Write a top-level header for each topic, then its gear and optional taxon headers.
column <- 3L
for (i in seq_along(display_topics)) {
  topic_columns <- seq.int(column, length.out = topic_spans[i])
  writeData(workbook, "Workload", topic_headers[i], startCol = column)
  mergeCells(workbook, "Workload", cols = topic_columns, rows = 1)

  for (gear_header in gear_headers) {
    writeData(workbook, "Workload", gear_header, startCol = column, startRow = 2)
    if (display_topics[i] == "Megafauna catch") {
      # Give each gear one merged heading above its individual taxon columns.
      taxon_columns <- seq.int(column, length.out = length(taxon_headers))
      mergeCells(workbook, "Workload", cols = taxon_columns, rows = 2)
      writeData(workbook, "Workload", t(taxon_headers), startCol = column, startRow = 3, colNames = FALSE)
      column <- column + length(taxon_headers)
    } else {
      # The gear is the lowest level for these topics, so span the taxon row.
      mergeCells(workbook, "Workload", cols = column, rows = 2:3)
      column <- column + 1L
    }
  }
}

# Format the headers as a single band and save the two-sheet workbook.
header_style <- createStyle(fgFill = "#173E50", fontColour = "white", textDecoration = "bold",
                            halign = "center", valign = "center", wrapText = TRUE)
addStyle(workbook, "Workload", header_style, rows = 1:3, cols = seq_len(ncol(workload_cells)),
         gridExpand = TRUE)
setRowHeights(workbook, "Workload", rows = 1:3, heights = 32)
saveWorkbook(workbook, assignment_file, overwrite = FALSE)

# 6. Plot full-text assignments -------------------------------------------------

# 6.1. Set colours and reviewer order -------------------------------------------

# Use the same one-reading-per-reviewer records that feed the Workload sheet.
dir.create(figure_dir, showWarnings = FALSE, recursive = TRUE)
reviewer_order <- reviewers[order(total_counts, reviewers)]
# Match the original abstract-screening codes to the reviewer roster for plot labels.
reviewer_codes <- setNames(
  c("DRG", "PGU", "CL", "ISM", "DFF", "TM", "ABC", "NPS", "AEP", "DK", "LNH", "JOB", "CS", "GA", "EM"),
  reviewers)

# Use Viridis for the overview and keep the same gear order in every detail plot.
topic_colours <- setNames(viridisLite::viridis(4, begin = 0.12, end = 0.9), display_topics)
gear_levels <- c("Longline", "Purse seine", "Trawl", "Multiple gears", "Unclassified")

# Anchor each gear palette in its topic colour and use contrasting accent colours.
# Unclassified gear stays grey in every plot.
gear_palettes <- list(
  "Megafauna catch" = c(topic_colours[[1]], "#5A9DA0", "#D48556", "#C59AC7", "#999999"),
  "IUU fishing" = c(topic_colours[[2]], "#D49D45", "#76B6A5", "#AD6C86", "#999999"),
  "Fishing effort" = c(topic_colours[[3]], "#7664A3", "#D08453", "#B8B953", "#999999"),
  "Ghost gear" = c(topic_colours[[4]], "#5B5699", "#3E8B93", "#C47556", "#999999")
)
plot_theme <- theme_minimal(base_size = 12) +
  theme(panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(),
        legend.position = "bottom", plot.title = element_text(face = "bold"))

# 6.2. Plot total assigned readings by topic ------------------------------------

# Keep one row per reviewer and topic for the stacked overview.
topic_plot_data <- readings %>%
  count(reviewer, topic, name = "n_readings") %>%
  mutate(reviewer = factor(reviewer, levels = reviewer_order),
         topic = factor(topic, levels = display_topics))

stopifnot(sum(topic_plot_data$n_readings) == sum(workload_cells$n_total))

p_topic_workload <- ggplot(topic_plot_data, aes(n_readings, reviewer, fill = topic)) +
  geom_col(width = 0.7) +
  scale_y_discrete(labels = reviewer_codes) +
  scale_fill_manual(values = topic_colours, drop = FALSE) +
  scale_x_continuous(breaks = scales::breaks_width(5), expand = expansion(mult = c(0, 0.05))) +
  labs(title = "Full-text screening workload by reviewer",
       subtitle = paste(sum(topic_plot_data$n_readings), "first and second readings"),
       x = "Assigned papers", y = NULL, fill = NULL) +
  plot_theme
print(p_topic_workload)
ggsave(file.path(figure_dir, "01_workload_by_topic.png"), p_topic_workload,
       width = 11, height = 7, dpi = 300, bg = "white")

p_topic_workload

# 6.3. Prepare gear counts for the topic and taxon plots ------------------------

# Give each reading one plot group and one gear category, matching the workbook.
taxon_plot_groups <- c("Chondrichthyans", "Sea turtles", "Seabirds", "Marine mammals",
                       "Mixed and unclassified taxa", "Mixed and unclassified taxa")
gear_plot_data <- readings %>%
  mutate(plot_group = if_else(topic == "Megafauna catch", taxon_plot_groups[taxon], topic),
         gear_label = factor(gear_levels[gear], levels = gear_levels)) %>%
  count(plot_group, reviewer, gear_label, name = "n_readings") %>%
  mutate(reviewer = factor(reviewer, levels = reviewer_order))

stopifnot(sum(gear_plot_data$n_readings) == sum(workload_cells$n_total))

# 6.4. Save one stacked gear plot per topic or megafauna group ------------------

# Plot the three other topics, four named taxa and a companion panel for remaining taxa.
plot_groups <- c("IUU fishing", "Fishing effort", "Ghost gear", unique(taxon_plot_groups))
plot_files <- c("02_iuu_by_gear", "03_fishing_effort_by_gear", "04_ghost_gear_by_gear",
                "05_chondrichthyans_by_gear", "06_sea_turtles_by_gear", "07_seabirds_by_gear",
                "08_marine_mammals_by_gear", "09_mixed_and_unclassified_taxa_by_gear")
for (i in seq_along(plot_groups)) {
  # Keep the common reviewer order and show only reviewers assigned in this group.
  plot_data <- gear_plot_data %>% filter(plot_group == plot_groups[i])
  # Use the megafauna palette for all taxon plots.
  palette_topic <- if (plot_groups[i] %in% display_topics) plot_groups[i] else "Megafauna catch"
  gear_colours <- setNames(gear_palettes[[palette_topic]], gear_levels)
  p_gear_workload <- ggplot(plot_data, aes(n_readings, reviewer, fill = gear_label)) +
    geom_col(width = 0.7) +
    scale_y_discrete(labels = reviewer_codes) +
    scale_fill_manual(values = gear_colours, drop = FALSE) +
    scale_x_continuous(breaks = scales::breaks_width(2), expand = expansion(mult = c(0, 0.05))) +
    labs(title = paste(plot_groups[i], "by reviewer and gear"),
         subtitle = paste(sum(plot_data$n_readings), "first and second readings"),
         x = "Assigned papers", y = NULL, fill = NULL) +
    plot_theme

  # Allow taller plots when more reviewers have assignments in this group.
  plot_height <- max(4, 2 + 0.35 * n_distinct(plot_data$reviewer))
  print(p_gear_workload)
  ggsave(file.path(figure_dir, paste0(plot_files[i], ".png")), p_gear_workload,
         width = 10, height = plot_height, dpi = 300, bg = "white")
}
