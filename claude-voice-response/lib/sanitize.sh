#!/usr/bin/env bash
# Strip markdown/code blocks/etc. from assistant text so TTS reads clean prose.
# Usage: sanitize.sh  (reads from stdin or $1 → writes clean text to stdout)
# Exits 0 with empty stdout if nothing speakable remains.
set -euo pipefail

if [[ $# -gt 0 ]]; then
  INPUT="$1"
else
  INPUT="$(cat)"
fi

python3 - "$INPUT" <<'PY'
import re
import sys

text = sys.argv[1]

# 1. Drop fenced code blocks entirely (```lang ... ```).
text = re.sub(r"```.*?```", " ", text, flags=re.DOTALL)

# 2. Drop inline code spans (`...`).
text = re.sub(r"`[^`]*`", " ", text)

# 3. Drop HTML-style tags (<tag ...>) just in case.
text = re.sub(r"<[^>]+>", " ", text)

# 4. Drop image syntax: ![alt](url)
text = re.sub(r"!\[[^\]]*\]\([^)]*\)", " ", text)

# 5. Convert markdown links [text](url) → text.
text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)

# 6. Remove headings (#, ##, ...) at line starts.
text = re.sub(r"(?m)^\s{0,3}#{1,6}\s*", "", text)

# 7. Remove blockquote markers and list bullets.
text = re.sub(r"(?m)^\s*>\s?", "", text)
text = re.sub(r"(?m)^\s*[-*+]\s+", "", text)
text = re.sub(r"(?m)^\s*\d+\.\s+", "", text)

# 8. Remove bold/italic markers (** __ * _) but keep the text.
text = re.sub(r"(\*\*|__)(.+?)\1", r"\2", text, flags=re.DOTALL)
text = re.sub(r"(?<![*_\w])([*_])(?!\s)(.+?)(?<!\s)\1(?![*_\w])", r"\2", text, flags=re.DOTALL)

# 9. Strip remaining stray markdown punctuation that would be read aloud.
text = text.replace("—", ", ").replace("–", ", ")

# 10. Collapse whitespace.
text = re.sub(r"[ \t]+", " ", text)
text = re.sub(r"\n{2,}", "\n\n", text).strip()

# 11. If nothing meaningful remains, emit empty.
if not re.search(r"[A-Za-zА-Яа-я0-9]", text):
    sys.stdout.write("")
else:
    # Single-line for TTS friendliness.
    sys.stdout.write(re.sub(r"\s+", " ", text).strip())
PY
