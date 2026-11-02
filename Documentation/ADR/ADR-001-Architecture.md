# ADR-001: Clean Architecture with MVVM in one local Swift package

Status: Accepted · 2026-11-02

## Context

The app must be testable without a simulator, maintainable by one developer, and demonstrate professional layering. Over-modularization slows a solo developer; under-modularization lets business logic leak into views.

## Decision

- Layers: Domain, Persistence, DesignSystem, Features, App. Dependencies point inward to Domain.
- One local package `HanguStepKit` with one target per layer. The app target holds only the composition root.
- Presentation uses MVVM: `@Observable` view models own state, views own layout.
- Use cases are protocols with default implementations; view models depend on the protocols.

## Alternatives considered

- Single app target with folders: no compiler enforcement, rejected.
- One package per layer or per feature: more manifests, no benefit at this size. Revisit if build time or team size grows.
- TCA or other architecture frameworks: third-party dependency, learning overhead, rejected for MVP.

## Consequences

- `swift test` runs all unit tests on macOS in seconds.
- Adding a feature means a folder in Features, a use case in Domain, and a field in `AppDependencies`.
- Views in the Features target cannot reach Persistence even by accident.
