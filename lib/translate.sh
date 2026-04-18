#!/usr/bin/env bash
# Translate text to <target_lang> via the Anthropic API (Haiku).
# Usage: translate.sh <target_lang> <text>
# Writes translated text to stdout. On any failure, prints original text.
# Never exits non-zero so the TTS pipeline keeps going.
set -euo pipefail

TARGET="${1:-en}"
TEXT="${2:-}"

: "${CLAUDE_PLUGIN_DATA:=${HOME}/.claude/plugins/data/claude-voice-response}"

passthrough() { printf '%s' "$TEXT"; exit 0; }

# No-op path: target is English (we only generate English to begin with).
if [[ "$TARGET" == "en" || -z "$TEXT" ]]; then
  passthrough
fi

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  passthrough
fi

KEY=$(printf '%s|%s' "$TARGET" "$TEXT" | shasum -a 256 | cut -d' ' -f1)
CACHE_DIR="${CLAUDE_PLUGIN_DATA}/cache"
CACHE="${CACHE_DIR}/tr-${KEY}.txt"

if [[ -f "$CACHE" ]]; then
  cat "$CACHE"
  exit 0
fi

mkdir -p "$CACHE_DIR"

LANG_NAME() {
  case "$1" in
    ru) echo "Russian" ;;
    es) echo "Spanish" ;;
    de) echo "German" ;;
    fr) echo "French" ;;
    it) echo "Italian" ;;
    ja) echo "Japanese" ;;
    zh) echo "Chinese (Simplified)" ;;
    *)  echo "$1" ;;
  esac
}

TARGET_NAME=$(LANG_NAME "$TARGET")
PROMPT="Translate the following text to ${TARGET_NAME}. Output ONLY the translation, no preamble, no quotes, preserve tone and punctuation. If the text is already in ${TARGET_NAME}, return it unchanged.

${TEXT}"

RESP=$(curl -sS --max-time 15 https://api.anthropic.com/v1/messages \
  -H "x-api-key: ${ANTHROPIC_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d "$(jq -n --arg p "$PROMPT" '{
        model:"claude-haiku-4-5-20251001",
        max_tokens:800,
        messages:[{role:"user",content:$p}]
      }')" 2>/dev/null) || RESP=""

OUT=$(jq -r '.content[0].text // empty' <<<"$RESP" 2>/dev/null || echo "")

if [[ -z "$OUT" ]]; then
  passthrough
fi

printf '%s' "$OUT" | tee "$CACHE"
