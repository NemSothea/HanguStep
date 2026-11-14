"""Generate listening audio with MeloTTS (MIT). Dev tool only; never shipped.
usage: gen.py <listening.json> <out dir> [question ids...]"""
import json, subprocess, sys, tempfile, os
from melo.api import TTS

src, out = sys.argv[1], sys.argv[2]
wanted = set(sys.argv[3:])
questions = json.load(open(src, encoding="utf-8"))["questions"]
model = TTS(language="KR", device="cpu")
speaker = model.hps.data.spk2id["KR"]
rate = model.hps.data.sampling_rate
os.makedirs(out, exist_ok=True)

def lines(passage):
    for raw in passage.splitlines():
        line = raw.strip()
        if not line: continue
        for who in ("남자", "여자"):
            for sep in (":", "："):
                if line.startswith(who + sep):
                    yield who, line[len(who) + 1:].strip(); break
            else: continue
            break
        else:
            yield "narrator", line

for q in questions:
    if wanted and q["id"] not in wanted: continue
    with tempfile.TemporaryDirectory() as tmp:
        parts = []
        for i, (who, text) in enumerate(lines(q["passage"])):
            wav = f"{tmp}/{i}.wav"
            model.tts_to_file(text, speaker, wav, speed=1.0, quiet=True)
            if who == "남자":
                # Lower pitch and formants for a distinct male voice, keep tempo.
                deep = f"{tmp}/{i}m.wav"
                subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-af",
                                f"asetrate={rate}*0.82,aresample={rate},atempo=1/0.82", deep], check=True)
                wav = deep
            parts.append(wav)
        silence = f"{tmp}/gap.wav"
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "lavfi", "-i", f"anullsrc=r={rate}:cl=mono", "-t", "0.5", silence], check=True)
        listing = f"{tmp}/list.txt"
        with open(listing, "w") as f:
            for p in parts: f.write(f"file '{p}'\nfile '{silence}'\n")
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", listing,
                        "-ac", "1", "-c:a", "aac", "-b:a", "48k", f"{out}/{q['id']}.m4a"], check=True)
    print("wrote", q["id"])
