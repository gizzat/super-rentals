#!/usr/bin/env bash
# Load/write the plugin's persistent config.
# After `cfg_load`, these vars are set:
#   CFG_ENABLED   true|false
#   CFG_BACKEND   say|openai|elevenlabs
#   CFG_VOICE_ID  backend-specific voice identifier
#   CFG_VOICE_NAME  friendly name (e.g. "arnold")
#   CFG_LANGUAGE  en|ru|...
#   CFG_VERBOSITY first-sentence|summary|full|tldr|ping

set -euo pipefail

: "${CLAUDE_PLUGIN_DATA:=${HOME}/.claude/plugins/data/claude-voice-response}"
CFG_PATH="${CLAUDE_PLUGIN_DATA}/config.json"

cfg_defaults() {
  cat <<'JSON'
{
  "enabled": true,
  "backend": "say",
  "voice_id": "Alex",
  "voice_name": "alex",
  "language": "en",
  "verbosity": "summary"
}
JSON
}

cfg_ensure() {
  mkdir -p "${CLAUDE_PLUGIN_DATA}"
  if [[ ! -f "${CFG_PATH}" ]]; then
    cfg_defaults > "${CFG_PATH}"
  fi
}

cfg_load() {
  cfg_ensure
  local raw
  raw=$(cat "${CFG_PATH}")
  # NB: `// default` treats `false` as empty, which would mask a disabled state.
  # Use explicit null checks for boolean fields.
  CFG_ENABLED=$(jq -r 'if .enabled == null then true else .enabled end' <<<"$raw")
  CFG_BACKEND=$(jq -r '.backend // "say"' <<<"$raw")
  CFG_VOICE_ID=$(jq -r '.voice_id // "Alex"' <<<"$raw")
  CFG_VOICE_NAME=$(jq -r '.voice_name // "alex"' <<<"$raw")
  CFG_LANGUAGE=$(jq -r '.language // "en"' <<<"$raw")
  CFG_VERBOSITY=$(jq -r '.verbosity // "summary"' <<<"$raw")
  export CFG_ENABLED CFG_BACKEND CFG_VOICE_ID CFG_VOICE_NAME CFG_LANGUAGE CFG_VERBOSITY
}

# cfg_set <field> <value>
cfg_set() {
  cfg_ensure
  local field="$1" value="$2" tmp
  tmp=$(mktemp)
  jq --arg v "$value" ".${field} = \$v" "${CFG_PATH}" > "$tmp"
  mv "$tmp" "${CFG_PATH}"
}

# cfg_set_bool <field> <true|false>
cfg_set_bool() {
  cfg_ensure
  local field="$1" value="$2" tmp
  tmp=$(mktemp)
  jq ".${field} = ${value}" "${CFG_PATH}" > "$tmp"
  mv "$tmp" "${CFG_PATH}"
}

# Print the current config for /voice status.
cfg_print() {
  cfg_ensure
  cat "${CFG_PATH}"
}
