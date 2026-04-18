#!/usr/bin/env bash
# Smoke tests for claude-voice-response. No API keys or audio hardware required.
# Run with:  bash test/smoke.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
export CLAUDE_PLUGIN_ROOT="$ROOT"
export CLAUDE_PLUGIN_DATA="$(mktemp -d -t voice-smoke.XXXXXX)"
trap 'rm -rf "$CLAUDE_PLUGIN_DATA"' EXIT

PASS=0
FAIL=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == *"$expected"* ]]; then
    echo "  PASS  $name"
    PASS=$((PASS+1))
  else
    echo "  FAIL  $name"
    echo "         expected substring: $expected"
    echo "         actual:             $actual"
    FAIL=$((FAIL+1))
  fi
}

echo "── sanitize.sh ──"
OUT=$(bash "$ROOT/lib/sanitize.sh" $'Hello **world**.\n\n```js\nconsole.log(1);\n```\nBye.')
check "strips code fence + bold"      "Hello world. Bye." "$OUT"

OUT=$(bash "$ROOT/lib/sanitize.sh" $'# Heading\n- item one\n- item two\n\nDone.')
check "strips heading + bullets"      "Heading item one item two Done." "$OUT"

OUT=$(bash "$ROOT/lib/sanitize.sh" $'```\njust code\n```')
check "code-only → empty"             "" "$OUT"

echo "── verbosity.sh ──"
LONG="Sentence one is short. Sentence two goes on for a while with extra words. Sentence three ends things."
OUT=$(bash "$ROOT/lib/verbosity.sh" first-sentence en "$LONG")
check "first-sentence picks opener"   "Sentence one is short." "$OUT"

OUT=$(bash "$ROOT/lib/verbosity.sh" summary en "$LONG")
check "summary passes short text"     "Sentence one is short." "$OUT"

BIG=$(python3 -c 'print("A. "*400)')
OUT=$(bash "$ROOT/lib/verbosity.sh" summary en "$BIG")
LEN=${#OUT}
if [[ $LEN -le 501 ]]; then echo "  PASS  summary caps long text (len=$LEN)"; PASS=$((PASS+1))
else echo "  FAIL  summary caps long text (len=$LEN)"; FAIL=$((FAIL+1)); fi

OUT=$(bash "$ROOT/lib/verbosity.sh" full en "$LONG")
check "full passes text verbatim"     "$LONG" "$OUT"

OUT=$(bash "$ROOT/lib/verbosity.sh" ping en "$LONG")
check "ping English cue"              "Done." "$OUT"

OUT=$(bash "$ROOT/lib/verbosity.sh" ping ru "$LONG")
check "ping Russian cue"              "Готово." "$OUT"

echo "── translate.sh passthrough ──"
OUT=$(bash "$ROOT/lib/translate.sh" en "Hello there.")
check "en passthrough"                "Hello there." "$OUT"

# Without ANTHROPIC_API_KEY, Russian translate falls back to original text.
unset ANTHROPIC_API_KEY
OUT=$(bash "$ROOT/lib/translate.sh" ru "Hello there.")
check "ru falls back without key"     "Hello there." "$OUT"

echo "── config.sh ──"
# shellcheck source=../lib/config.sh
source "$ROOT/lib/config.sh"
cfg_load
check "default backend is say"        "say"      "$CFG_BACKEND"
check "default verbosity summary"     "summary"  "$CFG_VERBOSITY"
check "default language en"           "en"       "$CFG_LANGUAGE"
cfg_set language ru
cfg_load
check "language persists"             "ru"       "$CFG_LANGUAGE"
cfg_set_bool enabled false
cfg_load
check "enabled boolean persists"      "false"    "$CFG_ENABLED"

echo "── voices.sh ──"
ROW=$(bash -c 'source "$0"; voices_lookup alex' "$ROOT/lib/voices.sh")
check "lookup alex → say\tAlex"       "say	Alex"  "$ROW"

ROW=$(bash -c 'source "$0"; voices_lookup onyx' "$ROOT/lib/voices.sh")
check "lookup onyx → openai\tonyx"    "openai	onyx" "$ROW"

if bash -c 'source "$0"; voices_lookup doesnotexist' "$ROOT/lib/voices.sh" 2>/dev/null; then
  echo "  FAIL  unknown voice should error"; FAIL=$((FAIL+1))
else
  echo "  PASS  unknown voice errors"; PASS=$((PASS+1))
fi

echo "── speak.sh end-to-end (no audio; backend=say) ──"
# say.sh will no-op on Linux (no `say`), which is exactly what we want for CI.
cfg_set backend say
cfg_set voice_id Alex
cfg_set voice_name alex
cfg_set_bool enabled true
cfg_set language en
cfg_set verbosity summary
INPUT='{"last_assistant_message":"Hello **world**. Tests pass."}'
echo "$INPUT" | bash "$ROOT/hooks/speak.sh"
LOG="$CLAUDE_PLUGIN_DATA/last.log"
if [[ -f "$LOG" ]]; then
  grep -q "backend=say" "$LOG" && { echo "  PASS  hook logs backend selection"; PASS=$((PASS+1)); } \
                               || { echo "  FAIL  hook log missing backend="; FAIL=$((FAIL+1)); cat "$LOG"; }
  grep -q "Hello world. Tests pass." "$LOG" && { echo "  PASS  hook sanitized text"; PASS=$((PASS+1)); } \
                                             || { echo "  FAIL  hook did not log sanitized text"; FAIL=$((FAIL+1)); cat "$LOG"; }
else
  echo "  FAIL  no log file produced"; FAIL=$((FAIL+1))
fi

echo
echo "Results: $PASS passed, $FAIL failed."
[[ $FAIL -eq 0 ]]
