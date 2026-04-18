#!/usr/bin/env bash
# Dispatcher for the /voice slash command.
# Usage: voice-cli.sh <subcommand> [args...]
set -euo pipefail

: "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT must be set}"
: "${CLAUDE_PLUGIN_DATA:=${HOME}/.claude/plugins/data/claude-voice-response}"

# shellcheck source=../lib/config.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"
# shellcheck source=../lib/voices.sh
source "${CLAUDE_PLUGIN_ROOT}/lib/voices.sh"

SUB="${1:-status}"
shift || true

cmd_list() {
  echo "Available voices:"
  voices_list
  echo
  echo "Switch with:  /voice set <name>"
}

cmd_set() {
  local name="${1:-}"
  if [[ -z "$name" ]]; then
    echo "Usage: /voice set <name>"
    echo "Run '/voice list' to see available voices."
    exit 0
  fi
  local row backend voice_id
  if ! row=$(voices_lookup "$name"); then
    echo "Unknown voice: '$name'. Run '/voice list' to see options."
    exit 0
  fi
  backend=$(cut -f1 <<<"$row")
  voice_id=$(cut -f2 <<<"$row")
  cfg_set backend "$backend"
  cfg_set voice_id "$voice_id"
  cfg_set voice_name "$name"
  echo "Voice set: $name  (backend=$backend, id=$voice_id)"
  case "$backend" in
    elevenlabs) [[ -z "${ELEVENLABS_API_KEY:-}" ]] && echo "Note: ELEVENLABS_API_KEY is not set in your shell. Audio will be skipped until you export it." ;;
    openai)     [[ -z "${OPENAI_API_KEY:-}" ]]    && echo "Note: OPENAI_API_KEY is not set in your shell. Audio will be skipped until you export it." ;;
  esac
}

cmd_status() {
  cfg_load
  cat <<EOF
Voice-response config:
  enabled:   ${CFG_ENABLED}
  backend:   ${CFG_BACKEND}
  voice:     ${CFG_VOICE_NAME}  (id=${CFG_VOICE_ID})
  language:  ${CFG_LANGUAGE}   (on-screen text always stays English)
  verbosity: ${CFG_VERBOSITY}
EOF
}

cmd_on()  { cfg_set_bool enabled true;  echo "Voice response enabled."; }
cmd_off() { cfg_set_bool enabled false; echo "Voice response disabled."; }

cmd_test() {
  cfg_load
  local phrase
  case "$CFG_LANGUAGE" in
    ru) phrase="Привет! Я ваш голосовой помощник Клод." ;;
    *)  phrase="Hello. This is your Claude voice assistant speaking." ;;
  esac
  echo "Speaking test phrase with voice=$CFG_VOICE_NAME backend=$CFG_BACKEND lang=$CFG_LANGUAGE..."
  bash "${CLAUDE_PLUGIN_ROOT}/adapters/${CFG_BACKEND}.sh" "$CFG_VOICE_ID" "$phrase" "$CFG_LANGUAGE"
}

cmd_lang() {
  local arg="${1:-status}"
  if [[ "$arg" == "status" ]]; then
    cfg_load
    echo "Language: ${CFG_LANGUAGE}"
    echo "(Claude's on-screen replies remain English; only audio is translated.)"
    return
  fi
  cfg_set language "$arg"
  echo "TTS language set to: $arg"
  echo "Claude's on-screen replies will remain English; only the audio is translated."
  if [[ "$arg" != "en" && -z "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "Note: ANTHROPIC_API_KEY is not set. Translation will silently fall back to English text."
  fi
}

cmd_mode() {
  local arg="${1:-status}"
  if [[ "$arg" == "status" ]]; then
    cfg_load
    echo "Verbosity: ${CFG_VERBOSITY}"
    return
  fi
  case "$arg" in
    first-sentence|summary|full|tldr|ping) ;;
    *)
      echo "Unknown mode: '$arg'"
      echo "Valid modes: first-sentence | summary | full | tldr | ping"
      return
      ;;
  esac
  cfg_set verbosity "$arg"
  echo "Verbosity set to: $arg"
  if [[ "$arg" == "tldr" && -z "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "Note: ANTHROPIC_API_KEY is not set. tldr mode will fall back to a truncated copy."
  fi
}

case "$SUB" in
  ""|help|status) cmd_status ;;
  list)           cmd_list ;;
  set)            cmd_set "$@" ;;
  on)             cmd_on ;;
  off)            cmd_off ;;
  test)           cmd_test ;;
  lang)           cmd_lang "$@" ;;
  mode)           cmd_mode "$@" ;;
  *)
    echo "Unknown subcommand: '$SUB'"
    echo "Try: list | set <name> | status | on | off | test | lang <code> | mode <name>"
    ;;
esac
