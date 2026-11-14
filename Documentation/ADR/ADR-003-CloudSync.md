# ADR-003: NSPersistentCloudKitContainer for learner data sync

Status: Accepted · 2026-11-02 · Implemented 2026-11-03 (device verification pending)

## Context

The learner wants progress to follow them across iPhone, iPad and Mac without a custom backend. Sync must be optional and the app fully usable offline.

## Decision

- `NSPersistentCloudKitContainer` mirrors the `Learner` store to the user's private CloudKit database.
- No second write path to CloudKit. The container is the only sync mechanism for these entities.
- Persistent history tracking and remote change notifications refresh the UI after imports.
- Conflict policy per entity, decided in Phase 6: attempts are append-only (no conflicts); schedules resolve by latest `lastReviewedAt`; bookmarks resolve by latest modification. Duplicates created by two devices inserting the same target are deduplicated after import.
- Sync status (account state, last import or export, last error) is exposed on the Settings screen.

## Alternatives considered

- Custom backend: cost, maintenance, accounts. Rejected.
- CloudKit directly with `CKRecord`: full control, but reimplements what the container provides.
- Firebase or similar: third-party, privacy trade-offs. Rejected.

## Consequences

- Eventual consistency. The UI must never assume a change is on another device yet.
- Schema design is constrained from Phase 3 onward (see ADR-002).
- Real-device testing is mandatory before Phase 6 is accepted.

## Implementation notes (Phase 6)

- `PersistenceController(mode:sync:)` with `SyncOption.off | .cloudKit(containerIdentifier:)`. Fallback to `.off` with `syncFallbackError` when the Learner store cannot open in CloudKit mode.
- History tracking and remote-change notifications are on for the Learner store in every on-disk configuration, not only when CloudKit is on.
- `SyncMonitor` publishes `SyncState` and a debounced change stream; `LearnerDeduplicator` applies the per-entity policy after imports.
- The sync preference is device-local (`UserDefaults`), default on; changing it rebuilds the container.
- Details, tables and the device checklist: `Documentation/CLOUDKIT_SYNC.md`.
