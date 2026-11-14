"""Join frequency candidates with Wiktionary (kaikki) entries.

Usage: python match.py <freq.tsv> <kaikki.jsonl> <out.json> [min_sessions]
Output: list of {lemma, pos, sessions, count, hanja, roman, glosses[]} for candidates found
in Wiktionary; prints coverage and misses.
"""
import json, sys

freq_path, kaikki_path, out_path = sys.argv[1:4]
min_sessions = int(sys.argv[4]) if len(sys.argv) > 4 else 3
WANT = {"noun": {"noun"}, "verb": {"verb"}, "adjective": {"adj", "verb"}, "adverb": {"adv"}}

cands = []
for i, line in enumerate(open(freq_path, encoding="utf-8")):
    if i == 0:
        continue
    lemma, pos, count, sessions, _q, t1, lib = line.rstrip("\n").split("\t")
    if int(t1) < 2 and lib == "False" and int(sessions) >= min_sessions:
        cands.append({"lemma": lemma, "pos": pos, "count": int(count), "sessions": int(sessions)})
wanted = {c["lemma"] for c in cands} | {c["lemma"] + "하다" for c in cands}

index = {}
for line in open(kaikki_path, encoding="utf-8"):
    e = json.loads(line)
    w = e.get("word")
    if w not in wanted:
        continue
    glosses = [g for s in e.get("senses", []) for g in s.get("glosses", [])
               if not g.lower().startswith(("alternative", "hanja form", "obsolete", "archaic"))]
    if not glosses:
        continue
    roman = next((f["form"] for f in e.get("forms", []) if "romanization" in f.get("tags", [])), "")
    hanja = next((f["form"] for f in e.get("forms", []) if "hanja" in f.get("tags", [])), "")
    index.setdefault(w, []).append({"pos": e.get("pos"), "glosses": glosses, "roman": roman, "hanja": hanja})

out, misses = [], []
for c in cands:
    entries = index.get(c["lemma"], [])
    pick = next((x for x in entries if x["pos"] in WANT.get(c["pos"], ())), entries[0] if entries else None)
    if pick is None:
        misses.append(c["lemma"])
        continue
    verb = index.get(c["lemma"] + "하다", [])
    out.append({**c, "wiktPos": pick["pos"], "glosses": pick["glosses"][:4], "roman": pick["roman"],
                "hanja": pick["hanja"], "hadaVerb": verb[0]["glosses"][:2] if c["pos"] == "noun" and verb else []})

json.dump(out, open(out_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"candidates {len(cands)}, in Wiktionary {len(out)}, missing {len(misses)}")
print("missing sample:", " ".join(misses[:80]))
