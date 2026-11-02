# Coding Standards

## Language

- Swift 6, language mode 6, strict concurrency complete. Warnings are errors in spirit: fix them before review.
- No force unwrap or `try!` outside tests and previews. No `fatalError` in production paths.
- Prefer `struct` and `enum`. Classes only for view models (`@Observable`) and framework-required cases.
- `public` only on what another target needs. Default to internal.
- Typed identifiers (`VocabularyID`, not `String`).

## Naming

- Entities: nouns (`VocabularyItem`). Use cases: verb phrases (`LoadDashboardSummary`), protocol suffixed `UseCase`.
- Repositories: `XRepository` protocol, implementations prefixed by technology (`InMemoryXRepository`, `CoreDataXRepository`).
- View models: `XViewModel`. Views: `XView`. One screen per folder.
- Test methods: `testWhatIsVerifiedUnderWhichCondition`.

## Layering

- Views contain layout only. No `if level.rawValue > 2` business rules in SwiftUI.
- View models hold presentation state and translate user intent into use-case calls.
- Use cases hold business rules and orchestration.
- Repositories hold storage logic and mapping. They know nothing about screens.

## Localization and text

- All user-visible strings go through `LocalizedStringKey` or `String(localized:)`.
- Korean, English and Khmer content strings come from data, never from code.
- Normalize text with `TextNormalizer` before comparing or searching.

## Accessibility

- Every interactive control has a label. Images that carry meaning have descriptions.
- Support Dynamic Type; never fix a frame height on text.

## Tests

- XCTest. Domain and use case tests have no framework dependencies.
- Repository tests run against in-memory stores.
- View model tests are `@MainActor` and use stub use cases.
- A bug fix comes with a regression test.

## Git

- Conventional commits: `feat(quiz): ...`, `fix(sync): ...`, `docs: ...`, `test: ...`, `chore: ...`.
- No Co-Authored-By trailers, no generated-with lines.
- Commit only after `swift test` and both platform builds pass.

## Tooling

- `project.yml` is the source of truth; regenerate with `xcodegen generate` after changing targets or settings, then commit both.
- No third-party runtime dependencies without an ADR.
