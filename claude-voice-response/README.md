# claude-voice-response

A Claude Code plugin that **speaks Claude's final response aloud** in a voice you choose. Hear replies in Arnold's "I'll be back," in Yoda's inverted cadence, in Morgan Freeman's narration, or just in a clean macOS system voice — all without leaving your terminal.

## Features

- **Pluggable TTS backends** — ElevenLabs (celebrity / character voices), OpenAI TTS (six generic voices), and the macOS built-in `say` command (offline, free).
- **Runtime voice switching** via the `/voice` slash command. No restart needed.
- **Verbosity modes** so you pick how much gets spoken:
  - `first-sentence` – opening sentence only.
  - `summary` *(default)* – ≤500 chars, trimmed to a sentence boundary.
  - `full` – full response, no cap.
  - `tldr` – one-line AI summary (via Claude Haiku, cached).
  - `ping` – fixed "Done." / "Готово." cue; cheapest possible.
- **Optional Russian audio** — Claude Code's on-screen replies *always* stay English; only the TTS copy is translated (via Claude Haiku). Extensible to more languages via the same `language` field.
- **User-editable voice catalog** — drop your own ElevenLabs voice IDs into `~/.claude/plugins/data/claude-voice-response/voices.json`.
- **Non-blocking** — the Stop hook dispatches playback in the background, so Claude's turn completes instantly.

## Requirements

- **macOS** (audio playback uses `afplay` / `say`).
- `jq` and `python3` on your PATH (both ship with macOS).
- `curl` (also ships with macOS).
- Optional API keys, exported in your shell:
  - `ELEVENLABS_API_KEY` — to use any ElevenLabs voice.
  - `OPENAI_API_KEY` — to use any OpenAI TTS voice.
  - `ANTHROPIC_API_KEY` — to use `lang ru` (translation) or `mode tldr`.

Keys are read from the environment on every invocation. Missing keys fail *soft* — the hook logs a warning and exits 0, so Claude's session is never broken.

## Install

```bash
# From the super-rentals repo checkout:
claude plugin install ./claude-voice-response --scope user
```

This copies the plugin into `~/.claude/plugins/` and registers the Stop hook + `/voice` slash command.

Then run the one-time setup to seed config + user overrides:

```bash
CLAUDE_PLUGIN_ROOT=~/.claude/plugins/.../claude-voice-response \
  bash ~/.claude/plugins/.../claude-voice-response/scripts/postinstall.sh
```

(Or just run `/voice status` — it auto-creates the config on first use.)

## Usage

In Claude Code:

```
/voice status                    Show current config.
/voice list                      List available voices, grouped by backend.
/voice set alex                  Switch to a macOS voice (no API key needed).
/voice set arnold                Switch to an ElevenLabs voice.
/voice on                        Enable TTS.
/voice off                       Disable TTS.
/voice test                      Speak a canned phrase with current settings.
/voice lang ru                   Audio will be spoken in Russian; text stays English.
/voice lang en                   Back to English.
/voice lang status               Show current language.
/voice mode tldr                 One-line spoken summary.
/voice mode summary              Default; ≤500 chars.
/voice mode full                 Speak everything.
/voice mode first-sentence       Just the opening sentence.
/voice mode ping                 Speak only a "Done." cue.
/voice mode status               Show current verbosity.
```

Claude responds to your prompt → the `Stop` hook fires → your chosen adapter speaks the reply.

## Adding custom voices

User overrides live in `~/.claude/plugins/data/claude-voice-response/voices.json`. Entries there override (or extend) the defaults in `data/voices.default.json`. Example:

```json
{
  "terminator": {
    "backend": "elevenlabs",
    "voice_id": "<your-eleven-voice-id>",
    "description": "My Arnold Schwarzenegger clone"
  },
  "yoda": {
    "backend": "elevenlabs",
    "voice_id": "<your-yoda-clone-id>",
    "description": "Trained on Empire Strikes Back audio"
  }
}
```

Then: `/voice set terminator`.

## How it works

```
Claude finishes a turn
   ↓  Stop hook fires with {last_assistant_message, ...}
hooks/speak.sh
   ↓  sanitize (strip code/markdown)
   ↓  verbosity.sh (first-sentence | summary | full | tldr | ping)
   ↓  translate.sh (only if language != en, only in audio path)
   ↓  dispatch to adapters/{say,openai,elevenlabs}.sh
   ↓  afplay (backgrounded)
```

The hook runs in `async` mode with a 15-second timeout. All errors are logged to `~/.claude/plugins/data/claude-voice-response/last.log` and never surfaced to the user — a TTS failure will never break Claude Code.

## Troubleshooting

Check `~/.claude/plugins/data/claude-voice-response/last.log` for the latest invocation. Common issues:

| Symptom | Likely cause |
|--|--|
| Silent after voice change | API key for the new backend not exported in your shell. |
| Russian mode speaks English | `ANTHROPIC_API_KEY` not set; translation falls back to the original text. |
| Code is being spoken | Your response was almost entirely code; sanitizer left only fragments. Try `mode ping`. |
| `afplay: command not found` | You're not on macOS. This plugin is macOS-only in v0.1. |

## License

MIT (placeholder).
