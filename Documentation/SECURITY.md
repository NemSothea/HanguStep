# HanguStep Security Notes

Version 0.1 · Phase 8 · Status: credentials section implemented 2026-11-04; the full production review is Phase 10.

## 1. Principles

- No secrets in the app bundle, the repository or the Core Data stores (PRD FR-A3, NFR-7). CI builds with no credentials at all.
- Learner data stays in the learner's own iCloud private database (ADR-003). The app has no backend.
- Every outbound network call is listed here. Today there is exactly one optional destination.

## 2. Credentials

| Secret | Where it lives | Scope | Code |
|--------|----------------|-------|------|
| Anthropic API key (optional, learner-supplied) | Keychain generic password, service `com.nemsothea.hangustep`, account `assistant.claude.apiKey`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` | This device only. Not in iCloud Keychain, not in backups that leave the device, never synced by the app. | `KeychainSecretStore` (Features/Services) |
| Signing team id | `Configs/Signing.local.xcconfig`, git-ignored | Developer machine | — |

The key is read on each assistant request by `ConfiguredAssistantProviderSource` and handed to `ClaudeAssistantProvider` for that request only. It is not logged, not put in `UserDefaults`, not included in error messages. Removing it in Settings deletes the Keychain item. UI test runs use an in-memory secret store.

## 3. Network

| Destination | When | Payload | Not sent |
|-------------|------|---------|----------|
| `https://api.anthropic.com/v1/messages` | Only when the assistant is enabled, the provider is Claude and a key is saved | Question prompt, passage, options, the learner's chosen option, the related word or grammar pattern with its curated examples, the preferred explanation language; for generation also sibling words or patterns used as distractors and prompts already generated for that item | Attempts, scores, streaks, schedules, notes, bookmarks, device name, iCloud identity, any identifier of the learner |
| CloudKit (`iCloud.com.nemsothea.hangustep`) | When iCloud sync is on | Learner store records (ADR-003) | Content library, assistant settings, API key |

macOS runs sandboxed with `com.apple.security.network.client`; iOS needs no entitlement for outbound HTTPS. App Transport Security defaults apply (TLS only).

## 4. Generated content

Assistant output is treated as untrusted input. Drafts are converted and validated with the same rules as bundled content before storage (ADR-008); invalid or duplicate drafts are dropped. Explanations are shown as plain text, never interpreted as markup or links.

## 5. Phase 10 checklist (open)

- Threat model and data-flow review of the two destinations above.
- Decide whether to offer a proxy so learners do not need their own key.
- Privacy manifest (`PrivacyInfo.xcprivacy`) and App Store privacy labels.
- Dependency audit (currently zero third-party runtime dependencies, AC-14).
- Jailbreak and debugger considerations for the Keychain item.
