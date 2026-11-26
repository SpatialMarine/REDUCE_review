# REDUCE full-text protocol

Use this protocol with your reviewer workbook and its `columnExplanation` tab. The AI screens each paper and immediately extracts provisional data for papers it accepts. The assigned reviewer then checks both stages and records the final human screening decision.

## 1. Full-text screening

### Scope and recording

- Confirm the workbook, reviewer code and paper IDs in scope before screening. Use the full text and any relevant supplements. Use titles, abstracts and existing classifications to guide retrieval and assessment.
- In the `dataExtraction` tab of each reviewer workbook, keep one row per assigned `paperID` during screening. Preserve the bibliographic fields, DOI links, dropdowns and both review blocks. Leave extraction fields blank during screening.
- During screening, the AI writes only `rev_AI`, `FT_decisionAI`, `FT_exclCriteria_AI` and `notes_AI`. Record any proposed correction to a prefilled classification in `notes_AI` as described in section 2. Follow the model-identification requirements below for `rev_AI`.

### Identify the AI model and reasoning level in `rev_AI`

- Record the **full verified model identifier, including its version and variant, and the reasoning effort used for the assessment**. A family label such as `GPT-6` alone does not establish whether the model was, for example, GPT-6.1 Sol or another variant, and does not identify its reasoning level.
- Use the format `<exact model identifier> (reasoning effort: <verified level>)`. For example, `gpt-6.1-sol (reasoning effort: low)` explicitly identifies GPT-6.1 Sol with low/light reasoning. This is an illustration, not a claim about the model running any particular session. Preserve the exact machine-readable level exposed by the session rather than replacing it with an informal translation.
- Verify the model and effort against metadata for the actual assessment session or an explicitly confirmed model-and-reasoning selection for that assessment. Do not infer them from response quality, response time, the availability of a model in a catalogue, or application defaults. A list of available models does not identify the active model.
- If the exact model is verified but the reasoning level is not exposed, record `<exact model identifier> (reasoning effort: not exposed in session metadata)`. If only the family is verified, make the limitation explicit, for example: `GPT-6 (exact model variant: not exposed; reasoning effort: not exposed in session metadata)`. Do not silently present `GPT-6` alone as complete identification and do not invent a more specific variant or level.
- Identify the model that actually performed the screening and extraction. A later model that only reformats or reorganises rows must not replace that attribution with its own identity. If different models assess different results, retain result-specific attribution and document their roles in the reviewer change log. Record a later reassessment and its model separately in that log.
- Treat any proposed refinement of an already populated `rev_AI` cell as a correction under section 2: retain the previous value, identify the verification source and date in the change log, and apply it only within the authorised correction scope. All AI-authored additions or changes remain red.

### Record screening decisions
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
- **Topic assignment does not limit extraction to the original topic.** Complete the common metadata and fishery fields, then every topic block supported by an eligible result. If the full-text assessment adds a topic or changes the original topic, complete and retain the extraction in the corresponding topic columns, including when the classification change is still a proposal awaiting reviewer approval. For example, a paper originally assigned to IUU that also directly analyses eligible fishing effort must retain both its IUU and fishing-effort extraction. Do not remove supported extraction merely to match the original assignment. Use separate result rows when the evidence, area, gear or result differs, as specified below.
- **Display all AI work in red in the reviewer workbook.** Set the font colour to red for every cell the AI fills or changes, including screening fields, extraction fields, applied classification changes and all populated cells in AI-created result rows. Preserve the formatting and content of existing cells the AI has not changed. Red identifies AI authorship, including supported extraction without a classification proposal; it is not limited to disagreements or proposals. The human reviewer controls their own review fields and may change the colour after checking the work.
- The assigned reviewer checks both the screening and the extraction, records their independent decision and revises the extracted data as needed. If the reviewer accepts a paper the AI rejected or left pending, complete its extraction. If the reviewer rejects a paper with provisional extraction, exclude those results from consolidation and retain the review trail.
- In a fresh batch, expect the result-level extraction fields to be empty. Preserve supplied bibliography and metadata marked `(given to you)` in `columnExplanation`, plus the prefilled `*_final` classifications and `rev1_name`. Treat any other populated cell as existing work. Enter supported data in blank fields and preserve existing values unless a correction is authorised and logged.
- Review the prefilled `Topic_final`, `TaxaGroup_final` and `fishingGear_final` against the full text. These are classifications for the paper. Use the extraction fields, such as `fishingGear` and `TaxaGroup`, for the evidence linked to a particular result.
- Follow `columnExplanation` for each field and `dropDown` for the controlled categories. In fields marked `Dropdown / list`, choose each supported option in the same cell in desktop Excel with macros enabled. The workbook joins the options with ` / `, for example `34 / 47`. Keep the rationale in the notes or change log described below.

### Decide when a result needs more than one row

- Keep the same `paperID` on all rows for the publication. Assign a `resultID` such as `473-01` to each distinct result and reuse it on linked rows describing that same result.
- Use one row when the listed areas, gears and taxa share the same evidence. Add a row if the paper reports a distinct result or if combining values would imply a link the paper does not support. For example, if one estimate is for longline in FAO 34 and another is for trawl in FAO 47, record two rows.
- **Keep each paper's rows together.** Insert each additional result immediately below the original row or the last existing result row for that `paperID`, shifting the following papers down. Preserve the original order of papers and the existing order and stable `resultID` values within each paper. Do not append extra results at the bottom of the worksheet away from their original paper.
- **Do not leave blank gaps in the article table.** When removing, replacing or restoring an AI-created result row, reuse its position or remove the entire unused row and shift the following rows up. Clearing cells or deleting an XML row element without updating subsequent row positions is not sufficient. Never remove a row containing existing reviewer data merely to close a gap.
- Record the reported study area and cite the page, figure, table, section or supplement in `source_reference`. Enter FAO areas, EEZs and geometry only when supported at the level of the result. Record uncertainties in `extraction_notes` and leave unsupported values blank.

### Describe the study area to guide polygon delineation

For each extracted result, write `study_area_as_reported` as a single paragraph in English. Combine the paper’s text, maps, captions and legends to describe the area linked to that result and explain how its polygon should be delineated.

- Identify the region, relevant geographic features and fishing activity.
- Include reported latitude, longitude, depth ranges and other limits relevant to delineation. Clearly identify approximate limits inferred from a figure.
- Explain which mapped features guide the polygon and which side of each boundary applies. For example, specify that fishing grounds lie offshore of a coastal exclusion line.
- State what the polygon represents, such as observed fishing grounds, a sampling footprint, a prediction domain or an approximate study extent.
- Where a mapped regulation or boundary guides delineation, check its applicability to the extracted evidence and state any relevant temporal mismatch or uncertainty.
- Identify boundaries that require interpretation, extrapolation or manual closure. Do not use the map frame, an EEZ boundary or a bathymetric contour as the study boundary without supporting evidence.

Include the relevant figure, page or section in the paragraph. Distinguish evidence reported by the authors from proposed delineation choices. Record the detailed construction method and unresolved limitations in `extraction_notes`, and retain the supporting source locators in `source_reference`. If a polygon cannot be supported, describe the available spatial evidence and state what is missing.

Describe the paper's supported study area in `study_area_as_reported`. When relevant, explain which mapped observations or boundaries guide delineation. Record the subsequent FAO 34/47 clipping and the resulting regional coverage in `extraction_notes`, following section 3.

### Record scientific species names

- For each megafauna result, check the results text, tables, figures and relevant supplements for species linked to that row's evidence, area and gear. Enter the full scientific names as reported in `species_scientific_names`, separated by ` / `. Cite where the species are identified in `source_reference`.
- If the paper identifies species within a group but reports a combined count, weight or rate, list the identified species and keep the result at its reported level of aggregation. State in `extraction_notes` that the figures apply to the group. If the evidence identifies only a group, record that label in `taxon_as_reported` and leave `species_scientific_names` blank.

### Record AI proposals and changes to populated cells

During screening, the AI proposes corrections in `notes_AI` and leaves the prefilled value in place. Use one entry per field. Include the exact current value, the proposed value, a short explanation grounded in the full text and a source locator. The reviewer can accept, amend or decline the proposal.

In Excel, set the font colour of the entire `notes_AI` cell to **red**, whether or not it proposes a classification change, following the rule that all AI work is red. Start each proposed change with `PROPOSED` so the disagreement is also clear in plain-text exports. Keep prefilled classification values in place until an authorised correction is applied, but do not delay or remove supported extraction in an added or changed topic's columns while the classification proposal is pending.

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

Before every save and again after reopening the saved workbook, verify that all rows for each `paperID` form one contiguous block, there are no entirely blank rows between the first and last article, and the number of distinct papers and the set of `resultID` values are unchanged by row reorganisation. Confirm that row movements preserve cell values, formulas, red AI formatting, human review fields, validations, macros and any row-linked objects or references. Resolve rows by `paperID` and `resultID` after each insertion or deletion rather than reusing stale row numbers.

For every megafauna row with `species_scientific_names` blank, confirm that the available evidence identifies no species linked to the result. If a figure, table or supplement needed for that check is unavailable or unreadable, record what is missing in `extraction_notes`.

## 3. Store PDFs and study-area geometries

### Find and check the PDF before archiving

- Look first in `output/full_text_screening/by_reviewer/Papers/<reviewer_code>/<topic>/` for already organised copies. For papers still being organised, check the project's `input/Papers/` folder and any shared upload folder or Zotero collection specified for the batch. Verify the match against the DOI, title and authors. Record the actual source path in the batch tracker so the reviewer can reopen the same file.
- Check that the file opens and contains the article rather than a title page, abstract or preview alone. Check the page sequence and readable content against the article version, including Methods, Results and any cited figures, tables or supplements needed for eligibility or extraction. Flag missing or truncated pages, unreadable material, a mismatched article or a missing required supplement. A scan with readable pages can be reviewed visually even if text extraction fails. Judge reports and chapters against their own structure.
- In the batch tracker, use `Missing` when no file was found, `Needs PDF check` when a file is present but there is a suspected problem, and `Usable` when the material needed for the review is available. In `notes_AI`, record the problem, its location and the action requested. For example, `PDF CHECK | file.pdf | PDF pages 5–7 appear absent and Figure 2 is missing | retrieve the complete version and verify whether the figure locates the fishing effort in FAO 34.`
- If missing or unreadable material could change eligibility, leave `FT_decisionAI` and `FT_exclCriteria_AI` blank and flag the paper for the reviewer. If eligibility is clear but an extraction item cannot be verified, extract only supported results and record the missing item in `extraction_notes`. Keep the PDF flag visible until the reviewer has checked the replacement or confirmed that the available version is sufficient.

### Store full-text PDFs and study-area polygons

- Use the reviewer acronyms defined in `src/09_prepareFullTextReviewerFiles.R`. Within `output/full_text_screening/by_reviewer`, store PDFs in `Papers/<reviewer_code>/<topic>/` and the paired study-area and calibration GeoJSON files in `Polygons/<reviewer_code>/<topic>/`. Use the topic folder names `IUU`, `Megafauna catch`, `Fishing effort` and `Ghost gear`.
- Name each PDF `FirstAuthor_JournalAbbrev_Year.pdf`. Use the first author's surname, the abbreviated journal name and the publication year. For reports, use the publisher or series abbreviation in place of the journal. Keep the source PDF in its original location and copy it to the assigned reviewer and topic folder with the standard name. If a paper is extracted for more than one topic, place a copy in each applicable topic folder.
- **The required deliverable is two `.geojson` files: the geographically calibrated study-area polygon and its calibration controls.** An image-space `_trace.json` file alone is an intermediate draft, not a completed polygon deliverable. Changing a `.json` extension to `.geojson` or assigning a CRS label to pixel coordinates does not perform calibration.
- For a paper assigned to two reviewers, place a copy of the PDF in each reviewer's folder and keep their geometry pairs separate. Store each pair in the topic folder for the result it represents. Keep the PDF filename and fingerprint recorded in both exports consistent with the exact PDF the reviewer will reopen in the web tool.

### Delineate the evidence footprint and restrict it to the review area

Use the most spatially specific evidence available for the extracted result. First reconstruct the supported footprint, then apply the statistical-scope and land-exclusion procedure below.

- Where the paper explicitly defines the relevant boundary, reproduce it using the text, map, caption and legend together.
- Where observations or fishing effort are mapped in occupied grid cells, reconstruct and merge those cells. Preserve gaps and disconnected areas. Use a reported bounding rectangle only when it represents the intended analytical domain or when more specific spatial evidence is unavailable.
- Where the map shows sampling points without an explicit boundary, retain their locations. Construct an envelope only when the sampling design, point distribution and accompanying description support it. Treat separated groups separately. Record and justify any envelope method, distance threshold or buffer. If the evidence cannot support an area, leave polygon delineation pending.
- Preserve the complete supported footprint as an intermediate record. Apply the accepted scope and land masks using the procedure below. Retain disconnected components and interior holes. If the intersection is empty, record that no mapped coverage falls within the review area and leave the regional geometry pending for assessment against the result's evidence.
- Record the evidence source, construction method, mask filename and version or checksum, and any unresolved limitations in the geometry metadata and review log. Distinguish the paper's complete extent from the portion retained for this review.
- Validate and visually inspect the geometry after clipping. Confirm that the complete geometry, including all components and holes, survives export and reopening. If the tracer cannot preserve it, retain the GIS result as pending and document the compatibility issue.

### Restrict the evidence footprint to the review area and exclude land

Construct the evidence footprint from the paper before applying geographic masks. Preserve this complete footprint as an intermediate record so that the regional clipping can be reproduced.

Use two complementary references:

- **Statistical scope.** Use Areas 34 and 47 from [FAO 34/47 boundary layer](spatial/FAO_34_47.geojson) to establish the external limits of the review region.
- **Land exclusion.** Use the compact regional working layer [regional land layer](spatial/LAND_FAO_34_47.geojson) after common-mask acceptance. It combines the World Bank land polygons with the derived Sao Pedro and Sao Paulo supplement, retains nearby land for coastal harmonisation, and removes administrative attributes without simplifying the coastline. Original sources are archived outside the repository; the source archive, member paths and checksums are recorded in [source and mask register](spatial/land_sources_register.json). See [source and mask register](spatial/land_sources_register.json) for the derivation, checksums and outstanding acceptance checks.

Do not assign these operations to a particular compass direction. Apply land exclusion along mainland coasts and around islands wherever they occur.

#### Prepare and approve the common masks

- Keep the compact regional reference layers and accepted processing masks in `spatial/`. Archive the original source datasets outside the repository; record the archive location, member paths and checksums in [the shared source and mask register](spatial/land_sources_register.json), together with each layer's source, version or retrieval date, CRS, modifications and acceptance status.
- Validate the terrestrial polygons and merge them into a common land mask. Retain small islands and rocks supported by the accepted source.
- Inspect differences between the FAO coastline and the terrestrial reference. Where they disagree, use the accepted terrestrial reference to define the land-sea boundary while preserving the external statistical limits of Areas 34 and 47. Document and review any reconstruction of the coastal part of the scope mask. Do not enlarge the external statistical boundaries.
- Accept the common masks before applying them across papers. Use the same accepted mask versions for all studies in a synthesis, and record later revisions that require reprocessing earlier polygons.

The Sao Pedro and Sao Paulo supplement is derived from the Brazilian Navy's chart 11 plan at 1:1,000 scale. Review its contours, coverage, processing method and source-use conditions before accepting it into the common land mask. Retain its status as a derived dataset and its documented limitations.

#### Clip each study-area geometry

1. Construct and geographically calibrate the footprint using the paper's text, map, caption and legend, following the evidence-selection rules above.
2. Intersect the complete footprint with the accepted FAO 34/47 scope mask.
3. Subtract the accepted land mask from the intersection.
4. Preserve disconnected components and interior holes. Do not join separate areas or fill gaps merely to obtain a single polygon.
5. Validate the result and inspect coastal sections and islands. Confirm that no measurable area remains outside the accepted scope mask or overlaps the land mask, using a documented numerical tolerance.
6. If the intersection is empty, record that the mapped footprint provides no coverage within the review area and reassess its attribution to the extracted result.

#### Record and verify the result

Record the source footprint, mask versions, processing steps, numerical tolerance and unresolved limitations in the geometry metadata and review log. In `study_area_as_reported`, describe the area supported by the paper. In `extraction_notes`, explain the clipping and what portion is retained for the review.

Check that the exported study-area GeoJSON preserves all components and holes and remains consistent with its calibration and editing metadata. Reopen it in GIS and in the tracer. If the tracer cannot preserve the clipped geometry, retain the result as pending and document the compatibility issue.

A finer land mask improves coastal delineation but does not increase the positional accuracy of the paper's map or its calibration. Keep those uncertainties explicit.

### Use bathymetry only where it supports the evidence footprint

Use a versioned bathymetric raster and derived depth contours as an additional reference when the paper defines a depth-bounded study domain. An explicit limit such as sampling to the 500-m isobath can justify a bathymetric boundary. A reported range of capture depths alone does not establish continuous sampling throughout that depth band. Do not infer occupied area from depth suitability alone.

Prefer the article's explicit boundary or spatial data. Use external bathymetry to reconstruct missing depth limits only when its role is justified by the text, figure and sampling design. Retain the original footprint, identify reconstructed sections, preserve gaps and components, and record the raster version, source, CRS, vertical units and convention, resolution, contour thresholds and processing steps. A finer raster does not improve the accuracy of the source map or calibration. Compare the reconstruction against the article's map and record discrepancies. Leave unsupported boundaries pending rather than replacing them with an arbitrary contour.

Keep the bathymetric raster separate from the statistical-scope and land masks. Archive large source grids outside the repository and retain reproducible regional extracts or derived products with their provenance. Do not use the raster's zero contour to replace the accepted land mask without a separate review. Verify coverage before extracting contours; do not fill missing coverage by extrapolation. Generate article-specific depth thresholds as needed rather than limiting all articles to a fixed contour list.

### Assign jurisdiction and statistical units after geographic verification

Construct and calibrate the result-specific footprint from text and mapped evidence, apply justified depth or jurisdictional construction constraints, restrict it to the accepted FAO 34/47 scope and exclude land. Verify the geometry before calculating its spatial classifications. Review the study-area description and polygon together so that neither implies unsupported precision or coverage.

Intersect the verified regional geometry with the versioned EEZ reference and the accepted FAO assignment-unit layer. These layers classify the polygon; do not normally use them to reshape it. An EEZ boundary can constrain construction only when the paper explicitly restricts its domain to that jurisdiction. Modern jurisdiction boundaries are not automatically historical fishing-agreement boundaries.

For each resultID, retain an audit table containing the polygon filename and checksum, reference layer and checksum, jurisdiction or FAO code, overlap area, polygon area, percentage of polygon area, calculation CRS, assignment basis and review status. The percentages describe spatial extent only and must not be interpreted as shares of observations, catches or fishing effort. Do not split or duplicate an aggregate result merely because its footprint spans several units.

Assign every supported unit with a substantive area overlap. Exclude edge-only contacts. Use a documented numerical tolerance for computational artifacts and separately assess small overlaps in relation to calibration and boundary uncertainty; do not use one arbitrary percentage threshold to erase genuine small regions. Flag unstable classifications for human review. Preserve overlapping claims and distinguish territory from sovereign state, mapping accepted territory names to the project dropdown labels. Do not count overlapping claims twice when calculating total covered area.

Assign `International waters` only from intersection with the explicit [regional high-seas reference](spatial/HIGH_SEAS_FAO_34_47.geojson), derived from Marine Regions High Seas v2 (2024). Unassigned coastal gaps caused by reference-layer differences are excluded from automatic jurisdiction assignment: do not classify them as international waters, merge them into the nearest EEZ or modify the study footprint to remove them. Record any unassigned overlap and its consequence in the spatial audit; a coastal gap alone must not add an EEZ or `International waters` to the workbook.

Record the most detailed FAO units supported by the spatial evidence, using the explicit hierarchy supplied by the source. Do not infer a parent solely by splitting a code string: source codes may use different conventions. Avoid listing both a parent and its descendant as independent covered units. Retain the original source code, label and hierarchy; document any display-code crosswalk rather than silently changing official source values. Where boundaries differ between the existing major-area mask and the current hierarchy, resolve and approve a common version before routine assignment. Retain unresolved residuals for review.

Spatial assignments are provisional until the polygon and classifications have been checked. Where no usable polygon exists, text-supported EEZ or FAO assignments can be recorded with their explicit source and method; do not manufacture a polygon to populate these fields. Log discrepancies between text and geometry. Preserve existing populated workbook values until an authorised, logged correction is applied.

#### Shared reference files and acceptance status

Use [the FAO hierarchy](spatial/FAO_34_47_hierarchy.geojson), [the terminal assignment units](spatial/FAO_34_47_assignment_units.geojson) and [the code catalogue](spatial/FAO_34_47_catalogue.csv). The catalogue contains 45 codes, including 33 terminal units and 12 broader fallback units. Keep the original source codes, including the FAO WFS subdivision notation, and use the explicit parent fields rather than reconstructing the hierarchy from punctuation.

Use [the regional EEZ reference](spatial/EEZ_FAO_34_47.geojson) and [the regional high-seas reference](spatial/HIGH_SEAS_FAO_34_47.geojson) for jurisdiction classification. The high-seas layer is clipped to FAO 34/47 and excludes the project land mask and current EEZ polygons. Territory and sovereign fields and overlapping claims must be retained. The former unclassified-residual layer is retired from `spatial/` and archived outside the repository. Its coastal remnants are not retained as a working classification layer; they are not added to neighbouring jurisdictions or subtracted from study polygons.

Sources, retrieval dates, hashes, processing methods, validation and remaining limitations are recorded in [the spatial reference register](spatial/spatial_reference_register.json). These classification references were retrieved on 26 November 2026. The catalogue is approved for the workbook; routine automatic spatial assignments remain pending reconciliation of the current FAO hierarchy with the existing major-area mask and review of uncertain jurisdictional boundary intersections. Coastal residuals are deliberately excluded from automatic classification under the policy above. Do not silently change the review's external statistical limits or infer historical jurisdiction boundaries from the current EEZ layer. Use the verified [GEBCO 2020 regional raster](spatial/GEBCO_2020_FAO_34_47.tif) for bathymetric reference and article-specific contour extraction. It covers FAO 34/47 at the original 15-arc-second spacing, with lossless compression and cells outside the statistical scope set to NoData. Elevations are in metres relative to sea level; depth contours use negative elevation values (for example, -750 m for 750-m depth). Base-resolution values and grid alignment are unchanged from the source. Display overviews are not the analytical resolution. This raster is not a universal depth mask: justify each article-specific depth constraint under the bathymetry rules above, and retain the separate land-exclusion procedure.


### Complete the tracer workflow: select, trace, calibrate and export

- Before tracing, read `study_area_as_reported` together with its cited text, figure, caption and legend. Use that description to guide the polygon’s extent and boundary interpretation. Record any additional construction choices in `extraction_notes`. If tracing reveals that the description needs correction, follow section 2’s rules for changes to populated cells.

Use the [REDUCE study-area tracer](https://spatialmarine.github.io/REDUCE_review/study-area-tracer/) and complete the same four-step process as a user of that website. Do not stop after drawing the outline or bypass the geographic-review conditions that unlock the exports.

1. **Open the source PDF.** Select the verified article and its exact PDF page. Keep the PDF filename and SHA-256 fingerprint with the export metadata so the reviewer can load the same source.
2. **Select the map panel.** Crop the relevant map, keeping the outline and the reference locations needed for calibration visible. Preserve the crop, render resolution and full-page pixel coordinate convention used by the tracer. Do not calibrate a different panel, inset or PDF version by mistake.
3. **Construct the evidence footprint.** Follow the evidence-selection and FAO-clipping rules above. Preserve the footprint's disconnected areas and holes. Keep the complete source footprint and the regional clipped geometry traceable, and verify that the editing and export workflow preserves both their geometry and meaning. Record whether the geometry represents observed coverage, an analytical domain or an approximate envelope. Give separate panels or outlines distinct identifiers when separate exports are needed.
4. **Calibrate geographically and inspect the result.** Match identifiable locations on the PDF to verified WGS 84 coordinates. Use labelled graticule intersections where available, or identifiable locations with coordinates checked against an independent georeferenced source. A scale bar alone cannot determine geographic position. Enter decimal degrees in `[longitude, latitude]` order, with west and south negative. The tracer uses an affine fit and exports WGS 84 longitude/latitude coordinates (`OGC:CRS84`). Record the source map's projection/datum when known, or the explicit projection assumption and its limitations.

For calibration, mark at least three distinct, non-collinear **Fit** controls distributed around the outline, plus at least one genuinely independent **Check** control at a different known location. Check controls must be excluded from the fit; do not duplicate or relabel a Fit location to simulate an independent check. Keep all control points visible within the selected crop and record the coordinate source for each point.

Use all legible longitude and latitude labels to constrain or check the calibration where their locations can be interpreted reliably. Each control requires both a known longitude and a known latitude. Prefer printed graticule intersections. A marginal label supplies only one coordinate; infer intersections from marginal ticks only when the map supports a straight, axis-aligned graticule, and explicitly record that construction and its projection assumption.

Distribute Fit controls near the extremes and around the footprint, with additional interior controls where useful. Reserve separate Check locations across the panel, including interior and edge locations where available, before fitting. Use additional labels to assess different parts of the map rather than assigning every location to Fit. Do not generate a dense set of apparently independent controls from the same few axis marks; such constructed locations share reference information. Checks inferred from the same labelled axes test internal map consistency and must be distinguished from checks against an independent geographic source.

More controls do not correct an unsuitable transformation. Inspect whether Check errors increase toward the edges or show a systematic spatial pattern. If they do, reconsider the projection assumption and transformation model. Document the coordinate sources, Fit/Check allocation and any reliance on inferred intersections. Leave the calibration pending when the available references or model cannot support the intended mapping accuracy.

Read the Check errors in kilometres, compare the geographic preview with the source and an independent reference such as a coastline, and inspect any vertices outside the Fit-control boundary, where the transformation extrapolates. Judge the errors against the figure resolution and intended mapping use; do not assume a successful fit proves geographic accuracy. Correct misplaced controls, signs or coordinate conversions. If the affine model cannot adequately represent the source projection, the reference locations cannot be verified or the errors are unacceptable, leave geometry generation pending and document the specific obstacle. Do not invent control coordinates or force an export.

Complete every item of the tracer's geographic-review checklist only after performing the corresponding check. Identify the person or AI that actually performed this technical review; the AI must not enter the assigned human reviewer's identity or imply human approval. Record any required explanation of extrapolated sections and their reference evidence. The tracer's export status `reviewed` records this technical geographic check; it does not replace the independent human review tracked in the workbook.

Export the regional study-area geometry only after completing the scope clipping, land exclusion and verification steps above. Preserve the complete source footprint and its calibration so that the clipped result can be reproduced and revised.

Once both export buttons are enabled, download **both** `Download study-area GeoJSON` and `Download calibration GeoJSON`. Use the tracer's native export structures so that the pair remains usable in GIS and can be reloaded, edited and checked in the same website. Preserve the polygon's geographic coordinates and its editing metadata, including image-space vertices, crop, page, render resolution and embedded calibration. Preserve the calibration's geographic Point features, corresponding pixel positions, Fit/Check roles, coordinate-source notes, diagnostics, projection assumption and review metadata. Do not strip these fields to produce a generic geometry-only GeoJSON.

### Name, store and verify the GeoJSON pair

- Save both files together in `Polygons/<reviewer_code>/<topic>/`, relative to the reviewer workbook. Use the shared stem `<paperID>_<PDF_stem>_Fig<NN>`, adding a consistent panel or area identifier when needed. The required endings are `_study-area.geojson` and `_calibration.geojson`. Rename the downloaded files to this convention if the tracer supplies a page/crop-based filename, without discarding their internal metadata.
- For example, the PDF `Fernandez_JNorthwAtlFishSci_2005.pdf` and its Figure 1 produce `1560_Fernandez_JNorthwAtlFishSci_2005_Fig01_study-area.geojson` and `1560_Fernandez_JNorthwAtlFishSci_2005_Fig01_calibration.geojson` in the same folder. Distinct areas could use matching stems ending in `Fig01_north` and `Fig01_south`, each with its own pair. Never overwrite a different panel, result or reviewer's files just because they come from the same paper.
- Reopen the exact PDF/page in the tracer, load the study-area GeoJSON as the saved reference and load its companion calibration GeoJSON. Check that the outline and controls align with the intended map, the geographic preview is consistent, and the editing and recalibration controls work. Loading a saved pair may reset the website's checklist for a fresh review; that is expected and must not be bypassed. Inspect the exported polygon against an independent geographic reference to establish that it is located correctly and uses longitude/latitude rather than pixel coordinates.
- Confirm that both files exist, parse as GeoJSON FeatureCollections, and carry consistent PDF/page/calibration metadata. The study-area export must contain a valid closed geographic polygon; the calibration export must contain the geographic control points and the metadata needed to recover their pixel locations and roles. Confirm the intended `paperID`, `resultID`, figure/panel and represented extent in the export metadata where supported and in the review log. Record both relative file paths together in that log so the pair is traceable.
- In `geometry_file`, record the relative path to the **study-area GeoJSON**, for example `Polygons/DRG/Megafauna catch/1560_Fernandez_JNorthwAtlFishSci_2005_Fig01_study-area.geojson`. Record the companion calibration path in `extraction_notes` or the reviewer change log, without adding workbook columns. In `source_reference`, give the figure, PDF page and what the outline represents. Flag approximation, coordinate sources, projection assumptions and unresolved limitations explicitly.
- For new work, set `polygon_studyArea` to `Yes` only after the calibrated polygon and companion calibration have both been exported, saved and checked for reopening in the tracer. If only a pixel-space draft exists or calibration/export cannot be completed, leave the geometry task pending, use `No` for a new row, leave `geometry_file` blank and explain what remains in `extraction_notes`. Preserve existing populated values unless a correction is authorised and logged under section 2.
- Leave `geometry_checked`, `geometry_edited` and `geometry_edited_uploaded` blank on new rows and preserve any existing values. Only the human reviewer fills these fields after independently reviewing the polygon and calibration. When the human reviewer edits a pair, keep its filenames and workbook/log links consistent and retain the review trail.
- Keep historical `_trace.json` files as intermediate records; do not delete them or present them as the final deliverables. When continuing an older case, reopen its trace as a starting reference, complete the calibration and review workflow, export and verify the two GeoJSON files, and propose or apply the corresponding workbook-path correction according to section 2. A case with only a historical trace remains incomplete until the required pair is available.

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
| `rev_AI` | Full verified model identifier (version and variant) and reasoning effort used for the assessment. Example: `gpt-6.1-sol (reasoning effort: low)`. Explicitly label any unavailable variant or effort information; a bare family label such as `GPT-6` is insufficient. Follow section 1 and preserve the attribution of the model that performed the assessment. |
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
| `study_area_as_reported` | One paragraph describing the result-specific study area and guiding polygon delineation, following section 2. Combine text and mapped evidence, including relevant coordinates, depths, boundary interpretation and temporal applicability. Distinguish reported limits from inferred or proposed limits and cite the supporting figure/page. |
| `FAO_area` | Record `34`, `47` or `34 / 47` for the result-specific regional evidence. Prefer a verified polygon intersection; otherwise use explicit reported location and record the assignment basis. Leave unresolved attribution pending. |
| `FAO_subdivisions` | Immediately after `FAO_area`, record the supported most detailed FAO codes from the shared 45-code catalogue, separated by ` / `, without duplicating their parents. Use the 33 terminal units for detailed spatial assignment; select a broader fallback unit when only that level is supported. Record reference versions, assignment basis and uncertain overlaps in `extraction_notes` or the geometry log. Leave unknown assignments blank. |
| `EEZ` | Record all supported jurisdiction reporting units using the agreed territory labels. Prefer verified polygon intersections; otherwise cite explicit reported attribution. Review overlapping claims, uncertain boundary intersections and international waters. Modern EEZs do not establish historical agreement boundaries. A landing port or vessel flag does not locate the catch. Record the assignment basis and any missing dropdown unit in `extraction_notes` or the geometry log. |
| `evidence_scope` | Use `Regional evidence` for a result attributable to FAO 34 or 47. In an otherwise eligible paper, use `Global evidence only` for context that cannot be separated for the region, and keep that result out of the regional synthesis. Use `Pending verification` when attribution needs checking. |
| `polygon_studyArea` | For new work, use `Yes` only when the calibrated study-area GeoJSON and its companion calibration GeoJSON have both been exported, saved and verified under section 3. Use `No` while that pair is unavailable and explain pending geometry work in `extraction_notes`. A pixel-space trace, point, line or set of isolated cells alone does not constitute a completed study-area polygon. Preserve existing values subject to the correction rules. |
| `geometry_file` | Path to the verified `_study-area.geojson`, relative to the reviewer workbook. Save the matching `_calibration.geojson` alongside it and record the companion path in `extraction_notes` or the reviewer change log. Leave blank for new work without the verified pair. Historical trace paths require a logged correction when the GeoJSON pair is completed. |
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
- The workbook guidance for `rev_AI` should request the full verified model identifier, including version and variant, plus the reasoning effort used for the assessment. It should show the required format, explicitly identify unavailable metadata, and distinguish the assessing model from a later model that only edits formatting or row order, as specified in section 1.
- The workbook guidance for `species_scientific_names` should clarify that identified species can be listed when the corresponding result is reported at group level.
- The workbook guidance for `geometry_checked`, `geometry_edited` and `geometry_edited_uploaded` should state that only the human reviewer fills these fields and that they stay blank before human review.
