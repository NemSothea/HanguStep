# TOPIK corpus tools

Developer-only scripts that choose which TOPIK II words and grammar to teach. Nothing here ships in the app, and no exam text is committed. Decision record: `Documentation/ADR/ADR-010-TOPIK-II-Content-Sources.md`.

## Inputs (git-ignored, under `ContentSources/`)

| Folder | What | Licence / use |
|--------|------|---------------|
| `ContentSources/topik/` | TOPIK I and II past papers (PDF) from topikguide.com, plus `text/` OCR output | NIIED copyright. Used only to count word frequency. Never copied into the app. |
| `ContentSources/wiktionary/kaikki-korean.jsonl` | Wiktionary Korean extract from kaikki.org | CC BY-SA 4.0. English meanings may be used with attribution (item `source`). |

## Pipeline

```sh
# 1. OCR scanned papers (macOS Vision, Korean + English). One PDF per call.
swiftc -O Tools/topik-corpus/ocr.swift -o /tmp/ocr
/tmp/ocr ContentSources/topik/91st-TOPIK-II-Reading-Test-Paper.pdf ContentSources/topik/text/91st-TOPIK-II-Reading-Test-Paper.txt

# 2. Python env for the Korean morphological analyser (kiwipiepy, LGPL, dev only).
python3 -m venv /tmp/kiwi && /tmp/kiwi/bin/pip install -r Tools/topik-corpus/requirements.txt

# 3. Word frequency: lemma, pos, count, exams (of N), TOPIK I count, already in library.
/tmp/kiwi/bin/python -I Tools/topik-corpus/count.py ContentSources/topik/text \
  Packages/HanguStepKit/Sources/Persistence/Resources/Content /tmp/freq.tsv

# 4. Grammar frequency (endings and N에 대해-type expressions).
/tmp/kiwi/bin/python -I Tools/topik-corpus/gram.py ContentSources/topik/text

# 5. Join a batch with Wiktionary senses for drafting (writes chunk1..3.json).
/tmp/kiwi/bin/python -I Tools/topik-corpus/inputs.py /tmp/batch.tsv ContentSources/wiktionary/kaikki-korean.jsonl
```

## Selection rules

- Candidate = appears in TOPIK II papers, fewer than 2 times in TOPIK I papers, not already in the library.
- Rank by number of exams the word appears in, then total count.
- Suffix merge: noun + 적/화 is one word (긍정적, 활성화). Noun + 하다 adjective is one word (필요하다).
- Exam-instruction words (중략, 물음, 밑줄 ...) are dropped. Verbs used mainly as grammar (위하다, 대하다, 통하다, 따르다, 인하다, 의하다, 비하다) are taught as grammar patterns, not vocabulary.
- Level: batch 1 (most frequent) is level 3. Later, less frequent batches are level 4; basic words missing from levels 1-2 are tagged level 2. TOPIK publishes no per-level word list, so this split is a judgement.

## Batches

- Batch 1 (2026-11-14): 300 words (level 3), 20 grammar patterns.
- Batch 2 (2026-11-14): next 300 candidates after dropping 이렇게, 이때, 시키다, 감사하다; 253 level 4 + 47 level 2 words, 20 level 4 grammar patterns.

## Corpus used for batches 1-2 (2026-11-14)

TOPIK II: exams 35, 36, 37, 41, 47, 52, 60, 64, 83, 91, 96, 102 (reading, listening transcript, writing where available). TOPIK I: exams 64, 83, 91, 96, 102 (reading, listening transcript). 1,640 candidates appear in 3 or more of the 12 exams.
