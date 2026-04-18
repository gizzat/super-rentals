# claude-voice-response

> Hear Claude's replies out loud in Arnold Schwarzenegger, Master Yoda, Morgan Freeman, or whatever voice you like — right inside Claude Code.

A [Claude Code](https://claude.com/claude-code) plugin that speaks every assistant response through a text-to-speech backend of your choice. Runtime voice switching, length controls, and optional Russian audio output — all via a single `/voice` slash command.

---

## Table of contents

- [Why](#why)
- [Install](#install)
- [Quick start](#quick-start)
- [Commands](#commands)
- [Voice backends](#voice-backends)
- [Adding custom voices (Arnold, Yoda, your own clone)](#adding-custom-voices)
- [Verbosity modes](#verbosity-modes)
- [Russian audio mode](#russian-audio-mode)
- [How it works](#how-it-works)
- [Troubleshooting](#troubleshooting)
- [Repository layout](#repository-layout)
- [Contributing](#contributing)
- [License](#license)

---

## Why

Claude Code prints replies; sometimes you'd rather hear them. This plugin hooks into the moment a turn ends and pipes the sanitized final message through a TTS engine. Pick any voice you can get a voice ID for (ElevenLabs has a huge community library of character / celebrity clones) and your terminal starts talking back.

Nothing about Claude's normal behaviour changes — on-screen text is untouched, the hook runs in the background, and any failure is silent.

## Install

**Requirements:** macOS, `jq`, `python3`, `curl` (all ship with macOS).

### From GitHub (recommended)

In Claude Code, add this repo as a plugin marketplace, then install the plugin from it:

```text
/plugin marketplace add gizzat/super-rentals
/plugin install claude-voice-response@gizzat
```

### From a local clone

```bash
git clone https://github.com/gizzat/super-rentals.git
```

Then in Claude Code:

```text
/plugin marketplace add ./super-rentals
/plugin install claude-voice-response@gizzat
```

### For plugin development (hot-reload)

Skip the marketplace and load the plugin directly from a local directory — useful when you're editing `hooks/speak.sh` or the adapters and want changes picked up immediately:

```bash
claude --plugin-dir ./super-rentals
```

Run `/reload-plugins` inside the session after making changes.

Once installed, the Stop hook and the `/voice` command are registered automatically.

### Optional API keys

Export whichever backends you want to use:

```bash
export ELEVENLABS_API_KEY=sk_...      # needed for Arnold / Yoda / any ElevenLabs voice
export OPENAI_API_KEY=sk-...          # needed for onyx / nova / shimmer / ...
export ANTHROPIC_API_KEY=sk-ant-...   # needed for Russian mode and `tldr` verbosity
```

The macOS `say` backend works with **zero** configuration — perfect for trying the plugin out.

## Quick start

```text
/voice set alex         # macOS built-in voice, no key required
/voice test             # hear a test phrase
/voice set arnold       # switch to an ElevenLabs voice (needs ELEVENLABS_API_KEY)
/voice mode summary     # speak a ≤500-char summary (default)
/voice mode ping        # or: just say "Done." when a turn finishes
/voice lang ru          # audio in Russian; on-screen text stays English
/voice off              # mute
/voice on               # unmute
/voice status           # show current config
```

## Commands

| Command | What it does |
|---|---|
| `/voice list` | List available voices grouped by backend. |
| `/voice set <name>` | Switch to the named voice. |
| `/voice status` | Show backend, voice, language, verbosity, enabled flag. |
| `/voice on` / `/voice off` | Enable or disable TTS. |
| `/voice test` | Speak a canned phrase using the current settings. |
| `/voice lang <code>` | Set audio language (`en`, `ru`, …). On-screen text always stays English. |
| `/voice lang status` | Show current audio language. |
| `/voice mode <name>` | Set verbosity: `first-sentence`, `summary`, `full`, `tldr`, `ping`. |
| `/voice mode status` | Show current verbosity. |

## Voice backends

| Backend | Needs key? | Offline? | Best for |
|---|---|---|---|
| **macOS `say`** | no | ✅ | Free system voices — Alex, Samantha, Daniel, Milena, Yuri. Great for trying things out. |
| **OpenAI TTS** | `OPENAI_API_KEY` | ❌ | Clean generic voices: `alloy`, `echo`, `fable`, `onyx`, `nova`, `shimmer`. Cheap. |
| **ElevenLabs** | `ELEVENLABS_API_KEY` | ❌ | Celebrity / character voices. Browse the ElevenLabs Voice Library and paste any voice ID in. |

Missing keys are a soft failure: the hook logs a warning and exits quietly — Claude Code is never disrupted.

## Adding custom voices

The plugin ships a seed catalog in [`data/voices.default.json`](data/voices.default.json). To add your own Arnold, Yoda, or cloned voice, drop entries into your personal catalog:

```bash
~/.claude/plugins/data/claude-voice-response/voices.json
```

Example:

```json
{
  "terminator": {
    "backend": "elevenlabs",
    "voice_id": "PASTE_YOUR_ELEVENLABS_VOICE_ID_HERE",
    "description": "Arnold clone from ElevenLabs Voice Library"
  },
  "yoda": {
    "backend": "elevenlabs",
    "voice_id": "PASTE_YODA_VOICE_ID_HERE",
    "description": "Trained on Empire Strikes Back audio"
  }
}
```

Then in Claude Code:

```text
/voice set terminator
```

Keys in your personal catalog override entries in the shipped defaults, so updating the plugin never clobbers your voices.

## Verbosity modes

Pick how much of each response gets spoken — useful when replies are long or you just want a completion cue.

| Mode | Behaviour |
|---|---|
| `first-sentence` | Speak only the opening sentence. |
| `summary` *(default)* | Sanitize, cap at ~500 characters at a sentence boundary. |
| `full` | Speak the entire response verbatim. |
| `tldr` | Generate a one-sentence AI summary via Claude Haiku (cached per message). |
| `ping` | Play a fixed cue: `"Done."` (or `"Готово."` in Russian mode). Cheapest possible. |

All modes strip code fences and markdown before speaking — no robot voice reading `console.log` at you.

## Russian audio mode

```text
/voice lang ru
```

- **On-screen text stays English.** Translation happens *only* in the TTS pipeline — the transcript, Claude's replies, and everything else you see are untouched.
- Translation uses Claude Haiku via the Anthropic API (`ANTHROPIC_API_KEY`). Results are cached per message, so repeated phrases ("Done.", "All tests pass.") cost one translation ever.
- Works with every backend. ElevenLabs auto-switches to the `eleven_multilingual_v2` model for non-English text; the macOS `say` adapter auto-picks a Russian system voice (Milena/Yuri) if you paired Russian with an English voice ID.

To add more languages, just pick an ISO code: `/voice lang es`, `/voice lang de`, etc.

## How it works

```
Claude finishes a turn
    │   Stop hook fires with { last_assistant_message, ... }
    ▼
 hooks/speak.sh
    │  strip markdown & code (lib/sanitize.sh)
    │  apply verbosity mode (lib/verbosity.sh)
    │  translate if language != en (lib/translate.sh)
    ▼
 adapters/{say,openai,elevenlabs}.sh
    │  request audio, save to /tmp
    ▼
 afplay   (spawned in the background — hook returns immediately)
```

The hook runs with `async: true` and a 15-second timeout. All errors are captured to `~/.claude/plugins/data/claude-voice-response/last.log` and never surfaced — a broken backend will never break Claude Code.

## Troubleshooting

Check `~/.claude/plugins/data/claude-voice-response/last.log` for the most recent invocation.

| Symptom | Likely cause |
|---|---|
| Nothing happens after `/voice set arnold` | `ELEVENLABS_API_KEY` not exported in the shell Claude Code inherits. |
| Russian mode speaks English | `ANTHROPIC_API_KEY` not set — translation falls back to the original text. |
| "afplay: command not found" | You're not on macOS. This plugin is macOS-only in v0.1. |
| Silence when response was pure code | Sanitizer stripped the whole message. Try `/voice mode ping`. |
| Want to disable temporarily | `/voice off` (persists across sessions). |

## Repository layout

```
.
├── .claude-plugin/
│   ├── plugin.json              Plugin manifest
│   └── marketplace.json         Marketplace entry so this repo is installable
├── hooks/
│   ├── hooks.json               Registers the Stop hook
│   └── speak.sh                 Hook entrypoint
├── commands/voice.md            /voice slash command
├── adapters/
│   ├── say.sh                   macOS `say`
│   ├── openai.sh                OpenAI TTS
│   └── elevenlabs.sh            ElevenLabs TTS
├── lib/
│   ├── sanitize.sh              Strip markdown / code
│   ├── verbosity.sh             first-sentence | summary | full | tldr | ping
│   ├── translate.sh             Anthropic Haiku translation, cached
│   ├── config.sh                Read/write persistent config
│   └── voices.sh                Voice catalog lookup
├── data/voices.default.json     Seed voice catalog
├── scripts/
│   ├── voice-cli.sh             Subcommand dispatcher for /voice
│   └── postinstall.sh           First-run setup
└── test/smoke.sh                Smoke tests (no audio / API needed)
```

## Contributing

Run the smoke tests before opening a PR — they don't need API keys or audio hardware:

```bash
bash test/smoke.sh
```

Ideas welcome: Linux / Windows playback adapters, streaming TTS, richer language support, voice-library browsers.

## License

MIT.
