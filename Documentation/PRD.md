# HanguStep — Product Requirements Document

Version 0.1 · 2026-11-02 · Phase 0 deliverable · Status: awaiting approval

---

## 1. Problem statement

A Khmer-speaking learner preparing for TOPIK needs daily, structured practice of Korean vocabulary and grammar with answers explained in a language they fully understand. Existing apps are English-centric, require a network connection, lock content behind subscriptions, and do not carry progress cleanly between iPhone and Mac. The learner also wants a single place to collect their own mistakes and revisit them on a schedule instead of re-reading whole word lists.

HanguStep solves this with an offline-first native Apple app that holds a TOPIK-structured vocabulary and grammar library with Korean, English and Khmer meanings, drills it through multiple-choice quizzes, records every answer, schedules reviews with spaced repetition, and syncs all learner data across the learner's devices through iCloud with no custom backend.

Secondary goal: the codebase is a portfolio-grade demonstration of Swift 6, Clean Architecture, Core Data and CloudKit engineering.

## 2. Target users and personas

### P1 — Sothea, the daily TOPIK candidate (primary)

- Native Khmer, fluent English, intermediate Korean. Target TOPIK II level 3 to 4.
- Studies 20 to 40 minutes a day, mostly on iPhone during commute, longer sessions on Mac in the evening.
- Wants: a fixed daily routine, quick quizzes, a mistake list that never gets lost, progress numbers that prove the routine is working.
- Pain: forgetting words seen last week, no Khmer glosses anywhere, progress trapped on one device.
- Also the developer and maintainer of this app.

### P2 — Dara, the beginner (secondary)

- Native Khmer, limited English. Starting Korean for work or study migration. Target TOPIK I level 1 to 2.
- Needs Khmer meanings as the primary gloss, simple navigation, large readable Hangul, pronunciation help.
- Studies on a single iPhone. May never enable iCloud.

### P3 — Alex, the English-speaking self-learner (tertiary)

- English native, no Khmer. Intermediate Korean. Uses the app for TOPIK II reading practice.
- Validates that the app works with Khmer hidden. Not an MVP focus but must not be blocked by design decisions.

Design rule derived from personas: the app must be fully useful on one device without iCloud (P2), and every piece of content must carry both English and Khmer so the preferred gloss is a setting, not a content fork (P1, P3).

## 3. Core learning features

| Feature | Description |
|---|---|
| Vocabulary library | Browse and search TOPIK-tagged words with hangul, romanization, part of speech, English and Khmer meaning, example sentences. |
| Vocabulary detail | Full entry, example sentences, pronunciation playback, bookmark toggle, personal note, mastery state. |
| Grammar lessons | Pattern, level, explanation in English and Khmer, example sentences, related patterns, practice questions. |
| Quiz engine | Multiple-choice sessions built from vocabulary, grammar or mixed pools, filtered by level and category. Immediate feedback with explanation. |
| Mistake review | Every incorrect answer collected into a reviewable list grouped by word or pattern. |
| Bookmarks | Mark any word or grammar item for later. |
| Progress dashboard | Totals, accuracy, daily and weekly activity, streak, weak items. |
| Spaced repetition | SM-2 scheduling of review items with a daily review queue. |
| Daily goal | Configurable target of questions or minutes per day. |
| iCloud sync | Learner data follows the Apple Account across devices. |
| Offline-first | Everything works with no network. Sync is background and eventual. |

## 4. User stories

Format: As a [persona], I want [goal] so that [benefit]. Priority: Must / Should / Could.

### Vocabulary

- US-01 (Must) As P1, I want to browse vocabulary filtered by TOPIK level and part of speech so that I study the right band of words.
- US-02 (Must) As P1, I want to search by hangul, English or Khmer so that I find a word from whichever side I remember.
- US-03 (Must) As P2, I want to see the Khmer meaning first so that I understand without relying on English.
- US-04 (Should) As P2, I want to hear the word pronounced so that I learn correct sounds.
- US-05 (Must) As P1, I want to bookmark a word so that I can return to it.
- US-06 (Could) As P1, I want to add a personal note to a word so that I store my own mnemonic.

### Grammar

- US-07 (Must) As P1, I want grammar patterns grouped by TOPIK level so that I progress in order.
- US-08 (Must) As P1, I want each pattern explained in English and Khmer with examples so that the nuance is clear.
- US-09 (Should) As P1, I want practice questions attached to a pattern so that I test it immediately.

### Quiz

- US-10 (Must) As P1, I want to start a quiz by level, category and length so that each session fits my available time.
- US-11 (Must) As P1, I want immediate feedback with an explanation after each answer so that I learn from the mistake while it is fresh.
- US-12 (Must) As P1, I want my unfinished quiz restored after relaunch so that an interruption costs nothing.
- US-13 (Must) As P1, I want a results screen with score and the list of wrong answers so that I know what to review.
- US-14 (Must) As P1, I want the app to refuse double submission of the same question so that my statistics are honest.

### Review and progress

- US-15 (Must) As P1, I want all my wrong answers in one list so that I review weaknesses, not everything.
- US-16 (Must) As P1, I want a daily review queue chosen by spaced repetition so that I revisit items just before I forget them.
- US-17 (Must) As P1, I want to see accuracy, totals, streak and weekly activity so that I can tell the routine is working.
- US-18 (Should) As P1, I want a daily goal with a visible completion state so that I stay consistent.
- US-19 (Should) As P1, I want the app to identify my weakest words and patterns so that I target them.

### Sync and platform

- US-20 (Must) As P1, I want progress made on iPhone to appear on Mac so that I continue where I stopped.
- US-21 (Must) As P1, I want to study offline and have changes sync later so that connectivity never blocks study.
- US-22 (Must) As P2, I want the app fully functional without iCloud so that sync is optional.
- US-23 (Should) As P1, I want to see sync status and last successful sync so that I trust the data.
- US-24 (Must) As P1, I want the same app on iPad and Mac with layouts suited to the screen so that longer sessions are comfortable.

### Content and settings

- US-25 (Must) As P1, I want to choose which gloss language is shown first so that the app fits my level.
- US-26 (Should) As P1, I want content updates that do not reset my progress so that I keep my history across versions.
- US-27 (Could) As P1, I want AI-generated extra practice later so that I get unlimited variations. Future phase.

## 5. Functional requirements

Each requirement is testable and traceable to user stories.

### FR-V Vocabulary

- FR-V1 Store vocabulary entries with: stable id, hangul, romanization, part of speech, TOPIK level (1 to 6), topic category, English meaning, Khmer meaning, zero or more example sentences (Korean, English, Khmer), optional hanja, content version.
- FR-V2 List vocabulary with filters for level, part of speech, category, bookmarked, mastery state. Filter changes apply within 100 ms on a 10 000 entry library.
- FR-V3 Search matches hangul (prefix and substring), romanization, English and Khmer text. Khmer search must handle Unicode normalization.
- FR-V4 Detail view shows all fields and example sentences, with bookmark toggle and personal note.
- FR-V5 Pronunciation plays through on-device Korean text-to-speech (AVSpeechSynthesizer, ko-KR). No network.

### FR-G Grammar

- FR-G1 Store grammar patterns with: stable id, pattern text, TOPIK level, category, explanation (English, Khmer), formation rules, example sentences, related pattern ids, content version.
- FR-G2 List grammar by level and category; detail view shows explanation, examples and attached practice questions.
- FR-G3 Grammar items support bookmarks and notes identically to vocabulary.

### FR-Q Quiz

- FR-Q1 Store questions with: stable id, type (vocabulary meaning, meaning to word, grammar fill-in, sentence completion, reading comprehension), prompt text, optional passage, 2 to 4 options, exactly one correct option, explanation (English, Khmer), level, source reference, content version.
- FR-Q2 Build a quiz session from parameters: pool (vocabulary, grammar, mixed, mistakes, review queue), level filter, question count (5, 10, 20, 40), shuffle options.
- FR-Q3 Present one question at a time. Accept exactly one answer per question. A second submission for the same question in the same session is rejected and logged.
- FR-Q4 Record every answer as an attempt: session id, question id, selected option, correct flag, timestamp, response time.
- FR-Q5 Show immediate feedback: correct or incorrect, correct option highlighted, explanation in the selected gloss language with a toggle to the other.
- FR-Q6 Persist session state after every answer. On relaunch, an unfinished session is offered for resumption or discard.
- FR-Q7 Results screen: score, accuracy, time, list of incorrect questions with links to the related vocabulary or grammar item.
- FR-Q8 Questions with invalid content (no correct option, duplicate options, empty prompt) are excluded from session generation and reported in diagnostics.
- FR-Q9 If the pool has fewer questions than requested, the session uses what exists and tells the user.

### FR-R Review and spaced repetition

- FR-R1 Every incorrect attempt adds or updates a mistake record for the underlying vocabulary or grammar item with a counter and last-missed date.
- FR-R2 Mistake list sorted by most recently missed and by frequency; clearing a mistake requires N consecutive correct answers (default 2).
- FR-R3 Each learned item has a review schedule record: ease factor, interval, repetitions, next review date, computed by SM-2.
- FR-R4 Daily review queue = items with next review date on or before today, ordered by overdue days, capped by a configurable daily limit (default 50).
- FR-R5 Missed days do not reset schedules; overdue items are prioritized. Streak logic is separate from scheduling.
- FR-R6 Scheduling is a pure function of (previous schedule, answer quality, today) so that it is deterministic and unit-testable.

### FR-P Progress

- FR-P1 Study session record: start, end, device, question count, correct count, mode.
- FR-P2 Dashboard metrics: total questions answered, correct and incorrect, accuracy, questions today, minutes today, 7-day and 30-day activity, current and longest streak, items due today, items mastered.
- FR-P3 Streak = consecutive calendar days (device local time zone) with at least one answered question or completed review. Day boundary rules documented.
- FR-P4 Weak items = items with accuracy below 60 percent over at least 3 attempts.
- FR-P5 Daily goal: user sets questions per day or minutes per day; dashboard shows progress toward goal.
- FR-P6 Metrics are computed from attempt records, never incremented separately, so duplicates cannot drift totals.

### FR-S Sync

- FR-S1 All learner data (attempts, sessions, mistakes, schedules, bookmarks, notes, settings) lives in Core Data and syncs via NSPersistentCloudKitContainer to the private CloudKit database.
- FR-S2 Content (vocabulary, grammar, questions) ships in the app bundle and is loaded into a local, non-synced store. Content is not uploaded to CloudKit.
- FR-S3 The app is fully functional when iCloud is unavailable, disabled, or the user is signed out. Local data is preserved.
- FR-S4 UI refreshes when remote changes are imported.
- FR-S5 Settings screen shows: iCloud account state, sync enabled, last successful import or export time, last error if any.
- FR-S6 Conflict policy per entity documented in Phase 6 (see Section 11 risk R3). Default: attempts are append-only and never conflict; schedules resolve to the record with the latest review date; bookmarks resolve to the latest modification.
- FR-S7 Learner records reference content by stable content id, never by Core Data object id, so content can be re-imported without orphaning progress.

### FR-C Content management

- FR-C1 Content is imported from a versioned JSON format defined in Phase 7. Import validates schema, uniqueness of ids, presence of correct options, and non-empty Korean, English and Khmer fields.
- FR-C2 Content updates are additive by id. Changed entries are updated; removed entries are soft-deleted so attempts remain valid.
- FR-C3 Every content item records a source and license field.

### FR-X Settings and localization

- FR-X1 Settings: primary gloss language (English or Khmer), daily goal, review limit, pronunciation on or off, sync toggle, reset local data with confirmation.
- FR-X2 App UI localized in English first. Khmer UI localization planned (Could). Korean content text is always shown in Korean.
- FR-X3 Fonts render Hangul and Khmer script correctly on all three platforms using system fonts.

### FR-A AI assistant (future, Phase 8, not MVP)

- FR-A1 Optional, behind an abstraction, mock provider first.
- FR-A2 Generated content validated and stored with provenance before it is shown as a question.
- FR-A3 No credentials in the app bundle.

## 6. Non-functional requirements

| Id | Category | Requirement |
|---|---|---|
| NFR-1 | Platform | iOS 17, iPadOS 17, macOS 14 and later. Universal purchase, single codebase. |
| NFR-2 | Offline | Every learner-facing feature works with network disabled. Verified in QA. |
| NFR-3 | Performance | Cold launch to interactive dashboard under 1.5 s on iPhone 12. Quiz answer feedback under 100 ms. Vocabulary search under 150 ms for 10 000 entries. |
| NFR-4 | Data integrity | No duplicate attempts for one question in one session. Statistics derived from attempts only. Content ids stable across versions. |
| NFR-5 | Sync | Eventual consistency accepted. Local write never blocked by sync. Sync failure never loses local data. |
| NFR-6 | Privacy | No analytics SDK in MVP. No third-party network calls. Learner data only in the user's private CloudKit database. |
| NFR-7 | Security | No secrets in bundle. Future AI calls go through a proxy or user-supplied key stored in Keychain. |
| NFR-8 | Accessibility | Dynamic Type up to accessibility sizes, VoiceOver labels on all controls, sufficient contrast in light and dark, reduced-motion respected. |
| NFR-9 | Localization | English UI; Korean and Khmer content; architecture ready for Khmer UI. |
| NFR-10 | Testability | Domain and use case layers at 80 percent line coverage. Repositories tested against in-memory Core Data. Scheduling algorithm 100 percent. |
| NFR-11 | Maintainability | Clean Architecture boundaries enforced by package or target separation. No business logic in views. Documented ADRs. |
| NFR-12 | Dependencies | Zero third-party runtime dependencies in MVP. |
| NFR-13 | Binary size | Bundled content under 20 MB. |
| NFR-14 | CI | GitHub Actions builds and runs unit tests on every pull request. |

## 7. MVP versus future features

### MVP (release M1 + M2)

- Vocabulary library with search, filters, detail, bookmarks, notes, TTS pronunciation
- Grammar library with explanations and examples
- Multiple-choice quiz engine with feedback, resume, results
- Mistake collection and review
- SM-2 spaced repetition with daily review queue
- Progress dashboard, streak, daily goal
- iCloud sync of learner data
- Bundled TOPIK I and II vocabulary and grammar content with English and Khmer
- English UI, light and dark mode, iPhone, iPad, Mac layouts

### Future (post MVP)

- AI assistant: generated questions, explanations, writing feedback (Phase 8)
- Listening practice with audio clips
- Writing practice (TOPIK II 쓰기) with self-assessment or AI feedback
- Reading passages with timed mode
- Khmer UI localization
- Handwriting or typing input for recall-type questions
- Widgets and Live Activities for daily goal
- Shared or community content packs
- Apple Watch companion
- Import of user-created word lists (CSV)
- Mock exam mode with TOPIK timing

### Explicitly out of scope

- Custom backend or accounts other than Apple Account
- Social features, leaderboards
- Official TOPIK past papers (licensing). Questions are TOPIK-style, never claimed official.
- Android or web

## 8. User journeys

### J1 Daily routine (P1, iPhone, morning)

1. Open app. Dashboard shows streak 12, goal 0 of 20, 14 items due.
2. Tap Review. Review queue session of 14 questions starts.
3. Answers each; wrong answers show explanation in Khmer with English toggle.
4. Session ends. Results: 11 of 14. Two items scheduled again for tomorrow, rest pushed out.
5. Dashboard updates: goal 14 of 20, streak 12 stays (today counted).
6. Tap Quick Quiz, level 3, vocabulary, 10 questions. Completes. Goal reached, streak remains 12 until midnight passes, then 13 tomorrow if continued.
7. Phone goes in pocket. Sync exports in background when network available.

### J2 Continue on Mac (P1, evening)

1. Open app on Mac. Sync imports morning attempts within a short time of launch.
2. Dashboard shows the same numbers as the phone.
3. Opens Mistakes. Sees the morning's two misses.
4. Opens grammar lesson linked from a miss, reads full explanation, bookmarks it.
5. Next morning the bookmark is on the phone.

### J3 Offline flight (P1)

1. Airplane mode. Starts a 40-question mixed quiz.
2. Halfway, app is killed by the system.
3. Relaunch offers to resume. Resumes at question 21. Previous 20 answers intact.
4. Completes. Everything saved locally.
5. Landing, network returns. Sync exports. Mac later shows the session.

### J4 First launch, no iCloud (P2)

1. Installs app, iCloud disabled on device.
2. Onboarding asks: primary meaning language → Khmer. Daily goal → 10.
3. Settings shows "iCloud unavailable. Your progress is saved on this device."
4. Browses level 1 vocabulary, taps a word, hears pronunciation, reads Khmer meaning.
5. Starts a 5-question level 1 quiz. Completes. Progress saved.

### J5 Two devices edit before sync (P1)

1. iPhone offline: answers 10 review questions.
2. Mac online: bookmarks 3 words.
3. iPhone reconnects. Both devices converge: attempts appended, bookmarks present, schedules reflect iPhone's reviews since they carry later review dates.
4. No duplicate attempts, no lost bookmarks.

### J6 Content update (P1)

1. App update ships content version 3 with 200 new words and 5 corrected meanings.
2. On launch, import runs. New words added, corrected words updated in place by id.
3. All attempts, schedules and bookmarks remain attached.

## 9. Screen inventory

| # | Screen | Purpose | Platforms |
|---|---|---|---|
| S1 | Onboarding | Gloss language, daily goal, iCloud explanation | All |
| S2 | Dashboard | Streak, goal, due items, quick actions, weekly activity | All |
| S3 | Vocabulary list | Search, filters, list | All (sidebar + detail on iPad/Mac) |
| S4 | Vocabulary detail | Entry, examples, TTS, bookmark, note | All |
| S5 | Grammar list | Levels and categories | All |
| S6 | Grammar detail | Explanation, examples, practice | All |
| S7 | Quiz setup | Pool, level, count | All |
| S8 | Quiz question | Prompt, options, feedback | All |
| S9 | Quiz results | Score, misses, links | All |
| S10 | Mistake review | Grouped misses, start review | All |
| S11 | Review queue | Due items, start session | All |
| S12 | Progress | Statistics, charts, weak items | All |
| S13 | Bookmarks | Saved items | All |
| S14 | Settings | Preferences, sync status, data reset, about | All |
| S15 | Sync status detail | Account state, last sync, errors | All |

Navigation: tab bar on iPhone (Home, Learn, Quiz, Review, Progress). Split view with sidebar on iPad and Mac. Settings via toolbar or sidebar item.

## 10. Acceptance criteria (MVP)

- AC-1 With network disabled, a new user can complete onboarding, browse vocabulary, hear pronunciation, run a quiz, see results, see dashboard update. No error shown.
- AC-2 Killing the app mid-quiz and relaunching restores the session at the same question with all prior answers.
- AC-3 Submitting an answer twice for one question creates exactly one attempt record.
- AC-4 Dashboard totals equal a direct count of attempt records in the store.
- AC-5 Given a schedule with known inputs, SM-2 output matches the published reference values in unit tests.
- AC-6 A quiz answered on iPhone appears in Mac dashboard after sync with identical totals. Verified on real devices.
- AC-7 A bookmark made on Mac appears on iPhone after sync.
- AC-8 Signing out of iCloud keeps all local data visible and usable. Signing back in resumes sync without duplicates.
- AC-9 Importing a newer content version preserves all attempts, schedules, bookmarks and notes.
- AC-10 Every content item in the bundle passes validation: unique id, non-empty Korean, English and Khmer, exactly one correct option per question.
- AC-11 VoiceOver can complete a full quiz. Dynamic Type at largest accessibility size does not clip Hangul or Khmer.
- AC-12 Unit tests pass in CI on every pull request. Domain coverage at or above 80 percent.
- AC-13 Cold launch under 1.5 s measured with Instruments on iPhone 12 class device.
- AC-14 Zero third-party runtime dependencies in the MVP build.

## 11. Technical and product risks

| Id | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | Content quality: Khmer translations wrong or inconsistent | High | High | Validation pipeline, source and reviewer fields per entry, user-facing "report" note in future, start with a curated subset (level 1 to 3) and grow. |
| R2 | CloudKit schema constraints: no uniqueness constraints, all relationships optional, no ordered relationships | Certain | Medium | Design Core Data model for CloudKit from Phase 3. Uniqueness enforced in domain layer by stable ids and dedupe on import. |
| R3 | Sync conflicts producing duplicate or stale learner records | Medium | High | Append-only attempts. Per-entity merge policy. Deduplicate schedules by content id after import. Test scenario J5 on real devices. |
| R4 | Two stores (bundled content + synced learner data) complicate relationships | Certain | Medium | No Core Data relationships across stores. Learner records hold content ids as strings. Repositories join in memory. |
| R5 | Swift 6 strict concurrency with Core Data contexts | High | Medium | Actor-isolated repository layer, Sendable DTOs crossing boundaries, no managed objects leave the persistence layer. |
| R6 | Scope creep from AI features | Medium | High | AI gated to Phase 8 behind protocol. Mock provider only until MVP ships. |
| R7 | Khmer and Hangul rendering issues (line breaking, fonts) on macOS | Medium | Medium | Test on all platforms early in Phase 2 with real strings. |
| R8 | Licensing of vocabulary lists | Medium | High | Use public-domain or openly licensed word lists (for example the National Institute of Korean Language learner vocabulary list), self-authored examples, record license per item. Never ship official exam questions. |
| R9 | Solo developer time | High | Medium | Strict phase order, MVP cut at Phase 5 usable on one device. |
| R10 | iCloud quota or account issues in the field | Low | Low | Sync status screen, local-first behavior, clear messaging. |
| R11 | Core Data lightweight migration failing after schema change | Medium | High | Versioned models from Phase 3, migration tests in CI. |

## 12. Release milestones

| Milestone | Phases | Definition of done |
|---|---|---|
| M1 Offline MVP | 0 to 5 | AC-1 to AC-5, AC-10 to AC-14 pass. Daily use by P1 on one device. |
| M2 Sync + content | 6, 7 | AC-6 to AC-9 pass on real iPhone and Mac. Full level 1 to 6 content imported. |
| M3 Assistant | 8 | Mock provider complete, real provider behind feature flag. |
| M4 Store | 9 to 11 | QA, security, TestFlight, App Store submission ready. |

## 13. Key decisions requested from the product owner

The following were assumed to keep Phase 0 moving. Confirm or change before Phase 1.

| # | Question | Assumption used |
|---|---|---|
| Q1 | Your current level and target? | Intermediate, target TOPIK II level 3 to 4. Content priority: levels 1 to 4 first. |
| Q2 | UI language? | English UI in MVP. Khmer UI later. Khmer always present in content. |
| Q3 | Pronunciation: on-device TTS or recorded audio? | TTS (AVSpeechSynthesizer ko-KR). No audio files in MVP. |
| Q4 | Listening and writing sections in MVP? | No. Vocabulary, grammar, reading-style MCQ only. |
| Q5 | Who writes Khmer translations? | You, with AI-assisted drafts reviewed by you. Each entry tagged with reviewer status. |
| Q6 | Question type for MVP: multiple choice only? | Yes. Typed recall is future. |
| Q7 | Single learner per Apple Account? | Yes. No profiles. |
| Q8 | Sync only learner data, content bundled? | Yes. Content never in CloudKit. |
| Q9 | Daily goal unit? | Questions per day, default 20. Minutes as alternative. |
| Q10 | Free app, no monetization? | Yes for now. No IAP code in MVP. |

## 14. Prioritized MVP backlog

Ordered. Each item maps to a phase.

1. Project skeleton, Clean Architecture targets, DI, CI build (Phase 1)
2. Design tokens, core components, adaptive navigation shell (Phase 2)
3. Core Data model: content store and learner store, repositories, migrations, in-memory test stack (Phase 3)
4. Seed content: 300 words, 30 grammar patterns, 200 questions, levels 1 to 3, with Khmer (Phase 3)
5. Vocabulary list, search, detail, bookmark, note, TTS (Phase 4)
6. Grammar list and detail (Phase 4)
7. Quiz session use cases: build, answer, persist, resume, score (Phase 4)
8. Quiz UI: setup, question, feedback, results (Phase 4)
9. Mistake collection and mistake review (Phase 4)
10. Attempt-derived statistics and dashboard (Phase 5)
11. SM-2 scheduler and review queue (Phase 5)
12. Streak and daily goal (Phase 5)
13. NSPersistentCloudKitContainer, sync status, conflict handling, device tests (Phase 6)
14. JSON content format, validator, versioned import, full level 1 to 6 content (Phase 7)
15. Accessibility and localization pass (Phase 9)

---

Approval needed to begin Phase 1: Technical Architecture.
