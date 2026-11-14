# Listening audio generator

Developer-only tool that renders every listening script (`Content/questions/listening.json`) to
`Packages/HanguStepKit/Sources/Persistence/Resources/Audio/listening/<question id>.m4a`.
Nothing here ships except the generated audio. Decision record: `Documentation/ADR/ADR-011-Listening-Practice.md`.

- Voice: [MeloTTS](https://github.com/myshell-ai/MeloTTS) Korean (code and model weights MIT). Runs offline on the Mac, no account.
- MeloTTS has one Korean voice. The man's lines are the same voice with pitch and formants lowered (ffmpeg `asetrate` + `atempo`, factor 0.82), so the two speakers sound different.
- Lines are joined with 0.5 s pauses, mono AAC 48 kbps (about 90 KB per dialogue).

## Setup (once)

```sh
UV_PYTHON_PREFERENCE=only-managed uv python install 3.11
uv venv -p 3.11 /tmp/melo
VIRTUAL_ENV=/tmp/melo uv pip install "git+https://github.com/myshell-ai/MeloTTS.git" "setuptools<70" python-mecab-ko
VIRTUAL_ENV=/tmp/melo uv pip uninstall mecab-python3
/tmp/melo/bin/python -m unidic download
```

macOS disks are case-insensitive, so the Japanese `MeCab` package and the Korean `mecab` package overwrite each
other. Korean needs only `python-mecab-ko`; MeloTTS imports its Japanese module unconditionally, so make it tolerate
the missing Japanese tagger in `site-packages/melo/text/japanese.py`:

```python
try:
    import MeCab
except ImportError:
    MeCab = None
...
_TAGGER = MeCab.Tagger() if MeCab else None
```

## Generate

```sh
cd Tools/listening-audio
TOKENIZERS_PARALLELISM=false /tmp/melo/bin/python -I gen.py \
  ../../Packages/HanguStepKit/Sources/Persistence/Resources/Content/questions/listening.json \
  ../../Packages/HanguStepKit/Sources/Persistence/Resources/Audio/listening [question ids...]
```

Without ids it renders every question. Re-render a question whenever its `passage` changes. `content-lint` fails when a
listening question has no recording; the app falls back to on-device TTS if a file is ever missing.
