import json, sys
batch = [l.split("\t") for l in open(sys.argv[1], encoding="utf-8").read().splitlines()]
words = {b[0] for b in batch} | {b[0] + "하다" for b in batch}
idx = {}
for line in open(sys.argv[2], encoding="utf-8"):
    e = json.loads(line)
    w = e.get("word")
    if w not in words or e.get("pos") in ("character", "name"):
        continue
    gl = [g for s in e.get("senses", []) for g in s.get("glosses", [])][:5]
    if not gl:
        continue
    f = e.get("forms", [])
    idx.setdefault(w, []).append({"pos": e.get("pos"),
        "hanja": next((x["form"] for x in f if "hanja" in x.get("tags", [])), ""),
        "roman": next((x["form"] for x in f if "romanization" in x.get("tags", [])), ""),
        "glosses": gl})
out = []
for i, b in enumerate(batch):
    out.append({"id": f"vocab.{3001 + i}", "hangul": b[0], "pos": b[1], "exams": int(b[3]),
                "wiktionary": idx.get(b[0], []), "wiktionaryHada": idx.get(b[0] + "하다", [])[:1]})
for k in range(3):
    json.dump(out[k*100:(k+1)*100], open(f"chunk{k+1}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(sum(1 for o in out if o["wiktionary"]), "of", len(out), "have Wiktionary entries")
