#!/usr/bin/env bash
# Claude Code Stop hook entrypoint.
# Reads hook JSON from stdin, extracts last_assistant_message, sanitizes it,
# applies the selected verbosity mode, optionally translates, then dispatches
# to the configured TTS adapter (in the background so Claude is never blocked).
#
# Intentionally lenient: any failure is logged to ${CLAUDE_PLUGIN_DATA}/last.log
# and the script exits 0 so Claude Code's turn completes normally.
set -u

: "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT must be set}"
: "${CLAUDE_PLUGIN_DATA:=${HOME}/.claude/plugins/data/claude-voice-response}"

mkdir -p "${CLAUDE_PLUGIN_DATA}" 2>/dev/null || true
LOG="${CLAUDE_PLUGIN_DATA}/last.log"

{
  # shellcheck source=../lib/config.sh
  source "${CLAUDE_PLUGIN_ROOT}/lib/config.sh"
  cfg_load

  if [[ "${CFG_ENABLED}" != "true" ]]; then
    echo "[speak] disabled; exiting." ; exit 0
  fi

  # Read hook JSON payload from stdin.
  INPUT=$(cat || true)
  if [[ -z "${INPUT}" ]]; then
    echo "[speak] empty stdin; exiting." ; exit 0
  fi

  MSG=$(jq -r '.last_assistant_message // empty' <<<"$INPUT" 2>/dev/null || echo "")
  if [[ -z "$MSG" ]]; then
    # Fall back: try to read the last assistant message from the transcript.
    TRANSCRIPT=$(jq -r '.transcript_path // empty' <<<"$INPUT" 2>/dev/null || echo "")
    if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
      MSG=$(tac "$TRANSCRIPT" 2>/dev/null | awk '
        /"role":"assistant"/ { print; exit }
      ' | jq -r '(.message.content // .content) | if type=="array" then map(select(.type=="text") | .text) | join("\n") else . end' 2>/dev/null || echo "")
    fi
  fi

  if [[ -z "$MSG" ]]; then
    echo "[speak] no assistant message found; exiting." ; exit 0
  fi

  TEXT=$("${CLAUDE_PLUGIN_ROOT}/lib/sanitize.sh" "$MSG" || echo "")
  if [[ -z "$TEXT" ]]; then
    echo "[speak] sanitized text empty (likely code-only); exiting." ; exit 0
  fi

  TEXT=$("${CLAUDE_PLUGIN_ROOT}/lib/verbosity.sh" "$CFG_VERBOSITY" "$CFG_LANGUAGE" "$TEXT" || echo "")
  if [[ -z "$TEXT" ]]; then
    echo "[speak] verbosity produced empty text; exiting." ; exit 0
  fi

  # For `ping`, verbosity.sh already emits the cue in the target language.
  if [[ "$CFG_LANGUAGE" != "en" && "$CFG_VERBOSITY" != "ping" ]]; then
    TEXT=$("${CLAUDE_PLUGIN_ROOT}/lib/translate.sh" "$CFG_LANGUAGE" "$TEXT" || echo "$TEXT")
  fi

  ADAPTER="${CLAUDE_PLUGIN_ROOT}/adapters/${CFG_BACKEND}.sh"
  if [[ ! -x "$ADAPTER" && ! -f "$ADAPTER" ]]; then
    echo "[speak] unknown backend '${CFG_BACKEND}'" ; exit 0
  fi

  echo "[speak] backend=${CFG_BACKEND} voice=${CFG_VOICE_NAME} lang=${CFG_LANGUAGE} mode=${CFG_VERBOSITY}"
  echo "[speak] text: ${TEXT}"

  # Spawn playback detached so the hook returns immediately.
  ( bash "$ADAPTER" "$CFG_VOICE_ID" "$TEXT" "$CFG_LANGUAGE" >/dev/null 2>&1 & ) </dev/null
} >"$LOG" 2>&1

exit 0
