#!/usr/bin/env bash
# ElevenLabs TTS adapter. Usage: elevenlabs.sh <voice_id> <text> [<lang>]
# Requires ELEVENLABS_API_KEY and `afplay` (macOS).
set -euo pipefail

VOICE_ID="${1:-}"
TEXT="${2:-}"
LANG_CODE="${3:-en}"

[[ -z "$TEXT" ]] && exit 0

if [[ -z "$VOICE_ID" ]]; then
  echo "[elevenlabs] voice_id missing; skipping." >&2
  exit 0
fi

if [[ -z "${ELEVENLABS_API_KEY:-}" ]]; then
  echo "[elevenlabs] ELEVENLABS_API_KEY not set; skipping." >&2
  exit 0
fi

if ! command -v afplay >/dev/null 2>&1; then
  echo "[elevenlabs] 'afplay' not found (macOS only); skipping." >&2
  exit 0
fi

# eleven_multilingual_v2 handles Russian + English + 30+ others.
if [[ "$LANG_CODE" == "en" ]]; then
  MODEL_ID="eleven_turbo_v2_5"
else
  MODEL_ID="eleven_multilingual_v2"
fi

TMP=$(mktemp -t voice-eleven).mp3
trap 'rm -f "$TMP"' EXIT

HTTP_STATUS=$(curl -sS --max-time 30 -o "$TMP" -w '%{http_code}' \
  -X POST "https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}" \
  -H "xi-api-key: ${ELEVENLABS_API_KEY}" \
  -H "Accept: audio/mpeg" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg t "$TEXT" --arg m "$MODEL_ID" '{
        text: $t,
        model_id: $m,
        voice_settings: { stability: 0.5, similarity_boost: 0.75 }
      }')" 2>/dev/null) || HTTP_STATUS="000"

if [[ "$HTTP_STATUS" != "200" ]]; then
  echo "[elevenlabs] HTTP $HTTP_STATUS from ElevenLabs" >&2
  exit 0
fi

afplay "$TMP"
