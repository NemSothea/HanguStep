# HanguStep Security Notes

Version 1.0 · Phase 10 · 2026-11-11. Credentials section from Phase 8; threat model, hardening and privacy added in Phase 10.

## 1. Principles

- No secrets in the app bundle, the repository or the Core Data stores (PRD FR-A3, NFR-7). CI builds with no credentials at all.
- Learner data stays in the learner's own iCloud private database (ADR-003). The app has no backend (ADR-009).
- Every outbound network call is listed here. Today there is exactly one optional destination.
- Collect as little as possible: nothing personal goes into synced records that the feature does not need.

## 2. Credentials

| Secret | Where it lives | Scope | Code |
|--------|----------------|-------|------|
| Anthropic API key (optional, learner-supplied) | Keychain generic password, service `com.nemsothea.hangustep`, account `assistant.claude.apiKey`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` | This device only. Not in iCloud Keychain, not in backups that leave the device, never synced by the app. | `KeychainSecretStore` (Features/Services) |
| Signing team id | `Configs/Signing.local.xcconfig`, git-ignored | Developer machine | — |

The key is read on each assistant request by `ConfiguredAssistantProviderSource` and handed to `ClaudeAssistantProvider` for that request only. It is not logged, not put in `UserDefaults`, not included in error messages. Removing it in Settings deletes the Keychain item. UI test runs use an in-memory secret store, and only Debug builds honour the `--ui-testing` argument.

## 3. Network

| Destination | When | Payload | Not sent |
|-------------|------|---------|----------|
| `https://api.anthropic.com/v1/messages` | Only when the assistant is enabled, the provider is Claude and a key is saved | Question prompt, passage, options, the learner's chosen option, the related word or grammar pattern with its curated examples, the preferred explanation language; for generation also sibling words or patterns used as distractors and prompts already generated for that item | Attempts, scores, streaks, schedules, notes, bookmarks, device name, iCloud identity, any identifier of the learner |
| `https://api.anthropic.com/v1/messages` (writing review, ADR-012) | Only when the learner taps "Get feedback" on a saved writing answer, with the Claude provider and a key | The writing task (instruction, material, model answer, length) and the learner's answer text | Other answers, scores, any identifier of the learner |
| CloudKit (`iCloud.com.nemsothea.hangustep`) | When iCloud sync is on | Learner store records (ADR-003) | Content library, assistant settings, API key |

Transport (`URLSessionTransport`, Phase 10):

- Ephemeral session: no cookie store, no URL cache, no credential storage.
- TLS 1.2 minimum, App Transport Security defaults, no ATS exceptions in `Info.plist`.
- Redirects are refused, so the `x-api-key` header can never be replayed to another host. A 3xx reply surfaces as an invalid response. `URLSessionTransportTests.testRedirectIsNotFollowed` fails if this is removed (checked by mutation).
- Replies are capped at 1 MB (a full 8192-token reply is under 100 KB) before decoding.
- 90 s request and resource timeout; no waiting for connectivity.

No certificate pinning: Anthropic rotates certificates and a stale pin would silently disable the feature for every installed copy. The system trust store plus the controls above is the chosen level for an optional feature using the learner's own key.

macOS runs sandboxed with `com.apple.security.network.client` only. iOS needs no entitlement for outbound HTTPS.

## 4. Generated content

Assistant output is treated as untrusted input. Drafts are converted and validated with the same rules as bundled content before storage (ADR-008); invalid or duplicate drafts are dropped. Explanations are shown as plain text, never interpreted as markup or links.

## 5. Threat model

Assets: learner progress (Learner store and its CloudKit mirror), the optional API key, device-local assistant settings, the content library and generated questions.

| # | Threat | Mitigation | Residual risk |
|---|--------|-----------|---------------|
| T1 | API key sent to a host other than Anthropic (redirect, misconfiguration) | Fixed endpoint constant; redirects refused (§3) | None known |
| T2 | API key leaked in logs, errors or crash reports | No logging in production code; errors carry status and API message only; `ClaudeAssistantProviderTests` asserts the prompt never contains the key | None known |
| T3 | Network interception | HTTPS only, TLS 1.2+, ATS defaults | A user-installed root certificate can intercept; accepted (§3) |
| T4 | Hostile or oversized API reply | 1 MB cap, strict decoding, validation before storage, plain-text rendering | None known |
| T5 | Lost or stolen locked device | iOS Data Protection `completeUntilFirstUserAuthentication` set explicitly on both SQLite stores; Keychain item `AfterFirstUnlockThisDeviceOnly`. macOS: sandbox container plus FileVault | Data readable after first unlock since boot; `complete` would break CloudKit background imports |
| T6 | Jailbroken device or attached debugger reading the key | None in code (see below) | Accepted |
| T7 | Personal data in synced history | Study sessions store the device class (`iPhone`, `iPad`, `Mac`), not the user-assigned name or host name (Phase 10) | None known |
| T8 | Launch arguments changing behaviour in shipped builds | `--ui-testing` only read in Debug builds; Release binary checked to contain no such string | None known |
| T9 | Malicious dependency or CI action | Zero third-party packages; CI fails if a remote package or `Package.resolved` appears; GitHub Actions pinned to commit SHAs | Xcode and the macOS runner image are trusted |
| T10 | Tampered bundled content | Bundle covered by the code signature; content validated on every launch; content store rebuildable | None known |
| T11 | Another iCloud user reading progress | Private CloudKit database only, no public or shared zones (ADR-003) | Relies on Apple account security |

Jailbreak and debugger decision (T6): no jailbreak detection or anti-debugging. Such checks are bypassed easily on a compromised device, risk false positives on normal ones, and protect a key that belongs to the learner, can be revoked by the learner in the Anthropic console, and is only present if the learner chose to add it.

## 6. Privacy

`App/PrivacyInfo.xcprivacy` is in the app bundle (iOS and macOS):

- `NSPrivacyTracking` false, no tracking domains.
- `NSPrivacyCollectedDataTypes` empty.
- Required-reason APIs: `UserDefaults`, reason `CA92.1` (the app's own settings: sync preference in `AppContainer`, assistant settings in `AssistantModel`, unsaved writing drafts in `WritingTaskViewModel`). No file timestamp, system boot time, disk space or keyboard APIs are used in our code.

App Store privacy label: **Data Not Collected** (product decision, 2026-11-11). Reasoning: the developer runs no server and receives nothing; progress lives on the device and in the learner's own iCloud. The Anthropic request is optional, off by default, made at the learner's request with the learner's own key, and sends no identifier. Writing feedback sends the learner's own answer text the same way, only when they tap "Get feedback". If a proxy is ever added (ADR-009), the developer would receive user content and the label must change to declare it.

## 7. Release checklist

- `aps-environment` is `development` in both entitlement files. Distribution signing in Xcode sets it to `production` on export; verify in the exported `.ipa` (Phase 11).
- CloudKit schema must be deployed from development to production in the CloudKit console before release (CLOUDKIT_SYNC.md).
- `ITSAppUsesNonExemptEncryption` is false: only HTTPS through the system TLS stack.
