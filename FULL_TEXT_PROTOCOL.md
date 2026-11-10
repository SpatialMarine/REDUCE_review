# REDUCE full-text protocol

Use this protocol with your reviewer workbook and its `columnExplanation` tab. The AI screens each paper and immediately extracts provisional data for papers it accepts. The assigned reviewer then checks both stages and records the final human screening decision.

## 1. Full-text screening

### Scope and recording

- Confirm the workbook, reviewer code and paper IDs in scope before screening. Use the full text and any relevant supplements. Use titles, abstracts and existing classifications to guide retrieval and assessment.
- In the `dataExtraction` tab of each reviewer workbook, keep one row per assigned `paperID` during screening. Preserve the bibliographic fields, DOI links, dropdowns and both review blocks. Leave extraction fields blank during screening.
- The AI writes only `rev_AI`, `FT_decisionAI`, `FT_exclCriteria_AI` and `notes_AI`. Record the model actually used in `rev_AI`. If its exact identifier is unavailable, record only the model information that can be verified. Record any proposed correction to a prefilled classification in `notes_AI` as described in section 2.
- The human reviewer reads the AI assessment and records their own decision in `FT_decisionRev1`, even when it agrees with the AI. Preserve the prefilled code in `rev1_name`. Use `FT_exclCriteria_rev1` and `notes` for the human rationale. Human decisions are used for consolidation and PRISMA counts. Keep both human assessments for double-assigned articles and document AI assistance in the methodology.
- Select `Accepted` or `Rejected` from the decision dropdown. For a rejection, select exactly one exclusion code from the corresponding dropdown. Leave the exclusion code blank for accepted or pending articles. In the applicable notes column, give a short, article-specific rationale in English, citing the page, section, table, figure or supplement when available.
- If the full text has not been retrieved or an unresolved question could change the decision, leave the decision and criterion blank. Record the retrieval issue or the specific evidence still needed in the applicable notes column. Use the PDF checks in section 3 even when a file is present.

### Apply the criteria in order

Apply **LANGUAGE → DOCUMENT → NOTOPIC → LOCATION → GEAR → TAXA → STUDY_TYPE**. For a rejected article, record the first applicable exclusion code in this hierarchy. If uncertainty about an earlier criterion could change the recorded code, flag the article for review. Consider all eligible topic pathways before rejecting a paper. The topic, location, gear and taxa used to justify inclusion must refer to the same qualifying evidence.

1. **LANGUAGE.** The full text must be in English. An English title or abstract alone is insufficient.
2. **DOCUMENT.** Eligible formats are journal articles, reports and book chapters. Exclude presentations, editorial material, letters, news items, conference or meeting abstracts, posters, dissertations and theses.
3. **NOTOPIC.** The study must directly quantify, describe, map, estimate or analyse an eligible topic. Check the methods and results, including relevant secondary results for megafauna catch.
   - **Fishing effort.** One of the study's primary objectives must be to quantify, describe, map, estimate, analyse or compare effort. Developing or reanalysing datasets such as Global Fishing Watch qualifies when the study reports effort metrics or patterns. Using effort solely as an explanatory variable is insufficient unless another topic qualifies.
   - **IUU fishing.** The study must directly address illegal, unreported or unregulated fishing. A mention in the background or discussion is insufficient.
   - **Ghost gear.** The study must directly address abandoned, lost or otherwise discarded fishing gear (ALDFG).
   - **Megafauna catch.** Include evidence of observed captures or estimates based on capture data. Spatial overlap, vessel attendance and other behavioural interactions alone are insufficient. When bycaught animals are used to study diet, genetics, parasites, taxonomy or another topic, check for eligible capture or bycatch rates. Those rates can qualify even when bycatch is a secondary objective. The use of bycaught specimens alone is insufficient. Apply the separate TAXA criterion to studies that otherwise address capture.
4. **LOCATION.** The study area consists of the complete FAO Major Fishing Areas **34 and 47**, including their international waters. Use the [FAO 34 and 47 boundary layer](spatial/FAO_34_47.geojson), which contains the two complete areas selected by `F_CODE` from `input/enviro/FAO_Areas/FAO_Major_Fishing_Areas.shp` and exported in WGS 84. Check reported FAO codes, coordinates or georeferenced figures against these boundaries as appropriate. For global or multi-region studies, require a case study, observations or identifiable results attributable to at least one of the two areas. A passing mention or a map that overlaps the areas without attributable evidence is insufficient. If uncertainty about the location could change the decision, leave it pending and identify the evidence needed.
5. **GEAR.** Eligible gears are industrial purse seine, longline and trawl. Commercial-vessel studies and research-vessel surveys using eligible gear can qualify. Exclude artisanal and small-scale fisheries. For mixed-gear studies, check that qualifying evidence can be attributed to an eligible gear.
6. **TAXA.** Applies only to the megafauna catch pathway. Eligible groups are marine mammals, sea turtles, seabirds and chondrichthyans. A paper can still qualify through fishing effort, IUU fishing or ghost gear.
7. **STUDY_TYPE.** Exclude non-empirical literature reviews, conceptual or perspective papers, protocol reviews and methods-only papers without an eligible empirical application. Meta-analyses can qualify if they meet the remaining criteria. A methods paper can qualify if it tests the method on an eligible case in the study area.

### Check before saving the screening
Confirm that each rejection uses the first supported code, each acceptance has a blank exclusion code and unresolved cases remain distinguishable in the notes. Check that only the approved review fields and paper IDs were edited. Report accepted, rejected and pending counts and list unresolved paper IDs.

## 2. Full-text data extraction

### Extract immediately after AI screening

- If `FT_decisionAI` is `Accepted`, extract supported results in the same pass and treat them as provisional until the assigned reviewer checks them. If the AI decision is `Rejected` or pending, leave new extraction fields blank.
- The assigned reviewer checks both the screening and the extraction, records their independent decision and revises the extracted data as needed. If the reviewer accepts a paper the AI rejected or left pending, complete its extraction. If the reviewer rejects a paper with provisional extraction, exclude those results from consolidation and retain the review trail.
- In a fresh batch, expect the result-level extraction fields to be empty. Preserve supplied bibliography and metadata marked `(given to you)` in `columnExplanation`, plus the prefilled `*_final` classifications and `rev1_name`. Treat any other populated cell as existing work. Enter supported data in blank fields and preserve existing values unless a correction is authorised and logged.
- Review the prefilled `Topic_final`, `TaxaGroup_final` and `fishingGear_final` against the full text. These are classifications for the paper. Use the extraction fields, such as `fishingGear` and `TaxaGroup`, for the evidence linked to a particular result.
- Follow `columnExplanation` for each field and `dropDown` for the controlled categories. In fields marked `Dropdown / list`, choose each supported option in the same cell in desktop Excel with macros enabled. The workbook joins the options with ` / `, for example `34 / 47`. Keep the rationale in the notes or change log described below.

### Decide when a result needs more than one row

- Keep the same `paperID` on all rows for the publication. Assign a `resultID` such as `473-01` to each distinct result and reuse it on linked rows describing that same result.
- Use one row when the listed areas, gears and taxa share the same evidence. Add a row if the paper reports a distinct result or if combining values would imply a link the paper does not support. For example, if one estimate is for longline in FAO 34 and another is for trawl in FAO 47, record two rows.
- Record the reported study area and cite the page, figure, table, section or supplement in `source_reference`. Enter FAO areas, EEZs and geometry only when supported at the level of the result. Record uncertainties in `extraction_notes` and leave unsupported values blank.

### Record AI proposals and changes to populated cells

During screening, the AI proposes corrections in `notes_AI` and leaves the prefilled value in place. Use one entry per field. Include the exact current value, the proposed value, a short explanation grounded in the full text and a source locator. The reviewer can accept, amend or decline the proposal.

> Illustrative example — PROPOSED | `Topic_final` | `Fishing effort / Megafauna catch` → `Megafauna catch` | Fishing effort is used as a covariate. The paper reports bycatch estimates as an outcome. | Methods, p. 4 and Results, Table 2.

During extraction, keep one entry per proposed or applied correction in a separate reviewer change log alongside the workbook. Record proposals as a batch and give the reviewer the workbook and log together. Continue filling eligible blank fields while populated-cell proposals are pending. Use the following fields.

| Field | What to record |
| --- | --- |
| Workbook and reviewer | Reviewer workbook name and reviewer code |
| Record | `paperID` and `resultID` when the correction concerns an extraction result |
| Field | Exact column header |
| Previous value | Exact content before the edit, including every selected option |
| Proposed value | Complete replacement value, including retained options. Use `[blank]` for a proposed clearing. |
| Reason and evidence | What the paper supports and where to verify it |
| Proposal author and date | Who made the proposal and when |
| Status, reviewer and date | `Proposed`, `Applied` or `Declined`. For a resolved proposal, record who resolved it and when. |
| Applied value | Exact saved value if applied, including any adjustment by the reviewer |

Apply an AI correction to a populated cell only after the reviewer accepts it or explicitly authorises the AI to apply corrections within that scope. The reviewer can approve the whole batch or a specified subset in one step. Record the previous value before writing and confirm the applied value afterward. If the cell changed since the proposal, preserve the current value and flag the conflict in the batch log for the reviewer. Keep any intervening reviewer edit and its rationale traceable.

A `*_final` classification applies to the paper. When it changes, check all affected rows for that `paperID` and identify those updated in the log. The classification cells hold dropdown values, and the log holds the explanation. Keep the reviewer decision fields under the reviewer's control.

### Check before saving the extraction

Confirm that each provisional result belongs to a paper accepted by the AI or the human reviewer, its area, gear and taxa refer to the same evidence, and the source locator lets another reviewer verify it. Use human-accepted records for final consolidation. Reconcile every applied AI correction with its saved cell value and leave unresolved proposals visible for the reviewer.

## 3. Store PDFs and study-area geometries

### Find and check the PDF before archiving

- Look first in `output/full_text_screening/by_reviewer/Papers/<reviewer_code>/<topic>/` for already organised copies. For papers still being organised, check the project's `input/Papers/` folder and any shared upload folder or Zotero collection specified for the batch. Verify the match against the DOI, title and authors. Record the actual source path in the batch tracker so the reviewer can reopen the same file.
- Check that the file opens and contains the article rather than a title page, abstract or preview alone. Check the page sequence and readable content against the article version, including Methods, Results and any cited figures, tables or supplements needed for eligibility or extraction. Flag missing or truncated pages, unreadable material, a mismatched article or a missing required supplement. A scan with readable pages can be reviewed visually even if text extraction fails. Judge reports and chapters against their own structure.
- In the batch tracker, use `Missing` when no file was found, `Needs PDF check` when a file is present but there is a suspected problem, and `Usable` when the material needed for the review is available. In `notes_AI`, record the problem, its location and the action requested. For example, `PDF CHECK | file.pdf | PDF pages 5–7 appear absent and Figure 2 is missing | retrieve the complete version and verify whether the figure locates the fishing effort in FAO 34.`
- If missing or unreadable material could change eligibility, leave `FT_decisionAI` and `FT_exclCriteria_AI` blank and flag the paper for the reviewer. If eligibility is clear but an extraction item cannot be verified, extract only supported results and record the missing item in `extraction_notes`. Keep the PDF flag visible until the reviewer has checked the replacement or confirmed that the available version is sufficient.

### Store full-text PDFs and study-area polygons

- Use the reviewer acronyms defined in `src/09_prepareFullTextReviewerFiles.R`. Within `output/full_text_screening/by_reviewer`, store PDFs in `Papers/<reviewer_code>/<topic>/` and polygon traces in `Polygons/<reviewer_code>/<topic>/`. Use the topic folder names `IUU`, `Megafauna catch`, `Fishing effort` and `Ghost gear`.
- Name each PDF `FirstAuthor_JournalAbbrev_Year.pdf`. Use the first author's surname, the abbreviated journal name and the publication year. For reports, use the publisher or series abbreviation in place of the journal. Keep the source PDF in its original location and copy it to the assigned reviewer and topic folder with the standard name. If a paper is extracted for more than one topic, place a copy in each applicable topic folder.
- Name each editable polygon trace `<paperID>_<PDF_stem>_Fig<NN>_trace.json`. For example, `1560_Fernandez_JNorthwAtlFishSci_2005_Fig01_trace.json` matches `Fernandez_JNorthwAtlFishSci_2005.pdf`. If a figure contains several outlines, add a panel or area identifier to distinguish them.
- For a paper assigned to two reviewers, place a copy of the PDF in each reviewer's folder and keep their polygon files separate. Store each polygon in the topic folder for the result it represents. Keep the PDF filename recorded in each trace consistent with the PDF the reviewer opens in the web tool.
- In `geometry_file`, record the path relative to the reviewer workbook, for example `Polygons/DRG/Megafauna catch/1560_Fernandez_JNorthwAtlFishSci_2005_Fig01_trace.json`. Record the figure or page and what the outline represents in `source_reference`. Flag approximate outlines and state what was used to draw them.
- Once the trace has been saved, set `polygon_studyArea` to `Yes` and `geometry_checked` to `No` until the reviewer checks it in the web tool. After checking, the reviewer records whether they edited the trace and, if they did, whether they uploaded the edited file.

### Store reviewed study-area GeoJSON

- Save the polygon and its calibration together in the same reviewer and topic folder as the trace.
- Use the shared stem `<paperID>_<PDF_stem>_Fig<NN>`, adding a panel or area identifier when needed. End the polygon filename with `_study-area.geojson` and the calibration filename with `_calibration.geojson`.
- Complete the tracer's geographic review before exporting the pair. Leave the case pending if it cannot be checked. Keep historical `_trace.json` files. For reviewed geometry, record the polygon GeoJSON path relative to the reviewer workbook in `geometry_file` and describe the source figure and what the outline represents in `source_reference`.
