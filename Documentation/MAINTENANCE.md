# Maintenance

How to keep HanguStep running and growing after 1.0 (ADR-013).

## Weekly: reinstall on the iPhone

Free signing expires after 7 days. With the iPhone connected (or paired for Wi-Fi in Xcode) and unlocked:

```sh
Tools/install-iphone.sh
```

Progress, bookmarks and writing answers stay. The Mac copy (`Tools/install-mac.sh`) never expires; re-run it only to update.

## Adding vocabulary (TOPIK II)

Pipeline and rules: `Tools/topik-corpus/README.md`, ADR-010.

1. Recount frequency, pick the next candidates, draft words (meaning, example, Khmer) into new `vocabulary/level4-*.json` files. Next free ids: see the last file of each level.
2. `swift run --build-system swiftbuild content-lint generate-questions` (rewrites generated questions and `summary.json`).
3. Bump `version` in `Content/package.json`, then `swift run --build-system swiftbuild content-lint` and `swift test --build-system swiftbuild`.

## Adding grammar or authored questions

Append to `grammar/level4.json` / `questions/authored-level4.json` (format: `CONTENT_FORMAT.md`), bump the version, lint, test.

## Adding listening questions

1. Add items to `questions/listening.json` (`kind: listening`, script in `passage` with `남자:` / `여자:` lines, ids `q.ls.NNNN`).
2. Render recordings: `Tools/listening-audio/README.md` (MeloTTS, offline). `content-lint` fails until every listening question has its `.m4a`.
3. Bump the version, lint, test.

## Adding writing tasks

Append to `writing/tasks.json` (format: `CONTENT_FORMAT.md`, "Writing prompts"). No version bump needed. Survey data must name fictional organisations. `content-lint` checks model-answer lengths.

## Before merging anything

- `swift test --build-system swiftbuild` and the UI suite (`QA_REPORT.md`) pass.
- CI on the pull request is green (`.github/workflows/ci.yml`).
- Docs and the relevant ADR updated.

## If you join the Apple Developer Program later

Put the team ID in `Configs/Signing.local.xcconfig`, run `xcodegen generate`, and follow `CLOUDKIT_SYNC.md` §8 and `PRODUCTION_READINESS.md` for sync and the App Store.
