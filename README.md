# A systematic review of marine megafauna distribution and fisheries interaction in west Africa  - R Code

Also available for referencing in Zenodo  
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.14847311.svg)](https://doi.org/10.5281/zenodo.14847311)


This repository provides the R code used in the following research paper:

Author
<a href="https://orcid.org/0000-0002-0072-1233">
  <img src="https://cdn.simpleicons.org/orcid/A6CE39" width="21"/>
</a>,
Author
<a href="https://orcid.org/0000-0002-0072-1233">
  <img src="https://cdn.simpleicons.org/orcid/A6CE39" width="21"/>
</a>,
... and Author
<a href="https://orcid.org/0000-0002-0072-1233">
  <img src="https://cdn.simpleicons.org/orcid/A6CE39" width="21"/>
</a>. 
Title...

------------------------------------------------------------------------

### Repository structure

| Folder | Description |
|----|----|
| *fun* | custom functions used into different scripts in `src` folder |
| *src* |  Source R scripts for data processing, statistical analysis, and visualization. |

### Abstract-screening adjudication

`src/05_summariseAbstractScreening.R` uses a separate workbook for manual
adjudication so reviewer decisions are never overwritten by generated output:

1. If `output/abstract_screening_reviewer3.xlsx` does not exist, the script
   creates it as a reviewer 3 template.
2. Complete the `reviewer_3` columns in its `final_screening` worksheet.
3. Rerun the script. Reviewer 3 values resolve disagreements and the adjudicated
   dataset is written to
   `output/abstract_screening/abstract_screening_final.xlsx`.

The reviewer 3 workbook is treated as a manual input and is not overwritten on
subsequent runs.

For an additional review of an otherwise complete paper, set the optional
`apply_reviewer3` column to `TRUE` in the manual workbook's `final_screening`
sheet. This explicitly applies Reviewer 3 even without an initial disagreement.
Leave it blank or `FALSE` to retain the previous rules; a valid single-reviewer
paper does not automatically require adjudication. Do not edit the generated
`requires_adjudication` indicator to activate a review.

See [the detailed Reviewer 3 guide](guides/reviewer3_additional_reviews.md) for
the input/output workflow, field precedence, tests, and an explanation of every
changed executable line in the screening script.

After adjudication, `src/06_prepareFullTextScreening.R` reads the generated
`abstract_screening_final.xlsx`, standardises the final categories, creates one
bar plot per screening variable, and exports:

- one workbook containing all accepted papers; and
- one workbook per standardised topic for full-text assignment.

These files are saved under `output/full_text_screening/`. Accepted papers with
no topic are written to `output/abstract_screening_topic_assignments.xlsx` for
manual classification. Complete `Topic_assignment` and, where relevant,
`TaxaGroup_assignment` and `fishingGear_assignment`, then rerun the script. The
file is treated as a manual input and is never overwritten.

Taxonomic-group summaries include only accepted papers classified under
`Megafauna catch`.

The gold-paper DOI lists defined in `src/02_Handling_RIS.R` are exported to
`input/rm_duplicates/goldPapers.xlsx`. Script 06 compares them with the final
screening decisions and writes a gold-paper audit and outcome plot under
`output/full_text_screening/`, warning if any gold paper was rejected or absent.

Manual correction workbooks are cumulative. On each run, the script appends
newly detected Paper IDs without deleting or replacing existing user-entered
values:

- `output/abstract_screening_topic_assignments.xlsx`
- `output/abstract_screening_taxa_assignments.xlsx`
- `output/abstract_screening_fishingGear_assignments.xlsx`
- `output/abstract_screening_exclusion_assignments.xlsx`

All generated plots are explicitly printed when the script is sourced in
RStudio as well as being saved to disk.

### Meeting figures and reviewer feedback

After script 05, run `src/07_screeningFeedback.R` with the project setup loaded.
It reads the final abstract-screening workbook and generates meeting figures,
one feedback workbook per initial reviewer, and a summary workbook under
`output/abstract_screening/feedback_screening/`. It does not modify screening
inputs or send feedback to reviewers. See the [feedback guide](guides/screening_feedback.md)
for counting rules, denominators, missing-field applicability and limitations.

### Study area tracer

[Open Study Area Tracer](https://spatialmarine.github.io/REDUCE_review/study-area-tracer/) to draw or revise a study-area outline from a PDF map. Select a page, crop the map, and trace the boundary or load a saved outline to edit it. The tool runs in your browser. PDFs and trace files stay on your device.

To run it locally on Windows, double-click `docs/study-area-tracer/start-local.cmd`. On other platforms, run `python3 docs/study-area-tracer/serve.py` from the repository root. Keep the launcher window open and use the browser tab at the printed `http://127.0.0.1` address. Opening `index.html` directly from disk prevents the browser from loading the modules that open PDFs.

1. Choose a PDF and open the page containing the map.
2. Click two opposite corners to select a panel. Use **Zoom** to inspect the crop.
3. Click along the boundary, or use **Load reference JSON or GeoJSON** and **Edit this outline** to revise a saved trace. You can move, add, delete or undo vertices.
4. Click **Close outline**. Use **Download editable JSON draft** to save an outline in PDF page pixels. To georeference it, mark at least three well-distributed **Fit** points and at least one distinct **Check** point, or load a calibration file. Review the errors and extrapolation.
5. Enter the reviewer name or ID and complete the checklist. If the outline extends outside the Fit boundary, record which part you checked and what reference supports its location. Both downloads unlock together. The calibration GeoJSON contains the control points and the study-area GeoJSON contains the polygon.
6. Open either file in QGIS. To edit it in the tracer, reopen the study-area file as a reference in step 3 or load the calibration file in step 4. Both files retain their review details. Reopening or changing the outline or controls requires a fresh confirmation before export.

When filing reviewed GeoJSON exports, give both files the shared `<paperID>_<PDF_stem>_Fig<NN>` stem and keep their `_study-area.geojson` and `_calibration.geojson` suffixes. See [the storage protocol](AGENTS.md#store-reviewed-study-area-geojson) for the reviewer folder and workbook fields.

PDFs, traces and calibrations are processed in the browser. The preview compares the loaded calibration with the current fit. It uses geographic degrees and has no reference basemap. Compare the exported layers with independent references before using them in the coverage analysis.

The tool bundles PDF.js 6.5.438 under its [Apache 2.0 licence](docs/study-area-tracer/vendor/LICENSE).


### Data availability

See Data availability statement in the published article

### License

Copyright (c) 2026. David Ruiz-García, Leia Navarro-Herrero, Jazel Ouled-Cheikh, Paola Gabasa, Ignacio Saint-Malo, Alejandro Espada-Pastor, Diego Fernández-Fernández, David March (not in order of publication or anything atm)

@davidruizgarci
<a href="https://github.com/davidruizgarci">
  <img src="https://cdn.simpleicons.org/github/ffffff" width="22"/>
</a><a href="https://www.researchgate.net/profile/David-Ruiz-Garcia-3">
  <img src="https://cdn.simpleicons.org/researchgate/00CCBB" width="22"/>
</a>

@author ADD YOUR DETAILS
<a href="https://github.com/davidruizgarci">
  <img src="https://cdn.simpleicons.org/github/ffffff" width="22"/>
</a><a href="https://www.researchgate.net/profile/David-Ruiz-Garcia-3">
  <img src="https://cdn.simpleicons.org/researchgate/00CCBB" width="22"/>
</a>

Licensed under the [MIT License](https://github.com/SpatialMarine/REDUCE_review/blob/main/LICENSE)

### Acknowledgements

The study was supported by the EU Horizon REDUCE project...
