# How to work with me on code

Follow the repository's conventions, architecture, test commands, and rules for protected inputs. If they conflict with this agreement, explain the conflict and ask me how to proceed.

## 1. Inspect, propose, and wait for approval

- Start with read-only inspection. Read the relevant files and check the working tree. Use my latest version, including any local edits.
- Before editing, explain the proposed change, affected files or sections, expected result, and verification plan. Keep the proposal proportional to the task.
- If delivery is unclear, ask whether I want code in the chat, edits to my local files, or a pull request.
- Wait for my explicit OK before editing. A request to explain, investigate, review, or suggest a fix authorises read-only work.
- Stay within the approved scope and delivery method. Ask before acting on a new decision or ambiguity. Carry out already approved steps without asking for the same approval again.

## 2. Keep local work, publication, and merging separate

- For local edits, use the agreed path and preserve my work. If a file changes during the task, reread it and flag any overlap before writing. Ask before Git actions outside the agreed delivery method.
- **First OK for a PR — prepare it locally.** Once I approve the proposal and the PR route, make the agreed edits, create the agreed local branch, and make local commits. Check the status of any existing PR. If it is closed or merged, ask how to proceed.
- **Second OK for a PR — publish the reviewed diff.** Show me the actual diff and verification results. Confirm the repository, target branch, and whether to open or update a PR. Wait for my explicit OK before pushing or opening or updating it, including a draft. Open new PRs as drafts unless we agree otherwise.
- If feedback, a rebase, or any other edit changes the approved diff, show me the revised diff and get approval before publishing.
- Merge only when I explicitly authorise merging that specific PR. Ask if my wording is ambiguous.
- Ask before marking a PR ready, pushing directly to the default branch, force-pushing, or rewriting history. Apply the same approval rules to skills and workflows that create issues, post comments, or take other external actions.

## 3. Keep changes within the agreed scope

- Make the smallest change that delivers the agreed result. Preserve unrelated code, formatting, documentation, configuration, and outputs. Report separate bugs or cleanup opportunities separately.
- Ask before adding dependencies or changing interfaces, data definitions, output formats, or filenames unless already covered by the approval.
- Protect manual inputs and existing user edits. Use copies of inputs and temporary output locations when verification generates files.

## 4. Write code I can follow from top to bottom

- **Organise scripts around their tasks and outputs.** Keep preparation, calculation, the figure or table, and export together under a descriptive heading. Put the display and save commands immediately below a plot.
- **Keep the opening section for inputs and outputs.** At the top of a script, define where the inputs come from and where the results are written. Define policies, parameters, colours, expected columns, and validation rules in the section that uses them. If several subsections share a setting, define it at the start of their parent section.
- **Use numbered sections and subsections organised by purpose.** Give each main task a heading such as `# 1. Main task`, and give each distinct step a descriptive subheading such as `# 1.1. First step` and `# 1.2. Second step`. Keep the settings, checks, transformations, and outputs for each objective together under its heading. Leave a blank line between blocks that do different things.
- **Write small operations where they are used.** Repeating a few straightforward lines is fine when it makes a block easier to follow. Use a function when it improves readability or keeps a substantial shared rule consistent. Follow the repository's architecture in application and library code.
- **Prefer clear names and visible steps.** Use a short pipeline or an explicit loop when it makes the sequence easier to follow. Split dense expressions into named steps when the intermediate results have distinct purposes.
- **Keep code compact and readable.** Keep a function call and its arguments on one line when the call is easy to scan. Wrap long or complex calls where a line break helps the reader follow the arguments. Keep control flow and separate operations on their own lines. When reviewing the diff, check for multiline calls in every block you were asked to edit or review for style. Put each call on one line if it remains easy to scan. Keep line breaks where they help the reader understand the arguments or where the repository's formatter requires them. Apply this rule to nested calls as well. If the outer call spans several lines, keep each argument on one line when it is easy to read, including arguments that are themselves function calls. During the style review, check both the outer call and its nested calls.
- **Write comments in English.** Put a brief comment immediately above each line or group of lines with a distinct purpose. One comment can cover several lines that serve one purpose.
- **Apply the comment rule inside functions and control flow.** Put a brief English comment immediately above each block that serves a distinct purpose, including early returns, validation checks, joins, loops, and file writes. Explain the condition, what the block does, and any consequence that matters for the data or output. During a style review, read each function body from top to bottom and check that every distinct step can be followed without inferring its purpose from the syntax alone.
- **Leave a blank line between blocks that do different things.** Use short, descriptive headings and subheadings. Match the layout and naming of the surrounding code.
- **Keep checks close to the data or rule they protect.** Check required columns when loading the input. Explain rules about unique IDs, denominators, and missingness next to the calculation.
- **Make outputs easy to interpret.** Keep related values side by side and use the sheets and columns the reader needs.
- **Use an approved file as a style reference.** When I point you to a file, read the relevant sections before proposing changes. Follow its headings, spacing, comment placement, naming, and level of detail where they fit the task. Each repository can specify its own reference.
- **Explain the rule next to the operation that applies it.** Put the comment immediately above the relevant filter, join, grouping, or calculation, including inside a pipeline. A comment above the whole pipeline can explain its overall purpose. Use short English comments and leave a blank line between blocks with different purposes.
- **Make the unit and meaning of each result clear.** For data work, explain what one row represents when it changes, what each count includes, and how overlapping cases are handled. Carry those distinctions into labels and exports. For example, use “Added a value” for an intervention on an initially blank field and “Blank” for a field that still applies and remains empty in the final result.

## 5. Verify the result and make it easy to review

- The first OK covers the usual checks and test runs in a temporary location. Use the repository's existing checks and, where practical, exercise its normal entry point. Ask before adding tests outside the approved scope.
- For a style-only refactor, compare relevant outputs before and after. For a behaviour change, verify the agreed difference. Ask separately before replacing deliverables in their real output folders.
- Check the final diff against the approved scope. Tell me which files or sections changed, what you checked, and what you could not verify. Distinguish edits from regenerated outputs and published changes. Link to the local file, diff, or authorised PR.

## REDUCE_review style reference

Use `src/07_screeningFeedback.R` as the approved style reference for analysis scripts in this repository.

## REDUCE_review full-text screening protocol

### Scope and recording

- Confirm the workbook, reviewer code and paper IDs in scope before screening. Use the full text and any relevant supplements. Use titles, abstracts and existing classifications to guide retrieval and assessment.
- In `Full_text_screening`, keep one row per assigned `paperID`. Preserve the bibliographic fields, DOI links, dropdowns and both review blocks. Keep data extraction outside this stage until the extraction fields and instructions have been agreed.
- The AI writes only `rev_AI`, `FT_decisionAI`, `FT_exclCriteria_AI` and `notes_AI`. Record the model actually used in `rev_AI`. If its exact identifier is unavailable, record only the model information that can be verified.
- The human reviewer reads the AI assessment and records their own decision in `FT_decisionRev1`, even when it agrees with the AI. Preserve the prefilled code in `rev1_name`. Use `FT_exclCriteria_rev1` and `notes` for the human rationale. Human decisions are used for consolidation and PRISMA counts. Keep both human assessments for double-assigned articles and document AI assistance in the methodology.
- Select `Accepted` or `Rejected` from the decision dropdown. For a rejection, select exactly one exclusion code from the corresponding dropdown. Leave the exclusion code blank for accepted or pending articles. In the applicable notes column, give a short, article-specific rationale in English, citing the page, section, table, figure or supplement when available.
- If the full text has not been retrieved or an unresolved question could change the decision, leave the decision and criterion blank. Record the retrieval issue or the specific evidence still needed in the applicable notes column.

### Apply the criteria in order

Apply **LANGUAGE → DOCUMENT → NOTOPIC → LOCATION → GEAR → TAXA → STUDY_TYPE**. For a rejected article, record the first applicable exclusion code in this hierarchy. If uncertainty about an earlier criterion could change the recorded code, flag the article for review. Consider all eligible topic pathways before rejecting a paper. The topic, location, gear and taxa used to justify inclusion must refer to the same qualifying evidence.

1. **LANGUAGE.** The full text must be in English. An English title or abstract alone is insufficient.
2. **DOCUMENT.** Eligible formats are journal articles, reports and book chapters. Exclude presentations, editorial material, letters, news items, conference or meeting abstracts, posters, dissertations and theses.
3. **NOTOPIC.** The study must directly quantify, describe, map, estimate or analyse an eligible topic. Check the methods and results, including relevant secondary results for megafauna catch.
   - **Fishing effort.** One of the study's primary objectives must be to quantify, describe, map, estimate, analyse or compare effort. Developing or reanalysing datasets such as Global Fishing Watch qualifies when the study reports effort metrics or patterns. Using effort solely as an explanatory variable is insufficient unless another topic qualifies.
   - **IUU fishing.** The study must directly address illegal, unreported or unregulated fishing. A mention in the background or discussion is insufficient.
   - **Ghost gear.** The study must directly address abandoned, lost or otherwise discarded fishing gear (ALDFG).
   - **Megafauna catch.** Include evidence of observed captures or estimates based on capture data. Spatial overlap, vessel attendance and other behavioural interactions alone are insufficient. When bycaught animals are used to study diet, genetics, parasites, taxonomy or another topic, check for eligible capture or bycatch rates. Those rates can qualify even when bycatch is a secondary objective. The use of bycaught specimens alone is insufficient. Apply the separate TAXA criterion to studies that otherwise address capture.
4. **LOCATION.** Eligible evidence must concern the West African study area in FAO Area 34 or 47. For global or multi-region studies, look for a relevant case study or identifiable results for the area. A passing mention of the area is insufficient.
5. **GEAR.** Eligible gears are industrial purse seine, longline and trawl. Commercial-vessel studies and research-vessel surveys using eligible gear can qualify. Exclude artisanal and small-scale fisheries. For mixed-gear studies, check that qualifying evidence can be attributed to an eligible gear.
6. **TAXA.** Applies only to the megafauna catch pathway. Eligible groups are marine mammals, sea turtles, seabirds and chondrichthyans. A paper can still qualify through fishing effort, IUU fishing or ghost gear.
7. **STUDY_TYPE.** Exclude non-empirical literature reviews, conceptual or perspective papers, protocol reviews and methods-only papers without an eligible empirical application. Meta-analyses can qualify if they meet the remaining criteria. A methods paper can qualify if it tests the method on an eligible case in the study area.

### Store full-text PDFs and study-area polygons

- Use the reviewer acronyms defined in `src/09_prepareFullTextReviewerFiles.R`. Within `output/full_text_screening/by_reviewer`, store PDFs in `Papers/<reviewer_code>/<topic>/` and polygon traces in `Polygons/<reviewer_code>/<topic>/`. Use the topic folder names `IUU`, `Megafauna catch`, `Fishing effort` and `Ghost gear`.
- Name each PDF `FirstAuthor_JournalAbbrev_Year.pdf`. Use the first author's surname, the abbreviated journal name and the publication year. For reports, use the publisher or series abbreviation in place of the journal. Keep the source PDF in its original location and copy it to the assigned reviewer and topic folder with the standard name. If a paper is extracted for more than one topic, place a copy in each applicable topic folder.
- Name each editable polygon trace `<paperID>_<PDF_stem>_Fig<NN>_trace.json`. For example, `1560_Fernandez_JNorthwAtlFishSci_2005_Fig01_trace.json` matches `Fernandez_JNorthwAtlFishSci_2005.pdf`. If a figure contains several outlines, add a panel or area identifier to distinguish them.
- For a paper assigned to two reviewers, place a copy of the PDF in each reviewer's folder and keep their polygon files separate. Store each polygon in the topic folder for the result it represents. Keep the PDF filename recorded in each trace consistent with the PDF the reviewer opens in the web tool.
- In `geometry_file`, record the path relative to the reviewer workbook, for example `Polygons/DRG/Megafauna catch/1560_Fernandez_JNorthwAtlFishSci_2005_Fig01_trace.json`. Record the figure or page and what the outline represents in `source_reference`. Flag approximate outlines and state what was used to draw them.
- Once the trace has been saved, set `polygon_studyArea` to `Yes` and `geometry_checked` to `No` until the reviewer checks it in the web tool. After checking, the reviewer records whether they edited the trace and, if they did, whether they uploaded the edited file.

### Check before saving

Confirm that each rejection uses the first supported code, each acceptance has a blank exclusion code and unresolved cases remain distinguishable in the notes. Check that only the approved review fields and paper IDs were edited. Report accepted, rejected and pending counts and list unresolved paper IDs.
