"""Count lemma frequency in OCR'd TOPIK papers. Output TSV of TOPIK II candidates.

Usage: python count.py <text_dir> <content_dir> <out.tsv>
"""
import glob, json, os, re, sys
from collections import defaultdict
from kiwipiepy import Kiwi

text_dir, content_dir, out_path = sys.argv[1:4]
kiwi = Kiwi()

POS = {"NNG": "noun", "VV": "verb", "VA": "adjective", "MAG": "adverb", "XR": "adjective"}
Q_RE = re.compile(r"^\s*(\d{1,2})\s*[.．](\s|$)")
BOILER = ("유의", "답안지", "수험번호", "감독관", "시험 시작", "홀수형", "짝수형", "국립국제교육원",
          "한국어능력시험", "읽기", "듣기", "쓰기", "다음을 읽고", "다음을 듣고", "알맞은 것을 고르십시오",
          "고르십시오", "중심 생각", "내용과 같은 것", "빈칸에")


def lemmas(line):
    """Yield (lemma, pos) for content words. Noun+하다 counts the noun (해결하다 -> 해결)."""
    toks = kiwi.tokenize(line)
    for i, t in enumerate(toks):
        if len(t.form) < 2 and t.tag in ("NNG", "MAG", "XR"):
            continue
        if t.tag in ("VV", "VA"):
            yield t.form + "다", POS[t.tag]
        elif t.tag == "XR":
            nxt = toks[i + 1] if i + 1 < len(toks) else None
            if nxt is not None and nxt.tag == "XSA":
                yield t.form + nxt.form + "다", "adjective"
        elif t.tag == "NNG":
            nxt = toks[i + 1] if i + 1 < len(toks) else None
            if nxt is not None and nxt.tag == "XSN" and nxt.form in ("적", "화"):
                yield t.form + nxt.form, "noun"
            elif nxt is not None and nxt.tag == "XSA":
                yield t.form + nxt.form + "다", "adjective"
            else:
                yield t.form, "noun"
        elif t.tag == "MAG":
            yield t.form, "adverb"


def scan(files):
    """Return {lemma: {pos, count, sessions:set, qnums:list}}."""
    stats = defaultdict(lambda: {"pos": "", "count": 0, "sessions": set(), "qnums": []})
    for path in files:
        session = os.path.basename(path).split("-")[0]
        q = 0
        for raw in open(path, encoding="utf-8"):
            line = raw.strip()
            if not line or line.startswith("==="):
                continue
            ascii_letters = sum(c.isascii() and c.isalpha() for c in line)
            if ascii_letters > len(line) / 3 or any(b in line for b in BOILER):
                continue
            m = Q_RE.match(line)
            if m and 1 <= int(m.group(1)) <= 50:
                q = int(m.group(1))
            for lemma, pos in lemmas(line):
                s = stats[lemma]
                s["pos"] = s["pos"] or pos
                s["count"] += 1
                s["sessions"].add(session)
                if q:
                    s["qnums"].append(q)
    return stats


t2 = scan(sorted(glob.glob(os.path.join(text_dir, "*TOPIK-II-*.txt"))))
t1 = scan(sorted(glob.glob(os.path.join(text_dir, "*TOPIK-I-*.txt"))))

known = set()
for part in glob.glob(os.path.join(content_dir, "vocabulary", "*.json")):
    for v in json.load(open(part, encoding="utf-8")).get("vocabulary", []):
        known.add(v["hangul"])

# Exam-instruction words and verbs that are really grammar expressions
# (-을 위해, -에 대해, -을 통해, -에 따라, -로 인해, -에 의해, -에 비해, -에 관해).
STOP = {"중략", "물음", "이러하다", "그러하다", "어떠하다", "다음", "내용", "남자", "여자", "그림", "밑줄", "윗글"}
GRAMMAR_VERBS = {"위하다", "대하다", "통하다", "따르다", "인하다", "의하다", "비하다", "관하다", "대하여", "불구하다"}
rows = []
for lemma, s in t2.items():
    if lemma in STOP or lemma in GRAMMAR_VERBS:
        continue
    t1c = t1[lemma]["count"] if lemma in t1 else 0
    median_q = sorted(s["qnums"])[len(s["qnums"]) // 2] if s["qnums"] else 0
    rows.append((lemma, s["pos"], s["count"], len(s["sessions"]), median_q, t1c, lemma in known))

rows.sort(key=lambda r: (-r[3], -r[2]))
with open(out_path, "w", encoding="utf-8") as f:
    f.write("lemma\tpos\tcount\tsessions\tmedian_q\ttopik1_count\tin_library\n")
    for r in rows:
        f.write("\t".join(map(str, r)) + "\n")
print(f"TOPIK II lemmas: {len(t2)}, TOPIK I lemmas: {len(t1)}, library words: {len(known)}")
