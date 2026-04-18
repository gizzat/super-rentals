#!/usr/bin/env bash
# Apply the selected verbosity mode to sanitized text.
# Usage: verbosity.sh <mode> <lang> <text>
# Prints the text to speak on stdout (may be empty).
#
# Modes:
#   ping             fixed completion cue in the target language (no API call)
#   first-sentence   first sentence (cap 240 chars fallback)
#   summary          ≤500 chars at a sentence boundary (default)
#   full             full sanitized text, no cap
#   tldr             AI-generated one-sentence summary via Haiku (cached)

set -euo pipefail

MODE="${1:-summary}"
LANG_CODE="${2:-en}"
TEXT="${3:-}"

: "${CLAUDE_PLUGIN_DATA:=${HOME}/.claude/plugins/data/claude-voice-response}"

emit_first_sentence() {
  python3 - "$TEXT" <<'PY'
import re, sys
t = sys.argv[1].strip()
m = re.search(r"(.+?[.!?])(\s|$)", t, flags=re.DOTALL)
out = m.group(1) if m else t[:240]
out = re.sub(r"\s+", " ", out).strip()
sys.stdout.write(out)
PY
}

emit_summary() {
  python3 - "$TEXT" <<'PY'
import re, sys
t = sys.argv[1].strip()
if len(t) <= 500:
    sys.stdout.write(t); sys.exit(0)
cut = t[:500]
m = re.search(r"[.!?](?!.*[.!?])", cut, flags=re.DOTALL)
if m:
    sys.stdout.write(cut[:m.end()])
else:
    sys.stdout.write(cut.rstrip() + "…")
PY
}

emit_tldr() {
  if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    # No API key → fall back to truncated original.
    printf '%s' "${TEXT:0:200}"
    return
  fi
  local key cache_dir cache
  key=$(printf 'tldr|%s' "$TEXT" | shasum -a 256 | cut -d' ' -f1)
  cache_dir="${CLAUDE_PLUGIN_DATA}/cache"
  cache="${cache_dir}/${key}.txt"
  if [[ -f "$cache" ]]; then
    cat "$cache"
    return
  fi
  mkdir -p "$cache_dir"
  local prompt resp out
  prompt="Summarize the following text in ONE short sentence (max 20 words). Output only the sentence, no preamble, no quotes.

${TEXT}"
  resp=$(curl -sS --max-time 15 https://api.anthropic.com/v1/messages \
    -H "x-api-key: ${ANTHROPIC_API_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "$(jq -n --arg p "$prompt" '{
          model:"claude-haiku-4-5-20251001",
          max_tokens:80,
          messages:[{role:"user",content:$p}]
        }')" 2>/dev/null) || resp=""
  out=$(jq -r '.content[0].text // empty' <<<"$resp" 2>/dev/null || echo "")
  if [[ -z "$out" ]]; then
    printf '%s' "${TEXT:0:200}"
    return
  fi
  printf '%s' "$out" | tee "$cache"
}

case "$MODE" in
  ping)
    case "$LANG_CODE" in
      ru) printf 'Готово.' ;;
      *)  printf 'Done.' ;;
    esac
    ;;
  first-sentence)
    emit_first_sentence
    ;;
  summary)
    emit_summary
    ;;
  full)
    printf '%s' "$TEXT"
    ;;
  tldr)
    emit_tldr
    ;;
  *)
    emit_summary
    ;;
esac
