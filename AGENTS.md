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
- **Keep code compact and readable.** Keep a function call and its arguments on one line when the call is easy to scan. Wrap long or complex calls where a line break helps the reader follow the arguments. Keep control flow and separate operations on their own lines. When reviewing the diff, check for multiline calls in every block you were asked to edit or review for style. Put each call on one line if it remains easy to scan. Keep line breaks where they help the reader understand the arguments or where the repository's formatter requires them.
- **Write comments in English.** Put a brief comment immediately above each line or group of lines with a distinct purpose. One comment can cover several lines that serve one purpose.
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
