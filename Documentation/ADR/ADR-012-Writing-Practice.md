# ADR-012: Writing practice with model answers and optional AI feedback

Status: Accepted (2026-11-14)

## Context

Writing (쓰기) is 100 of the 300 TOPIK II points. Questions 51-52 fill two blanks, 53 describes data in 200-300 characters, 54 is a 600-700 character essay. The app trained none of it (PRD Q4). The learner wants feedback, and there is no teacher.

## Decision

1. **Prompts are read-only content** in `Content/writing/tasks.json` (30 original tasks: 10 per type), decoded on demand by `BundledWritingTasks` and validated by `content-lint`. They are not imported into Core Data: small, never queried, never synced.
2. **Answers are learner data**: new `CDWritingAttempt` in the Learner configuration, added as model version **v2** (additive, lightweight migration, CloudKit-compatible). Feedback is stored as JSON text on the attempt. Fixture `Learner-v2.sqlite` added; the v1 fixture test now also writes an attempt after migrating.
3. **Character count** follows the answer sheet: spaces count, line breaks do not. The editor shows a live counter against the required range.
4. **Unsaved drafts** stay on the device (`UserDefaults`, one key per task) so leaving the screen loses nothing; saving clears the draft.
5. **Feedback** goes through `AssistantProvider.reviewWriting`:
   - Built-in (offline): rule checks only (length, both blanks, 한다체 in 53-54, paragraphs in 54). It never invents a score.
   - Claude: structured output graded on TOPIK's criteria (content and task, organisation, language use) with up to 12 corrections. Scores are clamped to the task's maximum. Comments follow the learner's gloss language.
   - Only on an explicit "Get feedback" tap, with the learner's own key (ADR-008/009).
6. Entry point: Quiz tab, "Writing practice", below the quiz setup.

## Consequences

- The AI score is an estimate, not an official grade; the UI says "Estimated".
- Essay text leaves the device only on request and only to Anthropic (SECURITY.md §3).
- With iCloud off (free signing), attempts stay on the device.
- 51-52 answers are free text with ㉠/㉡ lines; the offline check cannot judge correctness, so the model answer is always available to compare.
