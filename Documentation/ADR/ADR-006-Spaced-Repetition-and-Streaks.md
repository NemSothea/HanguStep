# ADR-006: SM-2 scheduling, answer quality mapping, streak and day rules

Status: Accepted · 2026-11-03

## Context

Phase 5 adds spaced repetition (PRD FR-R3 to FR-R6) and progress metrics (FR-P2 to FR-P6). The PRD names SM-2 and demands determinism and reference-value tests (AC-5) but leaves three details open: how a multiple-choice answer maps to an SM-2 quality, what "mastered" means, and how calendar days are counted for streaks.

## Decision

**Algorithm.** `SM2.next` implements the published SM-2 formulation: intervals 1, 6, then `round(previous × EF)`; `EF' = EF + 0.1 − (5 − q)(0.08 + (5 − q)0.02)` with floor 1.3; a failing answer (q < 3) resets repetitions to 0 and interval to 1. The ease factor is updated on every answer, including failures, as in the Wikipedia reference formulation. Values are pinned by `SM2Tests`.

**Quality mapping.** Multiple choice yields little signal, so the mapping is coarse: wrong = 1, right = 4, right within 4 seconds = 5. Grades 0, 2 and 3 are unused for now; the enum keeps them so a future self-assessment UI can use the full scale.

**When schedules move.** `SubmitAnswer` updates the target's schedule on every answer in every mode (quiz, mistakes, review). A target's first answer creates its schedule. A target advances at most once per calendar day: a second passing answer on the same day keeps the schedule (only `lastReviewedAt` moves), a failing answer always resets it. The schedule is written after the attempt and before the session advances; if that write fails the session stays on the question, the retry hits the duplicate guard and moves on, and the next answer on the target recomputes from the stored state. Full cross-store atomicity is deferred to the Phase 6 unit-of-work review. Next review date is the start of the local calendar day `interval` days after the answer, so "due" is `nextReviewDate <= now` regardless of time of day.

**Review queue.** Due items sorted by review date (most overdue first), joined with content first, then capped by the learner's `reviewLimit`, one question per target chosen at random among that target's valid questions. A due target whose content was retired takes no slot. The dashboard's due count stays schedule-based and can therefore exceed the startable queue by the number of retired targets; acceptable while content is bundled. Implemented as `QuizPool.review` so the existing session flow, resume and results are reused unchanged.

**Mastered.** An item is mastered when its interval has reached 21 days (Anki's "mature" convention). Only a display rule; nothing stops reviews.

**Streak.** A day is active if at least one attempt was answered on it (device local calendar). The current streak counts consecutive active days ending today, or ending yesterday when today has no answer yet, so a streak is only broken once a full day passes. Longest streak scans the whole history. Sessions count toward "minutes today" on the day they started; an unfinished session counts up to its last answer, so an abandoned sheet stops adding minutes.

**Statistics are derived.** `ProgressStatistics.summary` is a pure function of attempts, sessions, now and a calendar. Nothing is incremented or cached (FR-P6). Revisit if `allAttempts()` exceeds 100 ms at 20 000 rows (same trigger as DATABASE_SCHEMA.md D3).

## Alternatives considered

- FSRS or SM-18: better retention curves, but heavier to validate and the PRD specifies SM-2.
- Leaving the ease factor unchanged on failure (SuperMemo's prose): either reading is defensible; the reference formulation with pinned tests was chosen for verifiability.
- Caching daily counters: faster reads, but FR-P6 forbids totals that can drift from attempt records.
- Time-of-day due dates: makes "due today" depend on when the learner studied yesterday; start-of-day is what learners expect.

## Consequences

- Review sessions share one code path with quizzes; a bug fix helps both.
- Schedules are mutable rows keyed by target, so Phase 6 must merge them with "latest `lastReviewedAt` wins" (PRD FR-S6).
- Streaks depend on the device time zone; a learner who travels may see a day gain or lose a slot. Documented, not corrected.
