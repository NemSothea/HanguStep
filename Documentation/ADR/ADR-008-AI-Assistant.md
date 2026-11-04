# ADR-008: AI assistant behind a provider abstraction, mock first

Status: Accepted · 2026-11-04

## Context

PRD FR-A1 to FR-A3 ask for an optional assistant behind an abstraction, with a mock provider first, generated content validated and stored with provenance before it is shown, and no credentials in the bundle (NFR-7). Milestone M3 adds: real provider behind a feature flag. The PRD lists three uses: explanations, generated questions, writing feedback. Writing feedback needs the TOPIK II writing feature that does not exist yet, so Phase 8 ships the first two.

## Decision

**One protocol, two operations.** `AssistantProvider` (Domain) has `explain(ExplanationRequest)` and `generate(PracticeRequest) -> [DraftQuestion]`. Providers are pure functions of their input: they never read or write storage. Use cases `ExplainAnswer` and `GeneratePracticeQuestions` join content, call the provider and own persistence.

**Provider resolved per call.** Use cases hold an `AssistantProviderSource`, not a provider. The app's source (`ConfiguredAssistantProviderSource`, Features) reads the device-local `AssistantSettings` (UserDefaults) and the Claude key (Keychain) on every request and throws `AssistantError.disabled` or `.notConfigured`. The feature flag is therefore a plain setting with no restart, and the UI gates its buttons on the same `AssistantModel`.

**Device-local settings, not `LearnerSettings`.** The provider choice is only meaningful with a key, and the key must not sync. Keeping both on the device avoids a Core Data model version and a CloudKit field for something that would be wrong on the second device.

**Mock is a real provider, not a stub.** `MockAssistantProvider` (Domain) explains from the curated explanation plus the related word or pattern, and generates cloze questions from example sentences and meaning questions from sibling vocabulary. Deterministic, offline, and the default. It is what UI tests use and what a learner without a key gets.

**Claude provider in its own target.** `Assistant` (SwiftPM target, depends on Domain) holds `ClaudeAssistantProvider`: raw `URLRequest`s to the Anthropic Messages API (no official Swift SDK), model `claude-opus-5-5`, API version `2026-10-21`, `fallbacks: "default"` with the `server-side-fallback-2026-07-01` beta so a safety decline is re-run server-side. Explanations use `output_config.effort = low`, plain text, 1024 tokens. Question drafts use structured outputs (`output_config.format = json_schema`) at `medium` effort so the reply always decodes. An `HTTPTransport` seam makes it testable without the network. Features never imports this target; the composition root passes a factory closure.

**Generated questions live in the content store.** `CoreDataGeneratedQuestionStore` writes `CDQuestion` rows with `sourceOrigin = aiGenerated`, `contentVersion = 0`, id `q.ai.<uuid>`, `sourceName = <provider>`. The ordinary `QuestionRepository` serves them, so sessions, attempts, mistakes and SM-2 work unchanged. `CoreDataContentStore` skips `aiGenerated` rows when retiring on import, so a library update does not retire them. They are not synced (content store) and can be deleted from Settings; attempts keep their copied target so history survives.

**Validation before storage (FR-A2).** `GeneratePracticeQuestions.question(from:)` turns a draft into a `Question` and keeps it only if `Question.validate()` is empty; prompts already stored for the target are dropped; all drafts failing throws `AssistantError.nothingUsable`. The store also re-validates. A provider cannot put an invalid or duplicate question in front of the learner.

**Privacy.** A request to Claude carries the question text, options, the learner's choice, the related word or pattern and its examples. It never carries attempts, progress, notes or the learner's identity. The Settings footer says so.

## Consequences

- Phase 8 is complete without any network call: tests and UI tests run the mock.
- A third provider is a new `AssistantProviderKind` case, a factory branch and a target. No use case or view changes.
- Generated questions are device-local. A learner on two devices gets different generated sets; acceptable, since they are supplements to the synced library.
- Prompt wording is in `Prompts` (Assistant target) and is not covered by tests beyond shape; quality is evaluated by use.
- Writing feedback (PRD 214) is deferred to a writing-practice phase.
