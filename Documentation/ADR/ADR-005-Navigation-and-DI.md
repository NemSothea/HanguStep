# ADR-005: Value-based navigation and manual dependency injection

Status: Accepted · 2026-11-02

## Context

Three form factors share one codebase. Navigation must adapt and remain testable. Dependency wiring must be explicit and free of singletons.

## Decision

Navigation:

- `AppSection` selects the top-level area. Compact iPhone uses `TabView`; iPad and Mac use `NavigationSplitView`.
- Each section owns a `NavigationStack`. Feature routes are `Hashable` enums handled with `navigationDestination(for:)`.
- No global router object.

Dependency injection:

- `AppContainer` in the app target is the composition root and the only place concrete repositories are named.
- `AppDependencies` carries use-case protocols into Features.
- Constructor injection everywhere; tests pass stubs.

## Alternatives considered

- A coordinator class per flow: more code than value routes, UIKit-era pattern.
- Environment-based service locator: hides dependencies, hard to test. Rejected.
- Swinject or Factory: third-party for a problem a struct solves.

## Consequences

- Deep links become `(AppSection, [Route])` values, easy to test.
- `AppDependencies` must be extended for each new use case. Deliberate: dependencies stay visible.
