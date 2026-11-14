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

## Consequences

- Works fully offline, no bundle growth.
- TTS sounds less natural than exam recordings and voice availability varies by device. The app trains comprehension; learners should still practise with official past-paper audio.
- Speed is fixed near normal rate; a speed setting can come later.
