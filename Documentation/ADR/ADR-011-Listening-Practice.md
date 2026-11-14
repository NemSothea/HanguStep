# ADR-011: Listening practice with on-device TTS

Status: Accepted (2026-11-14)

## Context

TOPIK II gives listening (듣기) a third of the score (100 of 300 points). The library trained vocabulary, grammar and reading only (PRD Q4), so the learner, who targets level 3-4 by April 2027, had no listening practice in the app. Recorded audio would need voice actors or licensed clips and bloat the bundle; official past-paper audio may not be redistributed.

## Decision

1. New `QuestionKind.listening`. The script lives in the existing `passage` field, so no Core Data or content-format migration is needed. A listening question without a script fails validation (`missingListeningScript`).
2. Scripts mark turns with `남자:` / `여자:`; other lines are narration (`ListeningScript`, Domain). `SpeechPronouncer` speaks line by line with `AVSpeechSynthesizer`: a male and a female Korean voice when installed, otherwise one voice with a lower pitch for the man.
3. The script is hidden until the learner answers, then shown for checking. Audio starts when the question appears, can be replayed, and stops on Next or Close.
4. Listening has its own quiz pool. `Mixed` excludes it and listening questions carry no learning target, so audio never starts unasked in mixed quizzes, review or mistakes.
5. The AI assistant never generates listening questions (excluded from its schema): a script has to be checked for speech quality by a person.
6. Content: 100 original questions (`q.ls.0001`-`0100`, levels 3-4) modelled on TOPIK II question types. No exam text is copied.

## Amendment (2026-11-14): bundled recordings

On the learner's iPhone 13 the on-device voice was "terrible", even with the man's pitch drop reduced. No cloud TTS account was available (Azure was preferred but could not be created).

7. Each listening question now ships a recording, `Audio/listening/<question id>.m4a`, rendered offline on the developer's Mac with MeloTTS (Korean, code and weights MIT). One voice; the man's lines are pitch- and formant-shifted (`Tools/listening-audio`). Mono AAC 48 kbps, about 9 MB for 100 questions.
8. `QuizSessionViewModel` plays the recording through `Pronouncer.play(_:)` (AVAudioPlayer, `.playback`/`.spokenAudio` on iOS so it plays with the ring switch on silent). If a file is missing it falls back to on-device TTS.
9. `content-lint` and `BundledContentTests` fail when a listening question has no recording. Changing a script means re-rendering its file.

## Consequences

- Works fully offline. Bundle grows by about 9 MB.
- One synthetic voice family: clearer than the iPhone voice, still less natural than exam recordings. Learners should still practise with official past-paper audio.
- Speed is fixed near normal rate; a speed setting can come later.
- The generator needs a Python 3.11 environment with local patches (see the tool's README); it is a developer tool, never shipped.
