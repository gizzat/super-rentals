#!/usr/bin/env bash
# OpenAI TTS adapter. Usage: openai.sh <voice_id> <text> [<lang>]
# Requires OPENAI_API_KEY and `afplay` (macOS).
set -euo pipefail

VOICE_ID="${1:-onyx}"
TEXT="${2:-}"
LANG_CODE="${3:-en}"  # noqa: not used directly; tts-1 handles multilingual input.

[[ -z "$TEXT" ]] && exit 0

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "[openai] OPENAI_API_KEY not set; skipping." >&2
  exit 0
fi

if ! command -v afplay >/dev/null 2>&1; then
  echo "[openai] 'afplay' not found (macOS only); skipping." >&2
  exit 0
fi

TMP=$(mktemp -t voice-openai).mp3
trap 'rm -f "$TMP"' EXIT

HTTP_STATUS=$(curl -sS --max-time 30 -o "$TMP" -w '%{http_code}' \
  -X POST https://api.openai.com/v1/audio/speech \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg t "$TEXT" --arg v "$VOICE_ID" '{
        model: "tts-1",
        input: $t,
        voice: $v,
        response_format: "mp3"
      }')" 2>/dev/null) || HTTP_STATUS="000"

if [[ "$HTTP_STATUS" != "200" ]]; then
  echo "[openai] HTTP $HTTP_STATUS from OpenAI TTS" >&2
  exit 0
fi

afplay "$TMP"
