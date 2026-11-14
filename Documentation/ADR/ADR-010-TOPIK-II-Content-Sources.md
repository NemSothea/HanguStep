# ADR-010: TOPIK II content sources

Status: Accepted (2026-11-14)

## Context

The library shipped with TOPIK I content only (levels 1-2). The learner targets TOPIK II level 3-4 before April 2027, so TOPIK II vocabulary and grammar are needed before release (Phase 11).

The planned source, 한국어기초사전 (krdict, CC BY-SA 2.0 KR), cannot be used: its download needs a login the learner cannot complete, and the site returns HTTP 400 to every request from our tooling. TOPIK publishes no official vocabulary list with levels.

## Decision

1. **Word and grammar choice from real exams.** Count lemma frequency in 12 TOPIK II past papers (2014-2025) and 5 TOPIK I papers, using OCR (macOS Vision) and a morphological analyser (kiwipiepy). Teach words that appear in the most TOPIK II exams and rarely in TOPIK I. Tools: `Tools/topik-corpus/`.
2. **Exam papers are never shipped.** PDFs and OCR text stay in git-ignored `ContentSources/`. Only the derived word list (facts, not expression) influences the app. Every example sentence, question and explanation is written by us.
3. **English meanings from Wiktionary** (kaikki.org extract, CC BY-SA 4.0) where a sense fits the exam usage. Those items carry `source.origin = imported`, licence CC BY-SA 4.0 and a link to the Wiktionary page. Homographs are resolved by hand (제도 = system, not archipelago). Words with no fitting Wiktionary sense are written by us and keep the library default (CC BY 4.0).
4. **Attribution in the app.** The word detail screen shows the source line with a link for imported items; Settings lists each distinct imported source (`ContentPackage.importedCredits`).
5. **Levels.** The most frequent batch is level 3; later batches are level 4. Basic everyday words that turn up in the count but were missing from levels 1-2 (비행기, 건물, 피부 ...) are tagged level 2 instead. This is a judgement, documented as such.
6. **Khmer** is drafted by AI and every item ships `review: pending`. Review is optional (learner decision, 2026-11-14): batches are not held back for it.
7. **Batches.** 300 words + 20 grammar patterns first, then about 300 words per week, so study can start before the full 1,500 are done.

## Consequences

- Content reflects what the exam actually tests, not a guess.
- The library becomes mixed-licence (CC BY 4.0 + CC BY-SA 4.0 items). Anyone redistributing the content must keep item-level sources.
- kiwipiepy (LGPL) is a developer tool only; it is not linked into the app, so no app dependency is added.
- OCR errors can drop or misread rare words; frequent words are robust because they recur across exams.
- Level 3 vs 4 labels may differ from a textbook's; frequency ordering matters more for exam preparation.
