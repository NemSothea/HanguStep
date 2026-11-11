# ADR-009: No assistant proxy in 1.0; learners bring their own key

Status: Accepted · 2026-11-11

## Context

ADR-008 ships the Claude provider with a key the learner pastes into Settings. SECURITY.md §5 left open whether HanguStep should run a proxy so learners do not need their own Anthropic account. A proxy would hold one developer key server-side and forward requests from the app.

## Options

1. **Bring your own key (current).** Key in the device Keychain, requests go straight to `api.anthropic.com`.
2. **Developer proxy.** A small server (for example a serverless function) holds the key, authenticates the app, rate-limits per install and forwards to Anthropic.

## Decision

Option 1 for 1.0. No proxy, no backend.

- The assistant is optional and off by default. The mock provider covers every learner without a key, offline.
- A proxy needs a server to run and patch, a paid usage budget, abuse controls (App Attest or DeviceCheck plus per-install quotas), and a privacy policy for data the developer would then process. That is a product and cost decision, not a security fix.
- With no backend the app has no developer-side data, which keeps the privacy label at "Data Not Collected" (SECURITY.md §6).

## Consequences

- Learners without an Anthropic account get the built-in (mock) assistant only; the Settings footer already describes it as working offline from the bundled examples.
- The provider abstraction (ADR-008) keeps the door open: a proxy is a new `AssistantProviderKind` and transport, with no use case or view change.
- If a proxy is added later it needs its own ADR covering authentication (App Attest), quotas, logging and data retention, and the privacy label must be revisited.
