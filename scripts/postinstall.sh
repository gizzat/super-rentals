#!/usr/bin/env bash
# First-run setup: seed config + user voice overrides file.
# Safe to re-run: only creates files that don't already exist.
set -euo pipefail

: "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT must be set}"
: "${CLAUDE_PLUGIN_DATA:=${HOME}/.claude/plugins/data/claude-voice-response}"

mkdir -p "${CLAUDE_PLUGIN_DATA}"

# shellcheck source=../lib/config.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"
cfg_ensure

# User-editable catalog stub. Keys here override data/voices.default.json.
USER_CATALOG="${CLAUDE_PLUGIN_DATA}/voices.json"
if [[ ! -f "$USER_CATALOG" ]]; then
  cat > "$USER_CATALOG" <<'JSON'
{
  "_readme": "Override or extend ./data/voices.default.json. Keys here win. Delete _readme when adding voices. Example:\n  \"my-clone\": { \"backend\": \"elevenlabs\", \"voice_id\": \"<paste id>\", \"description\": \"My cloned voice\" }"
}
JSON
fi

echo "claude-voice-response initialized at ${CLAUDE_PLUGIN_DATA}"
echo "Run '/voice list' in Claude Code to see available voices."
