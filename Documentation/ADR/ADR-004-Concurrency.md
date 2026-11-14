# ADR-004: Swift 6 strict concurrency with actor repositories and main-actor view models

Status: Accepted · 2026-11-02

## Context

Swift 6 language mode makes data races compile errors. Core Data contexts are not `Sendable`. SwiftUI state must be mutated on the main thread.

## Decision

- Domain entities are `Sendable` structs. They are the only types that cross isolation boundaries.
- In-memory repositories are actors. Core Data repositories are `Sendable` structs that own one background `NSManagedObjectContext` (itself `Sendable`) and run every operation inside `context.perform`, which already serializes access. They return domain structs, never managed objects. (Amended in Phase 3: an actor wrapping `perform` was a redundant second hop.)
- Use cases are `Sendable` structs with `async throws` methods.
- View models are `@MainActor @Observable`. Views trigger work with `.task`, which cancels automatically.
- `DateProvider` is injected wherever time is read.
- No `@unchecked Sendable`, no `nonisolated(unsafe)` without a comment and a reviewer.

## Consequences

- Every repository method is `async`, even in-memory ones. Small cost, uniform API.
- Core Data fetches for list screens may need pagination or `NSFetchedResultsController`-style streaming in Phase 3 to keep the main actor light.
