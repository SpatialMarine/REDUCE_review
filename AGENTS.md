# Full-text study-area files

- For each reviewed study area, save the polygon and its calibration together in `output/full_text_screening/by_reviewer/Polygons/<reviewer_code>/<topic>/`. Use the reviewer codes defined in `src/09_prepareFullTextReviewerFiles.R` and the assigned topic folder (`IUU`, `Megafauna catch`, `Fishing effort` or `Ghost gear`). Keep different reviewers' files separate.
- Use the shared stem `<paperID>_<PDF_stem>_Fig<NN>`, adding a panel or area identifier when needed. End the polygon filename with `_study-area.geojson` and the calibration filename with `_calibration.geojson`.
- Complete the tracer's geographic review before exporting the pair. Leave the case pending if it cannot be checked. Keep historical `_trace.json` files. For reviewed geometry, record the polygon GeoJSON path relative to the reviewer workbook in `geometry_file` and describe the source figure and what the outline represents in `source_reference`.
