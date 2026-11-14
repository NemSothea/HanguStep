# HanguStep QA Report

Phase 9 · 2026-11-04, re-verified and approved 2026-11-07 · Candidate: `develop` after Phase 8, version 1.0.0 (build 1)

Scope: everything in PRD §10 (AC-1 to AC-14) and §6 (NFR-1 to NFR-14) that can be verified on this machine, plus a visual and accessibility pass on the iPhone simulator. Device-only checks are listed with their status, not claimed.

## 1. Summary

| Area | Result |
|------|--------|
| Package unit tests | 151 tests, 0 failures, 1 skipped (CloudKit live test) |
| Line coverage | Domain 93 %, Persistence 83 %, Assistant 84 % (AC-12 target 80 %). SM-2 97 % |
| UI flows (iPhone 16 simulator) | 3 flows pass: quiz round trip + history, learn/search/bookmark/grammar, assistant explain + generate |
| Accessibility audit at AccessibilityXXXL | 10 screens, 0 persistent issues; full UI suite green 3 runs out of 3 (2026-11-07) |
| Static checks | No force unwrap, `try!`, `as!` or `fatalError` in production sources; zero third-party dependencies; content 488 KB |
| Performance proxies (Mac host) | Search over 10 000 words 58 ms worst case (limit 150 ms); answer feedback < 1 ms (limit 100 ms) |
| Builds | iOS Simulator and macOS succeed; CI runs package tests, content lint, both builds |
| Open | Device-only criteria (AC-1 airplane mode, AC-6 to AC-8 sync, AC-13 cold launch, VoiceOver walkthrough), Khmer review of content, TOPIK II content |

Verdict: release-candidate quality for an offline single-device TestFlight build. Not App Store ready until the device checks in §5 are done.

## 2. Acceptance criteria

| AC | Status | Evidence |
|----|--------|----------|
| AC-1 Offline first run | Partial | UI tests run with sync off and no network use; airplane-mode device run pending (§5) |
| AC-2 Resume mid-quiz | Pass | `ResumeQuizSession` + `MigrationTests.testOnDiskStoresOpenAndPersistAcrossRelaunch`; dashboard resume card in `testQuizRoundTripAndHistory` |
| AC-3 One attempt per question | Pass | `SubmitAnswer` duplicate guard, `QuizUseCaseTests`, `CoreDataRepositoryTests` |
| AC-4 Dashboard totals = attempt count | Pass | `LoadDashboardSummaryTests`, `ProgressStatisticsTests` (derived from attempts only) |
| AC-5 SM-2 reference values | Pass | `SM2Tests` pins intervals and ease factors; 97 % line coverage |
| AC-6 to AC-8 Sync on devices | Open | Needs two devices and a team id (`CLOUDKIT_SYNC.md` §8); sync code covered by `SyncTests` |
| AC-9 Content upgrade keeps learner data | Pass | `BundledContentTests.testBundledLibraryReplacesSampleDataAndKeepsAttempts`, `GeneratedQuestionStoreTests` |
| AC-10 Bundle validates | Pass | `BundledContentTests`, `content-lint` in CI: 230 words, 40 patterns, 530 questions, 0 issues |
| AC-11 VoiceOver + largest Dynamic Type | Partial | `AccessibilityUITests` audit at XXXL (labels, traits, clipping, contrast) passes; manual VoiceOver walkthrough pending |
| AC-12 CI tests, Domain ≥ 80 % | Pass | CI workflow; Domain 93 % |
| AC-13 Cold launch < 1.5 s | Open | Needs Instruments on a device |
| AC-14 Zero third-party dependencies | Pass | `Package.swift` has no external packages; `project.yml` only the local package |

## 3. Non-functional requirements

| NFR | Status | Note |
|-----|--------|------|
| NFR-1 Platforms | Pass | iOS 17 / macOS 14 deployment targets; both build |
| NFR-2 Offline | Partial | No network call without the assistant enabled with Claude; airplane-mode run pending |
| NFR-3 Performance | Partial | Host proxies pass; device launch pending |
| NFR-4 Data integrity | Pass | Duplicate guard, derived statistics, stable authored ids |
| NFR-5 Sync | Pass (code) | Local writes never wait for CloudKit; device verification pending |
| NFR-6 Privacy | Pass | No analytics, one optional opt-in destination (SECURITY.md §3) |
| NFR-7 Security | Pass | Key in Keychain only (`KeychainSecretStore`), nothing in bundle |
| NFR-8 Accessibility | Pass after fixes | See §4 |
| NFR-9 Localization | Partial | All UI strings are `LocalizedStringKey`; no string catalog yet. Khmer UI needs a catalog in the Features target and `bundle: .module` lookups |
| NFR-10 Testability | Pass | Domain 93 %, SM-2 97 % (two unreachable lines) |
| NFR-11 Maintainability | Pass | Six SwiftPM targets with enforced imports; ADR-001 to ADR-008 |
| NFR-12 Dependencies | Pass | None |
| NFR-13 Binary size | Pass | Content 488 KB |
| NFR-14 CI | Pass | Tests, lint, iOS and macOS builds on every pull request |

## 4. Defects found and fixed in this phase

| # | Found by | Defect | Fix |
|---|----------|--------|-----|
| 1 | Screenshot review | Three-line quiz prompts lost their first line (`HangulText` two-line limit) | No line limit; title size for sentence, grammar and reading prompts |
| 2 | Screenshot review | Empty band between the quiz toolbar and the progress bar | Inline navigation title mode |
| 3 | Audit | Secondary text under 4.5:1 (captions, glosses) | `textSecondary` asset `#55555E` / `#A6A6AF` |
| 4 | Audit | Level chips and badges under 4.5:1 with white text; white text on pale dark-mode tints | Darker light tints; `onTint` text colour |
| 5 | Audit | "0/20", "Goal", "Due today" wrapped per character at XXXL | One-column tile grid and vertical tiles at accessibility sizes |
| 6 | Audit | Option number pushed out of the row, text squeezed at XXXL | Vertical option layout at accessibility sizes |
| 7 | Audit | Dimmed options and disabled buttons faded below contrast | Colour swap instead of opacity |
| 8 | Audit | "Correct", "Perfect round" in `success` green under 4.5:1 | `success` `#15803D`, `danger` `#B91C1C` |
| 9 | Audit | Settings language picker clipped its value at XXXL | Inline picker at accessibility sizes |
| 10 | Audit | Quiz progress bar reported as a too-small hit target | Hidden from accessibility; the toolbar text carries the progress |
| 11 | Code review | Settings showed a hard-coded version | Read from the bundle; `Info.plist` uses `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` |
| 12 | Coverage | `ListMistakes` and the weak-item join untested | `ListMistakesTests`, `LoadProgressReportTests` |
| 13 | Re-verification | Level 1 to 3 chip text 4.41 to 4.49:1 on the grouped background | Light values `#166534`, `#3F6212`, `#854D0E` (6.1 to 6.4:1) |
| 14 | Re-verification | Settings "Show meanings first in" header in system grey, about 3:1 | `textSecondary` |
| 15 | Screenshot review | Vocabulary row squeezed the meaning to a few letters per line at XXXL | Row stacks vertically at accessibility sizes |
| 16 | Audit | VoiceOver read fill-in blanks (`______`) as underscores | Spoken as "빈칸"; `HangulText.spokenForm(of:)` with unit test |

### Audit method

The contrast check samples pixels and gave different results run to run (level chips at 5.8:1 flagged once, then not). The test now waits for content and transitions before each pass, runs the audit up to three times per screen, and fails only on issues found in every pass. Exemptions, all documented in `AccessibilityUITests`: navigation-bar items and unaddressable system controls for Dynamic Type; text under the tab bar or quiz action bar; contrast issues with no element (system chrome; our text is always an element).

## 5. Open items (owner: product owner, on devices)

1. Airplane-mode first run on iPhone: onboarding, browse, pronounce, quiz, dashboard (AC-1).
2. Two-device CloudKit run per `CLOUDKIT_SYNC.md` §8 (AC-6 to AC-8). Needs `Configs/Signing.local.xcconfig`.
3. Cold launch with Instruments on an iPhone 12-class device (AC-13).
4. VoiceOver: complete one quiz by swiping; confirm the option labels "Option 1, …" and the feedback card read in order.
5. Khmer review of the 800 pending content items; Khmer rendering on a physical Mac and iPad (R7).
6. TOPIK II content (levels 3 to 6), PRD backlog item 14.
7. String catalog for the Features target if a Khmer UI is wanted (NFR-9).

## 6. Release candidate

- Version 1.0.0, build 1, set in `project.yml`; shown in Settings from the bundle.
- Branch `develop` after this phase. `main` still at Phase 1; merging develop into main is the release decision.
- Signing: not configured in the repository by design (`Configs/Signing.local.xcconfig`, git-ignored).
- Known gaps carried into Phase 10 (security review) and Phase 11 (release): §5 above, privacy manifest, App Store metadata, screenshots.
