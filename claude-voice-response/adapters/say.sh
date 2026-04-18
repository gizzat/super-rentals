#!/usr/bin/env bash
# macOS `say` adapter. Usage: say.sh <voice_id> <text> [<lang>]
# Requires `say` (macOS built-in). Works offline, no API key.
set -euo pipefail

VOICE_ID="${1:-Alex}"
TEXT="${2:-}"
LANG_CODE="${3:-en}"

[[ -z "$TEXT" ]] && exit 0

if ! command -v say >/dev/null 2>&1; then
  echo "[say] 'say' not available on this platform; skipping." >&2
  exit 0
fi

# If the caller asked for Russian but picked an English voice, swap to a
# macOS Russian voice. User can install "Milena" / "Yuri" via
# System Settings → Accessibility → Spoken Content → System Voice.
if [[ "$LANG_CODE" == "ru" ]]; then
  case "$VOICE_ID" in
    Milena|Yuri|Katya) : ;;
    *) VOICE_ID="Milena" ;;
  esac
fi

say -v "$VOICE_ID" "$TEXT"
