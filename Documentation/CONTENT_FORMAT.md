# HanguStep Content Format

Version 1 · Phase 7 · Status: implemented 2026-11-04, in review

Defines the JSON library that ships inside the app and the tooling that validates it (PRD FR-C1 to FR-C3, AC-10). Decision record: `ADR/ADR-007-Content-Format-and-Import.md`.

## 1. Layout

```
Packages/HanguStepKit/Sources/Persistence/Resources/Content/
├── package.json                      # format version, library version, default source
├── summary.json                      # output of `content-lint generate-questions`, do not edit
├── vocabulary/*.json                 # part files, any number
├── writing/*.json                    # TOPIK II writing prompts (not part of the package, see below)
├── grammar/*.json
└── questions/
    ├── authored.json                 # hand-written grammar, sentence and reading questions
    └── generated-meaning.json        # output of `content-lint generate-questions`, do not edit
```

`package.json` is the only required file. Every other file is a **part**: an object with any of `vocabulary`, `grammar`, `questions` arrays. Parts are merged in file-name order; ids must be unique across the whole library. The folder names are a convention for authors, not a rule: a part under `grammar/` may contain questions.

The directory is copied verbatim into the Persistence resource bundle (`.copy("Resources/Content")` in `Package.swift`) and loaded by `BundledContent.load()`.

## 2. `package.json`

```json
{
  "formatVersion": 1,
  "version": 2,
  "source": { "origin": "curated", "name": "HanguStep content library", "license": "CC BY 4.0", "url": "https://..." }
}
```

| Field | Rule |
|-------|------|
| `formatVersion` | Must equal `ContentFile.supportedFormatVersion` (1). Any other value is rejected before decoding parts. |
| `version` | Integer. Must increase for the app to re-import (FR-C2). Same version = import skipped. |
| `source` | Default `ContentSource` for every item that does not carry its own `source`. `origin` is `curated`, `generated` or `imported`; `url` optional. |

## 3. Items

Shared rules: `id` is ASCII letters, digits, `.`, `-`, `_`; `level` is 1 to 6 (TOPIK I = 1 to 2, TOPIK II = 3 to 6); every `examples` entry needs `ko`, `en` and `km`; `source` and `review` are optional on every item. `review` is `pending` or `reviewed` and is authoring metadata only: it is counted for the Settings screen, never stored in Core Data.

### Vocabulary

```json
{ "id": "vocab.0001", "hangul": "학교", "romanization": "hakgyo", "hanja": "學校", "pos": "noun", "level": 1,
  "category": "school", "meaning": { "en": "school", "km": "សាលារៀន" },
  "examples": [ { "ko": "저는 학교에 가요.", "en": "I go to school.", "km": "ខ្ញុំទៅសាលារៀន។" } ], "review": "pending" }
```

`pos` is a `PartOfSpeech` raw value: `noun`, `verb`, `adjective`, `adverb`, `particle`, `pronoun`, `numeral`, `determiner`, `interjection`, `suffix`, `expression`, `other`. `hangul`, `romanization`, `meaning.en`, `meaning.km` must be non-empty.

### Grammar

```json
{ "id": "grammar.0002", "pattern": "-아/어요", "level": 1, "category": "sentence ending",
  "explanation": { "en": "...", "km": "..." }, "formation": { "en": "...", "km": "..." },
  "examples": [ ... ], "related": [ "grammar.0001" ], "review": "pending" }
```

`pattern` follows textbook notation: `-` for a verb or adjective stem, `N` for a noun slot, `V` only where the pattern wraps a verb (`안 V`). `related` ids must exist in the library. `formation` is optional.

### Questions

```json
{ "id": "q.gf.0001", "kind": "grammarFillIn", "level": 1, "prompt": "저는 학생______.", "passage": null,
  "options": [ "이에요", "예요", "있어요", "해요" ], "answer": 0,
  "explanation": { "en": "...", "km": "..." }, "grammar": "grammar.0001", "vocabulary": "vocab.0006", "review": "pending" }
```

`kind` is a `QuestionKind` raw value: `vocabularyMeaning`, `meaningToWord`, `grammarFillIn`, `sentenceCompletion`, `readingComprehension`, `listening`. `options` holds 2 to 4 distinct strings; `answer` is the zero-based index of the correct one. Option ids `o1`, `o2`, ... are derived from position, so **never reorder options of a shipped question**: learner attempts store the option id. Change the id of the question instead. `vocabulary` and `grammar` link the question to a learning target and must exist; a question needs at least one of them to count toward progress. `passage` is used by `readingComprehension` (the text to read) and `listening` (the script, required). A listening script has one line per turn, starting `남자: ` or `여자: `; other lines are narration. The app speaks it with on-device TTS (one voice per speaker) and shows it only after the learner answers. Listening questions carry no `vocabulary` or `grammar` link, so they never enter the review queue: audio only plays in the Listening pool. Every listening question needs a recording at `Resources/Audio/listening/<id>.m4a` (generated with `Tools/listening-audio`); `content-lint` fails without one. Re-render a question's file whenever its script changes.

Id conventions: `vocab.NNNN`, `grammar.NNNN` (level 1 from 0001, level 2 from 0101, level 3 from 0301, level 4 from 0401; TOPIK II vocabulary uses `vocab.3NNN` for level 3 and `vocab.4NNN` for level 4), `q.gf.NNNN` grammar fill-in, `q.sc.NNNN` sentence completion, `q.rc.NNNN` reading, `q.ls.NNNN` listening, `q.vm.<vocab id>` and `q.mw.<vocab id>` generated meaning questions.

## 4. Validation

`ContentFile.load` decodes `package.json` and the parts, converts to domain entities and runs every check in one pass, so an author sees all problems at once:

1. `formatVersion` supported; every file is valid JSON of the expected shape (the error names the file).
2. Field rules above: id charset, level range, non-empty romanization, complete examples, `answer` inside `options`.
3. `ContentPackage.validate()`: unique ids per kind, non-empty Korean, English and Khmer, 2 to 4 distinct options, exactly one correct option, every `vocabulary`, `grammar` and `related` reference resolves.

Any issue throws `ContentFile.Error.invalid([ContentPackageIssue])`. The app does not catch it: a broken bundle fails at launch, which the package test `BundledContentTests.testBundledLibraryLoadsAndValidates` catches first (AC-10).

## 5. Tooling

```
cd Packages/HanguStepKit
swift run content-lint                       # validate the bundled library, print counts per level and pending review
swift run content-lint generate-questions    # rewrite questions/generated-meaning.json and summary.json
swift run content-lint /path/to/other/dir    # validate any directory with the same layout
```

`generate-questions` builds two questions per word (Korean to meaning, meaning to Korean) with `MeaningQuestionGenerator`. Distractors prefer the same part of speech and level, never repeat a hangul or meaning, and the shuffle is seeded from the question id, so re-running on unchanged vocabulary produces an identical file and option order stays stable. Re-run it after every content change and commit the output; CI runs the lint and fails on a diff.

`summary.json` holds the counts, pending-review total and credits that Settings shows. On a warm launch the app reads only this file and `package.json`'s version: when the store already holds that version, the multi-megabyte library is not decoded. `content-lint` fails when the summary is missing or stale, and a bundled-content test checks it against the full library.

## 6. Shipping a content update

1. Edit or add part files. Bump `version` in `package.json`.
2. `swift run content-lint generate-questions`, then `swift run content-lint`.
3. `swift test` (bundled-content tests) and run the app once: the Settings screen shows the new version and counts.
4. Items removed from the library are retired, not deleted, on import (FR-C2). Learner attempts, bookmarks and schedules that point at retired items stay valid and readable.

## 7. Review workflow

Every item ships with `review: pending` until a native Khmer reviewer confirms the `km` fields. The Settings screen shows the pending count. Switch items to `reviewed` in the JSON; this does not require a version bump, since no stored field changes.

## 8. Not yet covered

Levels 3 to 6 (TOPIK II), listening content, audio assets, and importing packages from outside the bundle (download or file import). The format and loader already accept any directory, so these are content and transport work, not format changes.

## Writing prompts (ADR-012)

`writing/*.json` holds `{"tasks": [...]}`. They are read straight from the bundle (no Core Data import, no version bump needed) and validated by `content-lint`.

```json
{ "id": "w.53.001", "type": "describeData", "level": 4,
  "prompt": "다음을 참고하여 '...'에 대한 내용을 200~300자의 글로 쓰십시오. ...",
  "material": "조사 기관: ...\n1위 운동 42%\n...", "minLength": 200, "maxLength": 300,
  "modelAnswer": "...", "tips": { "en": "...", "km": "..." }, "review": "pending" }
```

- `type`: `shortAnswer` (51-52: `material` has `( ㉠ )` and `( ㉡ )`, `modelAnswer` has a `㉠ ...` and a `㉡ ...` line, no length), `describeData` (53), `essay` (54). 53 and 54 need `minLength`/`maxLength`, and the model answer must fall inside it.
- Length counts characters including spaces, excluding line breaks (`WritingText.characterCount`), like the TOPIK answer sheet.
- Survey data in 53 is invented and must name fictional organisations, never a real agency or company.
- Ids: `w.51.NNN`, `w.52.NNN`, `w.53.NNN`, `w.54.NNN`. Learner answers store the id, so never reuse one for a different prompt.

