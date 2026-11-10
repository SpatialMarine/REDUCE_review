# REDUCE full-text protocol

Use this protocol with your reviewer workbook and its `columnExplanation` tab. The AI screens each paper and immediately extracts provisional data for papers it accepts. The assigned reviewer then checks both stages and records the final human screening decision.

## 1. Full-text screening

### Scope and recording

- Confirm the workbook, reviewer code and paper IDs in scope before screening. Use the full text and any relevant supplements. Use titles, abstracts and existing classifications to guide retrieval and assessment.
- In the `dataExtraction` tab of each reviewer workbook, keep one row per assigned `paperID` during screening. Preserve the bibliographic fields, DOI links, dropdowns and both review blocks. Leave extraction fields blank during screening.
- During screening, the AI writes only `rev_AI`, `FT_decisionAI`, `FT_exclCriteria_AI` and `notes_AI`. In `rev_AI`, record the exact model identifier and reasoning effort when verifiable from the session metadata. For example, `gpt-6.1-sol (reasoning effort: low)`. If the effort is unavailable, record the verified model identifier alone. Record any proposed correction to a prefilled classification in `notes_AI` as described in section 2.
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

### Record scientific species names

- For each megafauna result, check the results text, tables, figures and relevant supplements for species linked to that row's evidence, area and gear. Enter the full scientific names as reported in `species_scientific_names`, separated by ` / `. Cite where the species are identified in `source_reference`.
- If the paper identifies species within a group but reports a combined count, weight or rate, list the identified species and keep the result at its reported level of aggregation. State in `extraction_notes` that the figures apply to the group. If the evidence identifies only a group, record that label in `taxon_as_reported` and leave `species_scientific_names` blank.

### Record AI proposals and changes to populated cells

During screening, the AI proposes corrections in `notes_AI` and leaves the prefilled value in place. Use one entry per field. Include the exact current value, the proposed value, a short explanation grounded in the full text and a source locator. The reviewer can accept, amend or decline the proposal.

In Excel, set the font colour of the entire `notes_AI` cell to **red** when the note proposes a change to at least one prefilled `*_final` classification. Use **black** when the note proposes no such change. Start each proposed change with `PROPOSED` so the disagreement is also clear in plain-text exports.

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

For every megafauna row with `species_scientific_names` blank, confirm that the available evidence identifies no species linked to the result. If a figure, table or supplement needed for that check is unavailable or unreadable, record what is missing in `extraction_notes`.

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
- When the AI saves a polygon linked to the result, it sets `polygon_studyArea` to `Yes` and records the file in `geometry_file`. It leaves `geometry_checked`, `geometry_edited` and `geometry_edited_uploaded` blank on new rows and preserves any existing values. Only the human reviewer fills these three fields when reviewing the polygon and recording any edits or upload.

### Store reviewed study-area GeoJSON

- Save the polygon and its calibration together in the same reviewer and topic folder as the trace.
- Use the shared stem `<paperID>_<PDF_stem>_Fig<NN>`, adding a panel or area identifier when needed. End the polygon filename with `_study-area.geojson` and the calibration filename with `_calibration.geojson`.
- Complete the tracer's geographic review before exporting the pair. Leave the case pending if it cannot be checked. Keep historical `_trace.json` files. For reviewed geometry, record the polygon GeoJSON path relative to the reviewer workbook in `geometry_file` and describe the source figure and what the outline represents in `source_reference`.

## 4. Workbook field dictionary

The fields below follow the order in the workbook's `columnExplanation` tab. Use `dropDown` for the exact controlled values. Leave a field blank when the information is unavailable, unverified or outside the scope of the row. Use `Not specified` or `Pending verification` only where the field offers that option and its meaning applies. Where a dropdown supports multiple choices, combine only options supported by the same result. For a valid category absent from a list, use `Other` and its companion field where available. Otherwise record the reported value in `extraction_notes` for review.

### Bibliographical data

| Field | What to enter |
| --- | --- |
| `paperID` | Preserve the assigned identifier. Use the same value on every row for the paper. |
| `authors` | Preserve the supplied author list across rows. |
| `year` | Preserve the supplied publication year. Record observation years in `data_start` and `data_end`. |
| `journal` | Preserve the supplied journal or publisher. |
| `doi` | Preserve the supplied publication DOI and its link. Leave blank if unavailable and log any proposed bibliographic correction. |
| `title` | Preserve the supplied publication title across rows. |
| `abstract` | Preserve the supplied abstract across rows. Verify eligibility against the full text. |
| `keywords` | Preserve the supplied publication keywords across rows. |
| `document_type` | Record the verified publication format consistently across rows when filling metadata. Apply the DOCUMENT eligibility criterion separately. |
| `document_type_other` | If `document_type` includes `Other`, describe the reported format. Otherwise leave blank. |
| `openAccess` | Preserve the supplied status. A locally available PDF does not establish open access. Leave unknown status blank. |

### Assignation

| Field | What to enter |
| --- | --- |
| `Topic_final` | Review the supplied paper-level topics against the full text. Keep the current value while an AI proposal is pending. Record result-specific evidence in the corresponding topic blocks. |
| `TaxaGroup_final` | Review the supplied paper-level taxon groups. Use `TaxaGroup` for the groups linked to the particular result. |
| `fishingGear_final` | Review the supplied paper-level gears. Use `fishingGear` for the gears linked to the particular result. |

### Exclusion criteria

| Field | What to enter |
| --- | --- |
| `rev_AI` | Verified model identifier and reasoning effort, as specified in section 1. |
| `FT_decisionAI` | Use `Accepted` or `Rejected` when supported. Leave blank for pending cases. AI acceptance triggers provisional extraction. |
| `FT_exclCriteria_AI` | For an AI rejection, record the first supported exclusion code in the protocol hierarchy. Leave blank for acceptance or a pending decision. |
| `notes_AI` | Give the AI rationale and source locator. Mark PDF issues and log proposed changes to prefilled classifications using section 2, including the font colour rule. |
| `rev1_name` | Preserve the assigned reviewer code. |
| `FT_decisionRev1` | The reviewer records the independent human decision. Use it for final consolidation and PRISMA counts. |
| `FT_exclCriteria_rev1` | The reviewer records the first supported exclusion code for a human rejection. Leave blank for acceptance or a pending decision. |
| `notes` | The reviewer records the rationale, unresolved questions or amendments, with a source locator when available. Keep the paper-level decision consistent across linked rows. |

### General metadata

| Field | What to enter |
| --- | --- |
| `resultID` | Use a stable ID such as `473-01` for a distinct result. Reuse it on linked rows representing that same result. A separate estimate for another area or gear gets a different ID. |
| `study_area_as_reported` | Record the geographic wording tied to the result. Include the reported sampling area or analytical unit when this helps distinguish it from the broader study extent. |
| `FAO_area` | Record `34` or `47` when the result is reported for that area or its location falls within the linked boundary. Use `34 / 47` when the same result applies to both. Leave blank while attribution is unresolved. |
| `EEZ` | Record the verified EEZ reporting unit or `International waters` when supported. A landing port or fleet nationality does not locate the catch. If a supported EEZ is absent from the list, name it in `extraction_notes`. |
| `evidence_scope` | Use `Regional evidence` for a result attributable to FAO 34 or 47. In an otherwise eligible paper, use `Global evidence only` for context that cannot be separated for the region, and keep that result out of the regional synthesis. Use `Pending verification` when attribution needs checking. |
| `polygon_studyArea` | Use `Yes` when a saved polygon can be linked to the result, and `No` when none has been created. A point, line or set of isolated cells alone does not justify drawing a continuous polygon. |
| `geometry_file` | Use a path relative to the reviewer workbook. Record the linked polygon file and update the path to the reviewed study-area GeoJSON when exported. Leave blank when there is no polygon. |
| `geometry_checked` | Human reviewer only. Record `Yes` once the check is complete or `No` if the reviewer has started the check and it remains unresolved. Leave blank before human review or when there is no polygon. |
| `geometry_edited` | Human reviewer only. After checking the polygon, record `Yes` if it was edited or `No` if it was kept as drawn. Leave blank while the check is incomplete. |
| `geometry_edited_uploaded` | Human reviewer only. If the polygon was edited, record `Yes` once the corrected file has been uploaded or `No` while upload is pending. Leave blank when there was no edit. |
| `source_reference` | Cite the page, section, figure, table or supplement supporting the row. For a polygon, say whether it represents sampled locations, an analytical extent, a regulatory boundary or an approximate envelope. A regulatory boundary alone provides geographic context for a catch result. |
| `dataLink` | Enter the dataset URL or DOI supplied by the paper. Leave blank when there is no verified dataset link. |
| `data_start` | Enter the first year covered by the evidence for the result, including for a single-year result. Leave blank if unknown. |
| `data_end` | Enter the last year covered by that evidence. Use the same year as `data_start` for a single-year result. Leave blank if unknown. |

### Fishery

| Field | What to enter |
| --- | --- |
| `fishingGear` | Record the gear used for the result. Keep gears on the same row only where they share the same evidence, area and taxa. |
| `gear_subtype` | Record the supported subtype, such as bottom trawl or drifting longline. Leave blank when the article only identifies the broad gear. |
| `gear_subtype_other` | Describe the subtype as reported when `gear_subtype` includes `Other`. |
| `fishery_context` | Record `Commercial fishery` for observations from commercial operations, including onboard observers, or `Research survey` for a scientific fishing campaign. |
| `fleetFlag` | Record the vessel flag state as reported. Separate multiple flags with ` / ` when supported for the same result. Leave blank when unknown. |
| `extraction_notes` | Record uncertainties, limits of attribution, aggregation, unavailable material and category gaps. Identify the field and supporting evidence so the reviewer can act on the note. |

### Fishing effort

For example, AIS is a data source, spatial modelling is a method and fishing time is a type of evidence. Apply the same distinction in the IUU, ghost gear and catch blocks.

| Field | What to enter |
| --- | --- |
| `effort_data_source` | Record the underlying evidence source, such as AIS or logbooks. |
| `effort_data_source_other` | Describe the source when `effort_data_source` includes `Other`. |
| `effort_dataset_name` | Record the named dataset, product or programme as reported. Leave blank if unnamed. |
| `effort_analysis_type` | Record the main analysis that produced the result. Describe ancillary methods in `extraction_notes` or use a new row for a distinct finding. |
| `effort_method_other` | Describe the method when `effort_analysis_type` includes `Other`. |
| `effort_evidence_type` | Record the kind of effort evidence produced, such as fishing time. Store the category in this field. |
| `effort_evidence_type_other` | Describe the evidence when `effort_evidence_type` includes `Other`. |

### IUU

| Field | What to enter |
| --- | --- |
| `IUU_data_source` | Record the evidence source used for the specific IUU result. |
| `IUU_data_source_other` | Describe the source when `IUU_data_source` includes `Other`. |
| `IUU_dataset_name` | Record the named source dataset or programme. Leave blank if unnamed. |
| `IUU_analysis_type` | Record the main method used to identify or estimate the result. |
| `IUU_method_other` | Describe the method when `IUU_analysis_type` includes `Other`. |
| `IUU_evidence_type` | Record what the result reports. If the study uses a proxy, describe what was measured and why the authors link it to IUU in `extraction_notes`. For instance, an AIS gap is a signal whose interpretation depends on the study's validation and attribution. |
| `IUU_type` | Assign Illegal, Unreported or Unregulated only when supported. Use `Not specified` for a qualifying proxy or combined result that does not establish which category applies. Use separate rows for distinct category-specific results. |

### Ghost gear

| Field | What to enter |
| --- | --- |
| `ghost_data_source` | Record where the ghost gear evidence comes from, for example retrieval records or survey observations, using the controlled list. |
| `ghost_data_source_other` | Describe the source when `ghost_data_source` includes `Other`. |
| `ghost_dataset_name` | Record the named dataset or monitoring programme. Leave blank if unnamed. |
| `ghost_analysis_type` | Record the main method that produced the result. |
| `ghost_method_other` | Describe the method when `ghost_analysis_type` includes `Other`. |
| `ghost_evidence_type` | Record what the study reports about lost, abandoned or discarded gear. Keep different results separate when their sources, areas or units differ. |
| `ghost_evidence_type_other` | Describe the evidence when `ghost_evidence_type` includes `Other`. |
| `gear_item` | Record the object observed, lost or recovered. Record the originating fishing gear separately in `fishingGear` when attributable. Use `Not specified` if the item is unidentified. |
| `gear_item_other` | Describe the item when `gear_item` includes `Other`. |

### Marine megafauna

| Field | What to enter |
| --- | --- |
| `catch_data_source` | Record the source underlying the catch result, such as observers, landings records or logbooks. |
| `catch_data_source_other` | Describe the source when `catch_data_source` includes `Other`. |
| `catch_dataset_name` | Record the named dataset, survey or programme. Leave blank if unnamed. |
| `catch_analysis_type` | Record the main analysis, such as a catch rate calculation or mortality estimation. |
| `catch_method_other` | Describe the method when `catch_analysis_type` includes `Other`. |
| `catch_evidence_type` | Record the reported evidence category. In `extraction_notes`, distinguish retained catch, discards, total catch estimates, at-haulback mortality and post-release mortality where relevant. For rates, identify the numerator and effort denominator. |
| `TaxaGroup` | Record the eligible taxon groups supported for this result. Split rows when the evidence, area or gear differs by group. |
| `species_scientific_names` | Record the full names of species linked to the result as reported, separated by ` / `. Include identified species when figures are reported for a group and document that aggregation as described in section 2. |
| `taxon_as_reported` | Record common names or the original taxonomic or commercial group label. Preserve the reporting level when identification stops above species. |

### Additional fishery information

| Field | What to enter |
| --- | --- |
| `targetSpecies_metier` | Record the reported target species or métier for the fishery associated with the result. Separate supported entries with ` / `. Leave blank if the paper provides neither. |

### Template wording to reconcile

- The workbook guidance for `FT_decisionRev1` says to extract only from accepted papers. Section 2 defines when AI extraction starts and how human acceptance governs final inclusion. The workbook guidance should name both stages explicitly.
- The workbook guidance for `rev_AI` asks for the model name and version. Section 1 also records the verified reasoning effort when available.
- The workbook guidance for `species_scientific_names` should clarify that identified species can be listed when the corresponding result is reported at group level.
- The workbook guidance for `geometry_checked`, `geometry_edited` and `geometry_edited_uploaded` should state that only the human reviewer fills these fields and that they stay blank before human review.
