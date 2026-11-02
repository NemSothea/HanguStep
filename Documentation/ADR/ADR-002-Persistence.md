# ADR-002: Core Data with two stores, content separate from learner data

Status: Accepted · 2026-11-02 (implementation in Phase 3)

## Context

Content (vocabulary, grammar, questions) is authored, versioned and shipped with the app. Learner data (attempts, bookmarks, schedules) is personal and must sync. CloudKit mirroring should never upload the content library.

## Decision

- Core Data as the local database, accessed only inside the Persistence target.
- Two persistent stores in one container, separated by configuration:
  - `Content` store: not mirrored to CloudKit, replaced or updated on content import.
  - `Learner` store: mirrored to CloudKit from Phase 6.
- No Core Data relationships across the two stores. Learner records store content IDs as strings.
- Stable string IDs on every entity. Uniqueness enforced in repository code, not with Core Data constraints, because CloudKit does not support them.
- All relationships optional, no ordered relationships, no non-optional attributes without defaults, in line with `NSPersistentCloudKitContainer` requirements.
- Versioned model files from the first model; lightweight migration tested in CI.

## Alternatives considered

- SwiftData: simpler API, but CloudKit mirroring constraints are the same and the tooling is less mature on macOS 14. Core Data chosen for predictability; SwiftData can be reconsidered later.
- SQLite with GRDB: excellent but third-party, and loses the built-in CloudKit mirror.
- Content in JSON files read at runtime: slow search at 10 000 entries; import into Core Data instead.

## Consequences

- Repositories join content and learner data in memory. Acceptable for the data sizes in scope.
- Content updates cannot orphan learner records because the link is a string ID.
