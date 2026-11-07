# HanguStep Testing Strategy

Version 1.0 · Phase 9 · Status: current as of 2026-11-04

What is tested where, how it runs, and what is deliberately left to manual or device checks. Numbers come from the Phase 9 QA run (`QA_REPORT.md`).

## 1. Layers and tools

| Layer | Test target | Runs against | Tool | Gate |
|-------|-------------|--------------|------|------|
| Domain (entities, use cases, SM-2, mistake derivation, content format, assistant use cases, mock provider) | `DomainTests` | In-memory repositories from Persistence | XCTest, `swift test` | Line coverage ≥ 80 % (AC-12, NFR-10), SM-2 ≥ 95 % |
| Persistence (Core Data repositories, importer, generated store, sync monitor, migrations, bundled library) | `PersistenceTests` | In-memory `NSPersistentContainer` plus on-disk fixtures under `Tests/PersistenceTests/Fixtures` | XCTest | Every repository method; one fixture per shipped model version |
| Assistant (Claude provider wire format, error mapping) | `AssistantTests` | `StubTransport`, never the network | XCTest | Request shape, every error class |
| Features (view models, settings model, preferences) | `FeaturesTests` | Real use cases over in-memory repositories | XCTest, `@MainActor` | Every view model state transition |
| DesignSystem (tokens) | `DesignSystemTests` | — | XCTest | Smoke |
| Screens (navigation, quiz loop, learn, bookmarks, assistant flow) | `HanguStepUITests` | iPhone simulator, `--ui-testing` launch argument (fresh learner store, sync off, in-memory secrets) | XCUITest | Flows below pass; screenshots attached |
| Accessibility (AC-11, NFR-8) | `AccessibilityUITests` | Same, at `UICTContentSizeCategoryAccessibilityXXXL` | `XCUIApplication.performAccessibilityAudit` on 10 screens | No audit issues |
| Performance proxies (NFR-3) | `PerformanceTests` in `PersistenceTests` | 10 000 synthetic words in memory | XCTest timing | Search < 150 ms, feedback < 100 ms on the Mac host |
| Content (AC-10) | `BundledContentTests` + `content-lint` | The bundled JSON | XCTest + CLI | Zero validation issues, generated file not stale |

Views themselves are not unit-tested: SwiftUI bodies carry layout only (CODING_STANDARDS §Layering), so UI tests and the accessibility audit cover them.

## 2. Commands

```
cd Packages/HanguStepKit && swift test                               # all package tests, ~10 s
cd Packages/HanguStepKit && swift test --enable-code-coverage         # then llvm-cov, see §5
cd Packages/HanguStepKit && swift run content-lint                    # content validation
xcodebuild build -project HanguStep.xcodeproj -scheme HanguStep -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project HanguStep.xcodeproj -scheme HanguStep -destination 'platform=macOS' CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO
xcodebuild clean build-for-testing -project HanguStep.xcodeproj -scheme HanguStep -destination 'id=<simulator>' CODE_SIGNING_ALLOWED=NO
TEST_RUNNER_HANGUSTEP_SCREENSHOT_DIR=/path xcodebuild test-without-building -project HanguStep.xcodeproj -scheme HanguStep -destination 'id=<simulator>' -only-testing:HanguStepUITests
```

Known gotcha: the simulator can keep a stale UI test runner. When a UI test fails on a line that no longer matches the source, `xcrun simctl uninstall <sim> com.nemsothea.hangustep.uitests.xctrunner`, then `clean build-for-testing` and `test-without-building`.

## 3. CI

`.github/workflows/ci.yml` on every pull request and on pushes to `main` and `develop`:

1. `swift test --parallel` (all five package test bundles).
2. `content-lint generate-questions` followed by `git diff --exit-code` on the content directory.
3. iOS Simulator app build.
4. macOS app build.

UI tests and the accessibility audit are not in CI: they take about three minutes on a simulator and are run locally before each phase is approved. Moving them to CI is a Phase 11 decision.

## 4. Fixtures and test data

- `SampleContent` (Persistence): ten words, two patterns, seven questions. The fixture for every unit test; never shipped.
- `Tests/PersistenceTests/Fixtures/Learner-v1.sqlite`: learner store written by model v1; `MigrationTests` opens it with the current model. Add one per model version (DATABASE_SCHEMA §7).
- `--ui-testing`: `AppContainer` uses a scratch store directory wiped on launch, sync off, in-memory assistant secrets, cleared assistant settings.
- Deterministic helpers: `IdentityShuffler`, `FixedDateProvider`, counting id generators, `MockAssistantProvider`.

## 5. Coverage measurement

```
cd Packages/HanguStepKit && swift test --enable-code-coverage
D=.build/out/Products/Debug
xcrun llvm-cov report $D/DomainTests.xctest/Contents/MacOS/DomainTests \
  -object $D/PersistenceTests.xctest/Contents/MacOS/PersistenceTests \
  -object $D/FeaturesTests.xctest/Contents/MacOS/FeaturesTests \
  -object $D/AssistantTests.xctest/Contents/MacOS/AssistantTests \
  -instr-profile $D/codecov/default.profdata -ignore-filename-regex='Tests/|\.build/|ContentLint/'
```

Targets: Domain ≥ 80 % lines (AC-12), Persistence ≥ 75 %, Assistant ≥ 80 %. Features and DesignSystem are dominated by SwiftUI bodies and are judged by the UI suite, not by line coverage.

## 6. Manual and device checks

Not automatable here; tracked in `QA_REPORT.md` with owner and status:

- AC-1 offline run on a device with airplane mode.
- AC-6 to AC-8 two-device CloudKit sync (`CLOUDKIT_SYNC.md` §8).
- AC-13 cold launch with Instruments on an iPhone 12-class device.
- VoiceOver walkthrough of a full quiz (the automated audit checks labels and traits; it cannot drive VoiceOver).
- Khmer and Hangul rendering on a physical Mac and iPad.

## 7. Adding a feature

1. Domain use case with tests over in-memory repositories.
2. Repository method with a Core Data test (and in-memory counterpart).
3. View model test for each state transition.
4. Extend a UI test flow or add one; add the screen to `AccessibilityUITests` if it is a new top-level screen.
5. Run the commands in §2; attach numbers to the phase report.
