# CloudKit sync

How learner data moves between the learner's devices. Companion to ADR-003 and DATABASE_SCHEMA.md. Phase 6.

## 1. What syncs

| Data | Store | Synced | Why |
|---|---|---|---|
| Vocabulary, grammar, questions, examples, options, manifest | Content | No | Ships in the bundle; re-imported on update (FR-S2) |
| Attempts, study sessions, bookmarks, review schedules, notes, settings | Learner | Yes, private CloudKit database | Personal progress (FR-S1) |
| Sync preference | `UserDefaults` | No | Device-local choice |

Learner rows reference content by stable string id only (FR-S7). No relationship crosses stores.

## 2. Mechanism

`PersistenceController(mode: .onDisk, sync: .cloudKit(containerIdentifier:))` creates an `NSPersistentCloudKitContainer`. Only the Learner store description receives `NSPersistentCloudKitContainerOptions` (private scope). The Learner store always has persistent history tracking and remote-change notifications on, even with sync off, so sync can be enabled later without rebuilding the store and so saves from other contexts refresh the UI.

Container identifier: `iCloud.com.nemsothea.hangustep` (`AppContainer.cloudKitContainerIdentifier`, must match `App/HanguStep.entitlements`).

Startup order in `AppContainer.bootstrap()`:

1. Read the sync preference (default on). UI tests force it off.
2. Open the controller. If the Learner store refuses to open in CloudKit mode, the controller reopens it with sync off and records `syncFallbackError`. The app never fails to start because of iCloud (FR-S3).
3. Import bundled content if newer.
4. Build repositories and use cases.
5. Start `SyncMonitor`; publish `SyncState` to `SyncStatusModel` for Settings.

Toggling the preference in Settings stores it, stops the old monitor and re-runs `bootstrap()` (single-flight, so the root view's own `.task` cannot start a second run), which rebuilds the container. If the rebuild fails the stored preference is reverted so it matches what last worked. The UI shows the preparing state for a moment.

## 3. Status surface (FR-S5)

`SyncState` (Domain) carries: enabled, account status, syncing, last import, last export, last error. `SyncMonitor` (Persistence) fills it from:

- `NSPersistentCloudKitContainer.eventChangedNotification`: setup, import and export events with success or error.
- `CKContainer.accountStatus()` at start and on `CKAccountChanged`.

`SyncStatusModel.badgeStatus` maps it onto the design system's `SyncStatusBadge`:

| Condition | Badge |
|---|---|
| Preference off, or CloudKit could not be enabled and no error | iCloud sync off |
| Preference on, CloudKit fell back with an error | Sync problem + message |
| No iCloud account | Not signed in |
| Account temporarily unavailable | Offline |
| Event in flight | Syncing |
| Last event failed | Sync problem + message |
| Last event succeeded | iCloud up to date, last sync time |

## 4. UI refresh (FR-S4)

`.NSPersistentStoreRemoteChange` fires for CloudKit imports and for every save in this process too. `SyncMonitor` debounces it (leading 400 ms window, one trailing pass if more arrived, passes never overlap), then reads persistent history since its cursor. Every context this app writes with carries `transactionAuthor = "app"`; only transactions by another author (the CloudKit import, another process) count as foreign. On a foreign transaction the monitor runs deduplication when CloudKit is on and emits one value on `changes()`. Local saves therefore cause no reload storm. History older than 7 days is purged at start. Screens subscribe with `.reloadOnLearnerChange(dependencies.learnerChanges)`: Dashboard, Progress, Mistakes, Bookmarks, Review queue. Views never assume a change has reached another device.

## 5. Conflict and duplicate policy (FR-S6, risk R3)

CloudKit has no uniqueness constraints, so two devices can insert rows for the same logical record before they sync. Field-level conflicts on one record use Core Data's `mergeByPropertyObjectTrump`. Duplicate records are resolved by `LearnerDeduplicator` after each import:

| Entity | Logical key | Survivor |
|---|---|---|
| Attempt | session id + question id | Earliest `answeredAt` (first answer counts), then smallest id |
| Study session | id | Latest `modifiedAt`, then largest id |
| Bookmark, note | target | Latest `modifiedAt`, then largest id |
| Review schedule | target | Latest `lastReviewedAt`, then `modifiedAt`, then largest id |
| Settings | id (`settings`) | Latest `modifiedAt`, then largest id |

Ties are broken by row id so every device chooses the same survivor; without that, two devices could each delete the other's row.

Attempts are append-only, so totals cannot drift (FR-P6). Deleting a bookmark on one device while the other re-adds it resolves to whichever row survives the import; acceptable for MVP.

## 6. Schema rules from now on

The CloudKit schema is additive forever. After Phase 6 ships: only add optional or defaulted attributes and new entities; never rename or delete. Run the app once in Development with each model change so the schema is pushed, then deploy the schema to Production in CloudKit Console before release.

## 7. Project setup

- `App/HanguStep.entitlements` (iOS): iCloud container, CloudKit service, `aps-environment` development (Xcode rewrites it to production when archiving for distribution; silent pushes drive imports). `App/HanguStep-macOS.entitlements` adds the App Sandbox and network client, selected with `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`.
- `project.yml`: entitlements settings, `App/Info.plist` generated with `UIBackgroundModes: remote-notification` and merged with the generated Info.plist keys, config file `Configs/Signing.xcconfig`.
- Team ID lives in `Configs/Signing.local.xcconfig` (git-ignored, see the `.example`). Run `xcodegen generate` after creating it.
- CLI builds without a team: `CODE_SIGNING_ALLOWED=NO`. CloudKit then stays off at runtime.

## 8. Device verification checklist (required before Phase 6 is accepted)

Two devices (for example iPhone and Mac) on one iCloud account, Development environment.

- [ ] AC-6: finish a quiz on iPhone; Mac dashboard shows identical totals after import.
- [ ] AC-7: bookmark on Mac; bookmark appears on iPhone.
- [ ] J5: iPhone offline answers 10 review questions, Mac bookmarks 3 words, iPhone reconnects; no duplicate attempts, no lost bookmarks, schedules carry iPhone's later review dates.
- [ ] AC-8: sign out of iCloud on one device; data stays usable; sign back in; no duplicates.
- [ ] Settings shows account state, last import and export times, and an error when airplane mode is on during an export.
- [ ] Toggle sync off and on; container rebuilds; data intact.
- [ ] Kill the app during import; relaunch; no crash, data consistent.

Record results in this file under "Verification log" with date and build number.

## 9. Known limitations

- Dedupe runs on the device after import, so a duplicate can be visible briefly.
- No per-record merge for notes (last writer wins).
- Content store schema changes still bypass CloudKit entirely.
