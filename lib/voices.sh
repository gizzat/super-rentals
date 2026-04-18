#!/usr/bin/env bash
# Voice catalog lookup. The catalog is a JSON object keyed on a friendly name;
# each entry is { backend, voice_id, [description] }.
#
# Catalog load order (first hit wins per key):
#   1. ${CLAUDE_PLUGIN_DATA}/voices.json   (user-editable; survives updates)
#   2. ${CLAUDE_PLUGIN_ROOT}/data/voices.default.json   (ships with plugin)

set -euo pipefail

: "${CLAUDE_PLUGIN_DATA:=${HOME}/.claude/plugins/data/claude-voice-response}"
: "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT must be set}"

VOICES_USER="${CLAUDE_PLUGIN_DATA}/voices.json"
VOICES_DEFAULT="${CLAUDE_PLUGIN_ROOT}/data/voices.default.json"

# Print the merged catalog (user overrides defaults).
voices_all() {
  mkdir -p "${CLAUDE_PLUGIN_DATA}"
  if [[ -f "${VOICES_USER}" ]]; then
    jq -s '.[0] * .[1]' "${VOICES_DEFAULT}" "${VOICES_USER}"
  else
    cat "${VOICES_DEFAULT}"
  fi
}

# voices_lookup <name>  →  prints "<backend>\t<voice_id>" or exits 1.
voices_lookup() {
  local name="$1"
  local entry
  entry=$(voices_all | jq -r --arg n "$name" '.[$n] // empty')
  if [[ -z "$entry" ]]; then
    return 1
  fi
  local backend voice_id
  backend=$(jq -r '.backend' <<<"$entry")
  voice_id=$(jq -r '.voice_id' <<<"$entry")
  printf '%s\t%s\n' "$backend" "$voice_id"
}

# voices_list → pretty printed, grouped by backend.
voices_list() {
  voices_all | jq -r '
    to_entries
    | group_by(.value.backend)
    | map({backend: .[0].value.backend, voices: map({name: .key, voice_id: .value.voice_id, description: (.value.description // "")})})
    | .[] as $g
    | "── \($g.backend) ──\n" + (
        $g.voices | map("  \(.name)\t(\(.voice_id))\t\(.description)") | join("\n")
      )
  '
}
