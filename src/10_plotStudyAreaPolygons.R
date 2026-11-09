# 10. Trace study area outlines from a PDF -------------------------------------

# Load the project setup, then click Source once in RStudio.
# The assistant gives instructions for every step in its own window.

# 1. Set paths and check the rendering tools -----------------------------------

if (!interactive()) stop("Run this script from an interactive R session.")
polygon_dir <- file.path(input_data, "study_area_polygons")

# Find Poppler on PATH or in the bundled Windows runtime.
pdftoppm <- Sys.which("pdftoppm")
if (!nzchar(pdftoppm)) {
  pdftoppm <- file.path(Sys.getenv("USERPROFILE"), ".cache", "codex-runtimes",
                        "codex-primary-runtime", "dependencies", "native", "poppler",
                        "Library", "bin", "pdftoppm.exe")
}
pdfinfo <- file.path(dirname(pdftoppm), if (.Platform$OS.type == "windows") "pdfinfo.exe" else "pdfinfo")
if (!file.exists(pdftoppm) || !file.exists(pdfinfo)) stop("Poppler needs pdftoppm and pdfinfo.")

# 2. Build the assistant window ------------------------------------------------

# 2.1. Keep instructions and controls above the map -----------------------------

window <- tcltk::tktoplevel()
tcltk::tkwm.title(window, "REDUCE | Study area tracing")
step_title <- tcltk::tclVar("")
instructions <- tcltk::tclVar("")
status <- tcltk::tclVar("")
page_input <- tcltk::tclVar("")
file_label <- tcltk::tclVar("No PDF selected")
trace_choice <- tcltk::tclVar("")
header <- tcltk::tkframe(window, padx = 14, pady = 8)
controls <- tcltk::tkframe(window, padx = 14)
canvas <- tcltk::tkcanvas(window, width = 1000, height = 620, background = "#E8EDF3", highlightthickness = 0)
tcltk::tkpack(header, controls, canvas, fill = "x")
tcltk::tkpack(tcltk::tklabel(header, textvariable = step_title, font = "TkHeadingFont"),
              tcltk::tklabel(header, textvariable = instructions, wraplength = 970, justify = "left"),
              tcltk::tklabel(header, textvariable = status, foreground = "#174E76", wraplength = 970,
                             justify = "left"), anchor = "w")

# Keep the page and edits in memory until the user explicitly saves a revision.
pdf_file <- NULL
page_count <- 0L
page <- NA_integer_
step <- "file"
preview_dpi <- 125L
detail_dpi <- 600L
preview_file <- tempfile(fileext = ".png")
detail_file <- tempfile(fileext = ".png")
display_file <- tempfile(fileext = ".png")
photo <- tcltk::tkimage.create("photo")
corners <- matrix(numeric(), ncol = 2)
points <- matrix(numeric(), ncol = 2)
old_points <- matrix(numeric(), ncol = 2)
traces <- list(list())
trace_index <- 1L
trace_matches <- integer()
reference_labels <- character()
image_size <- display_size <- c(0, 0)
left <- top <- 0

# 2.2. Update controls and draw the current image -------------------------------

# Display errors in the assistant so the user can retry from the same window.
attempt <- function(action) {
  # Leave the window open if a file cannot be read or a polygon cannot be saved.
  tryCatch(action(), error = function(error) tcltk::tclvalue(status) <- conditionMessage(error))
}

# Fit the panel to the canvas and retain the scale used to interpret mouse clicks.
show_image <- function(file) {
  # Resize the display copy only. Coordinates stay in pixels of the original render.
  image <- png::readPNG(file)
  image_size <<- c(dim(image)[2], dim(image)[1])
  ratio <- min(1000 / image_size[1], 620 / image_size[2])
  display_size <<- pmax(1, round(image_size * ratio))
  cols <- pmin(image_size[1], floor((seq_len(display_size[1]) - 0.5) / ratio) + 1)
  rows <- pmin(image_size[2], floor((seq_len(display_size[2]) - 0.5) / ratio) + 1)
  display <- if (length(dim(image)) == 3L) image[rows, cols, , drop = FALSE] else image[rows, cols]
  png::writePNG(display, display_file)
  tcltk::tcl(photo, "configure", "-file", display_file)
  tcltk::tkdelete(canvas, "all")
  tcltk::tkcreate(canvas, "image", 0, 0, anchor = "nw", image = photo)
}

# Update only the drawn marks when a vertex is added or removed.
draw_marks <- function() {
  # The saved outline is blue, and the new outline and its vertices are orange.
  tcltk::tkdelete(canvas, "marks")
  for (kind in c("reference", "current")) {
    xy <- if (kind == "reference") old_points else points
    if (nrow(xy) == 0L) next
    colour <- if (kind == "reference") "#0065A8" else "#DC4A11"
    if (kind == "current" && step %in% c("review", "saved")) xy <- rbind(xy, xy[1, ])
    xy <- sweep(xy, 2, display_size / image_size, "*")
    if (nrow(xy) > 1L) {
      do.call(tcltk::tkcreate, c(list(canvas, "line"), as.list(c(t(xy))),
                              list(fill = colour, width = 2, tags = "marks")))
    }
    if (kind == "current" && step != "crop") {
      for (i in seq_len(nrow(xy))) {
        # Mark each vertex so it is easy to see where the last click landed.
        tcltk::tkcreate(canvas, "oval", xy[i, 1] - 3, xy[i, 2] - 3, xy[i, 1] + 3, xy[i, 2] + 3,
                        fill = colour, outline = "white", tags = "marks")
      }
    }
  }
}

# 3. Choose a PDF, a page and a map panel ---------------------------------------

# Render from the PDF again for the detail view instead of enlarging the preview.
render_page <- function(dpi, destination, crop = character()) {
  # Keep Poppler output in temporary files. Check that it produced the requested page.
  prefix <- tools::file_path_sans_ext(destination)
  args <- c("-f", page, "-l", page, "-r", dpi, "-png", "-singlefile", crop, shQuote(pdf_file), shQuote(prefix))
  result <- system2(pdftoppm, args, stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(result, "status")) || !file.exists(destination)) stop("Could not render PDF page ", page, ".")
}

choose_pdf <- function() attempt(function() {
  # Read the page count before enabling selection of a page.
  selected <- as.character(tcltk::tkgetOpenFile(parent = window, title = "Choose a PDF",
                                                  filetypes = "{{PDF files} {.pdf}}"))
  if (!nzchar(selected)) return(invisible(NULL))
  details <- system2(pdfinfo, shQuote(selected), stdout = TRUE, stderr = TRUE)
  count_line <- grep("^Pages:[[:space:]]+[0-9]+[[:space:]]*$", details, value = TRUE)
  if (length(count_line) != 1L || !is.null(attr(details, "status"))) stop("Could not read the PDF page count.")
  pdf_file <<- selected
  page_count <<- as.integer(sub("^Pages:[[:space:]]+", "", count_line))
  tcltk::tclvalue(file_label) <- basename(pdf_file)
  tcltk::tclvalue(page_input) <- ""
  tcltk::tclvalue(status) <- sprintf("Enter a PDF page from 1 to %d, counting from the first page.", page_count)
  tcltk::tkfocus(page_entry)
})

open_page <- function() attempt(function() {
  # Keep the user on the current step when the page input is invalid.
  answer <- trimws(tcltk::tclvalue(page_input))
  selected_page <- suppressWarnings(as.integer(answer))
  if (is.null(pdf_file)) stop("Choose a PDF first.")
  if (!grepl("^[0-9]+$", answer) || is.na(selected_page) || selected_page < 1L || selected_page > page_count) {
    stop("Enter a whole page number from 1 to ", page_count, ".")
  }
  page <<- selected_page
  preview_file <<- tempfile(fileext = ".png")
  render_page(preview_dpi, preview_file)
  start_crop()
})

start_crop <- function() {
  # Reset the selection and return to the full page. Earlier JSON files stay intact.
  corners <<- points <<- old_points <<- matrix(numeric(), ncol = 2)
  traces <<- list(list())
  trace_index <<- 1L
  trace_matches <<- integer()
  tcltk::tkconfigure(reference_box, values = character(), state = "disabled")
  tcltk::tclvalue(trace_choice) <- ""
  show_image(preview_file)
  set_step("crop")
}

open_crop <- function() {
  # Translate the two preview clicks into the 600 dpi coordinates expected by Poppler.
  scale <- detail_dpi / preview_dpi
  left <<- floor(min(corners[, 1]) * scale)
  top <<- floor(min(corners[, 2]) * scale)
  right <- ceiling(max(corners[, 1]) * scale)
  bottom <- ceiling(max(corners[, 2]) * scale)
  if (right - left < 10 || bottom - top < 10) {
    corners <<- matrix(numeric(), ncol = 2)
    stop("The crop is too small. Click two opposite corners around the entire map.")
  }
  crop <- c("-x", left, "-y", top, "-W", right - left, "-H", bottom - top)
  detail_file <<- tempfile(fileext = ".png")
  render_page(detail_dpi, detail_file, crop)
  show_image(detail_file)
  set_step("draw")
}

# 4. Trace, check and save one outline ----------------------------------------

# 4.1. Load a reference and add or remove vertices -----------------------------

select_reference <- function() attempt(function() {
  # The reference is transformed from full-page pixels to the current crop.
  choice <- match(tcltk::tclvalue(trace_choice), reference_labels)
  if (is.na(choice)) return(invisible(NULL))
  trace_index <<- trace_matches[choice]
  previous <- traces[[trace_index]]
  dpi <- previous$render_dpi
  if (is.null(dpi) && isTRUE(grepl("125 dpi", previous$coordinate_space, fixed = TRUE))) dpi <- 125
  if (length(dpi) != 1L || !is.finite(dpi) || dpi <= 0) stop("The reference has no recognised resolution.")
  if (!is.null(previous$pdf_md5) && !identical(previous$pdf_md5, unname(tools::md5sum(pdf_file)))) {
    stop("The reference belongs to a different PDF.")
  }
  xy <- do.call(rbind, lapply(previous$vertices, unlist)) * detail_dpi / dpi
  old_points <<- sweep(xy, 2, c(left, top), "-")
  draw_marks()
  tcltk::tclvalue(status) <- "Blue: saved reference. Orange: your new outline."
})

load_reference <- function() attempt(function() {
  # Offer only the saved outlines on the selected PDF page.
  selected <- as.character(tcltk::tkgetOpenFile(parent = window, title = "Choose a trace JSON",
                                                  filetypes = "{{JSON files} {.json}}"))
  if (!nzchar(selected)) return(invisible(NULL))
  loaded <- jsonlite::read_json(selected)
  matches <- which(vapply(loaded, function(trace) isTRUE(trace$pdf_page == page), logical(1)))
  if (!length(matches)) stop("This JSON has no outline for the selected page.")
  traces <<- loaded
  trace_matches <<- matches
  reference_labels <<- vapply(matches, function(i) {
    # Older traces identify the outline by site and buffer size.
    trace <- loaded[[i]]
    paste(c(paste("Outline", i), trace$site, trace$buffer_area_multiplier), collapse = " | ")
  }, character(1))
  tcltk::tkconfigure(reference_box, values = reference_labels, state = "readonly")
  tcltk::tclvalue(trace_choice) <- reference_labels[1]
  select_reference()
})

canvas_click <- function(x, y) attempt(function() {
  # Only clicks on the visible image are accepted, including after resizing.
  if (!step %in% c("crop", "draw")) return(invisible(NULL))
  click <- as.numeric(c(x, y))
  if (any(click < 0 | click >= display_size)) return(invisible(NULL))
  xy <- click * image_size / display_size
  if (step == "crop") {
    # The second corner defines the crop. Reset after a failed crop so it can be retried.
    if (nrow(corners) >= 2L) corners <<- matrix(numeric(), ncol = 2)
    corners <<- rbind(corners, xy)
    tcltk::tkdelete(canvas, "corner")
    tcltk::tkcreate(canvas, "oval", click[1] - 5, click[2] - 5, click[1] + 5, click[2] + 5,
                    fill = "#DC4A11", tags = "corner")
    tcltk::tclvalue(status) <- "First corner marked. Click the opposite corner."
    if (nrow(corners) == 2L) open_crop()
  } else {
    # Add a point and keep the outline open until the user clicks Close outline.
    points <<- rbind(points, xy)
    draw_marks()
    tcltk::tclvalue(status) <- paste(nrow(points), "vertices marked.")
  }
})

undo_point <- function() {
  # Remove only the latest point, leaving the saved reference visible.
  if (nrow(points)) points <<- points[-nrow(points), , drop = FALSE]
  draw_marks()
  tcltk::tclvalue(status) <- paste(nrow(points), "vertices marked.")
}

reset_points <- function() {
  # Start a new outline on the same panel without clearing the reference.
  points <<- matrix(numeric(), ncol = 2)
  draw_marks()
  tcltk::tclvalue(status) <- "Outline cleared. Click the first vertex."
}

# 4.2. Check the shape and save a new version ----------------------------------

close_outline <- function() attempt(function() {
  # Require a closed ring with a positive area and no self-intersection.
  if (nrow(unique(points)) < 3L) stop("Mark at least three different vertices.")
  geometry <- sf::st_sfc(sf::st_polygon(list(rbind(points, points[1, ]))))
  if (!isTRUE(sf::st_is_valid(geometry)) || as.numeric(sf::st_area(geometry)) <= 0) {
    stop("The outline crosses itself or has no area. Undo points or start over.")
  }
  set_step("review")
  draw_marks()
})

save_outline <- function() attempt(function() {
  # Convert the selected ring to full-page pixels. Keep the other JSON entries intact.
  if (step != "review") return(invisible(NULL))
  closed <- sweep(rbind(points, points[1, ]), 2, c(left, top), "+")
  revised <- traces
  record <- revised[[trace_index]]
  record$vertices <- unname(split(closed, row(closed)))
  record$pdf_page <- page
  record$pdf_file <- basename(pdf_file)
  record$pdf_md5 <- unname(tools::md5sum(pdf_file))
  record$render_dpi <- detail_dpi
  record$crop <- list(x = left, y = top, width = image_size[1], height = image_size[2])
  record$coordinate_space <- "PDF page pixels, top-left origin"
  record$status <- "Digitised in image space; geographic validation pending"
  revised[[trace_index]] <- record

  # Keep the original trace and every earlier revision.
  stem <- tools::file_path_sans_ext(basename(pdf_file))
  dir.create(polygon_dir, recursive = TRUE, showWarnings = FALSE)
  version <- 1L
  repeat {
    destination <- file.path(polygon_dir, sprintf("%s_studyArea_trace_v%02d.json", stem, version))
    if (!file.exists(destination)) break
    version <- version + 1L
  }
  jsonlite::write_json(revised, destination, auto_unbox = TRUE, pretty = TRUE, digits = 8)
  set_step("saved")
  tcltk::tclvalue(status) <- paste("Saved:", normalizePath(destination, winslash = "/"))
})

# 5. Guide the user through the four steps -------------------------------------

# Give each step its own controls so only the actions that make sense are shown.
file_controls <- tcltk::tkframe(controls)
crop_controls <- tcltk::tkframe(controls)
draw_controls <- tcltk::tkframe(controls)
review_controls <- tcltk::tkframe(controls)
saved_controls <- tcltk::tkframe(controls)

page_entry <- tcltk::tkentry(file_controls, textvariable = page_input, width = 6)
reference_box <- tcltk::ttkcombobox(draw_controls, textvariable = trace_choice, width = 22, state = "disabled")

# Put each button beside the control or action it affects.
tcltk::tkpack(tcltk::tkbutton(file_controls, text = "Choose PDF", command = choose_pdf),
              tcltk::tklabel(file_controls, textvariable = file_label),
              tcltk::tklabel(file_controls, text = "Page"), page_entry,
              tcltk::tkbutton(file_controls, text = "Open page", command = open_page), side = "left", padx = 4)
tcltk::tkpack(tcltk::tkbutton(crop_controls, text = "Change PDF or page", command = function() set_step("file")),
              side = "left", padx = 4)
tcltk::tkpack(tcltk::tkbutton(draw_controls, text = "Back to page", command = function() attempt(start_crop)),
              tcltk::tkbutton(draw_controls, text = "Load reference", command = load_reference), reference_box,
              tcltk::tkbutton(draw_controls, text = "Undo point", command = undo_point),
              tcltk::tkbutton(draw_controls, text = "Start over", command = reset_points),
              tcltk::tkbutton(draw_controls, text = "Close outline", command = close_outline), side = "left", padx = 4)
tcltk::tkpack(tcltk::tkbutton(review_controls, text = "Back to editing", command = function() {
  # Reopen the ring so the same vertices can be edited.
  set_step("draw")
  draw_marks()
}), tcltk::tkbutton(review_controls, text = "Save new version", command = save_outline), side = "left", padx = 4)
tcltk::tkpack(tcltk::tkbutton(saved_controls, text = "Trace another outline", command = function() attempt(start_crop)),
              tcltk::tkbutton(saved_controls, text = "Close", command = function() tcltk::tkdestroy(window)),
              side = "left", padx = 4)

# Show the instructions and buttons for the current step.
set_step <- function(next_step) {
  # Use one visible control bar at a time and clear the previous status message.
  step <<- next_step
  frames <- list(file = file_controls, crop = crop_controls, draw = draw_controls,
                 review = review_controls, saved = saved_controls)
  for (frame in frames) tcltk::tkpack.forget(frame)
  tcltk::tkpack(frames[[step]], anchor = "w", pady = 5)
  titles <- c(file = "Step 1 of 4 | Choose the PDF and page", crop = "Step 2 of 4 | Select the map panel",
              draw = "Step 3 of 4 | Trace the outline", review = "Step 4 of 4 | Review and save",
              saved = "Trace saved")
  guidance <- c(
    file = "Choose a PDF, enter the page containing the map and click Open page. Count from the first PDF page.",
    crop = "Click two opposite corners around the map you want to trace. Leave a little space around the boundary.",
    draw = "Click along the boundary in order. Use Undo point or Start over to correct it. Click Close outline when finished.",
    review = "Check the closed orange outline. Go back to edit it or save a new JSON version. Coordinates are PDF pixels.",
    saved = "You can close this window or trace another outline on this page."
  )
  tcltk::tclvalue(step_title) <- titles[[step]]
  tcltk::tclvalue(instructions) <- guidance[[step]]
  tcltk::tclvalue(status) <- ""
  if (step == "file") tcltk::tkdelete(canvas, "all")
}

# Start with the PDF selection and keep the workflow inside this window.
tcltk::tkbind(page_entry, "<Return>", function() open_page())
tcltk::tkbind(reference_box, "<<ComboboxSelected>>", function() select_reference())
tcltk::tkbind(canvas, "<Button-1>", canvas_click)
set_step("file")
tcltk::tkwait.window(window)



