# ADR-013: Personal release without a paid Apple Developer account

Status: Accepted (2026-11-14)

## Context

Phase 11 planned an App Store release (TestFlight, then the store). That needs the Apple Developer Program ($99/year), which also unlocks CloudKit. The learner, who is also the only user, does not want to pay for it now. The app is already complete for personal study: vocabulary, grammar, quizzes, review, listening and writing all work offline.

## Decision

1. **Release 1.0.0 as a personal build**, tagged `v1.0.0` on `main` with release notes. No App Store, no TestFlight.
2. **iPhone:** signed with the free personal team. `Tools/install-iphone.sh` builds and installs it (cable or Wi-Fi pairing); free signatures expire after 7 days, so the learner re-runs it weekly. Reinstalling keeps learner data.
3. **Mac:** `Tools/install-mac.sh` builds a locally signed (ad-hoc) copy in `/Applications`. It does not expire.
4. Free builds use `Configs/Personal-*.entitlements` (no iCloud, no push; sandbox and network client on macOS) and `HANGUSTEP_CLOUDKIT_AVAILABLE=NO`, so the app runs local-only. The team ID lives in git-ignored `Configs/personal-team.local`.
5. The App Store milestone (M4) is **deferred, not cancelled**. CloudKit sync, the privacy manifest and the release checklist stay in the code and docs; joining the program later needs only a team ID in `Configs/Signing.local.xcconfig` and the remaining device checks (CLOUDKIT_SYNC.md §8, QA_REPORT.md §5, PRODUCTION_READINESS.md §6).

## Consequences

- No sync: iPhone and Mac each keep their own progress.
- The iPhone build must be reinstalled every 7 days (about 2 minutes with the script).
- Free provisioning allows at most 3 apps per device; HanguStep uses one.
- Device-only acceptance criteria tied to CloudKit (AC-6 to AC-8) stay open until the program is joined.
