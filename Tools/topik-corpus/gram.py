"""Count connective/final endings and grammar-verb expressions in TOPIK II vs TOPIK I text."""
import glob, os, sys
from collections import Counter
from kiwipiepy import Kiwi
kiwi = Kiwi()
def scan(files):
    c = Counter()
    for p in files:
        for line in open(p, encoding="utf-8"):
            toks = kiwi.tokenize(line.strip())
            for i, t in enumerate(toks):
                if t.tag in ("EC", "EF", "ETM", "ETN") and len(t.form) >= 2:
                    c[f"-{t.form} ({t.tag})"] += 1
                if t.tag == "VV" and t.form in ("위하", "대하", "통하", "따르", "인하", "의하", "비하", "관하") and i > 0:
                    c[f"{toks[i-1].form}+{t.form}다"] += 1
                if t.tag == "NNB" and t.form in ("수", "것", "데", "줄", "만큼", "대로", "뿐", "셈", "척", "바", "탓", "김", "법", "리", "모양", "듯", "채", "터", "편", "지", "때문"):
                    c[f"N:{t.form}"] += 1
    return c
d = sys.argv[1]
t2 = scan(glob.glob(os.path.join(d, "*TOPIK-II-*.txt")))
t1 = scan(glob.glob(os.path.join(d, "*TOPIK-I-*.txt")))
rows = sorted(t2.items(), key=lambda kv: -kv[1])
for k, v in rows[:90]:
    print(f"{k}\t{v}\tT1={t1.get(k,0)}")
