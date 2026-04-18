---
description: Control the voice-response plugin (speaks Claude's replies aloud). Subcommands — list | set <name> | status | on | off | test | lang <code> | mode <name>.
argument-hint: "<subcommand> [args]"
allowed-tools: ["Bash"]
---

You are managing the `claude-voice-response` plugin.

Run the helper script with the user's arguments and print **its output verbatim** to the user — do not paraphrase, reformat, or add commentary unless the user asked a question.

```
bash "${CLAUDE_PLUGIN_ROOT}/scripts/voice-cli.sh" $ARGUMENTS
```

Supported subcommands (pass through exactly as typed by the user):

- `list` — print the voice catalog grouped by backend.
- `set <name>` — switch to the named voice (e.g. `set arnold`, `set yoda`, `set alex`).
- `status` — print current config (backend, voice, language, verbosity, enabled).
- `on` / `off` — enable or disable TTS.
- `test` — speak a canned phrase using the current settings.
- `lang <en|ru|...>` — set the TTS output language. **Claude Code's on-screen text always stays English.** Only audio is translated.
- `lang status` — print current language.
- `mode <first-sentence|summary|full|tldr|ping>` — set verbosity.
  - `first-sentence` – only the opening sentence.
  - `summary` – default; ≤500 chars at a sentence boundary.
  - `full` – full response, no cap.
  - `tldr` – AI one-liner (uses Anthropic API).
  - `ping` – fixed "Done." / "Готово." cue.
- `mode status` — print current verbosity.

If the user's arguments are empty or `help`, print the `status` output.
