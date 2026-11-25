# AGENTS.md

This project conforms to Bevry's skills.
Reference their remote URLs only — do not pull their contents into this file.
When a referenced skill applies with your project's tweaks, the local `<name>.md` file at this repo root references the remote URL and lists the tweaks underneath;
this process is documented in the upstream repo's [local tweaks pattern](https://github.com/bevry-vibes/skills#local-tweaks-pattern).

- https://github.com/bevry-vibes/skills/blob/main/policy.md — **applies**. Pass reciprocity detection with `agent-detect` before work.
- https://github.com/bevry-vibes/skills/blob/main/secrets.md — **applies**. Never probe for credentials. The project needs no secrets.
- https://github.com/bevry-vibes/skills/blob/main/author.md — **applies**. Agent commits carry the co-author trailer from `agent-detect`. Agent commits are never signed.
- https://github.com/bevry-vibes/skills/blob/main/commits.md — **applies**. Conventional Commits, one logical change per commit.
- https://github.com/bevry-vibes/skills/blob/main/plans.md — **applies**. Plan files live in `.plans/` with a prompt companion.
- https://github.com/bevry-vibes/skills/blob/main/build.md — **does not apply**. This is a command-line tool with no menu-bar app, login item, or macOS TCC permission.

## project rules

- The tool is macOS-only because `AVSpeechSynthesizer` is the only public API that can use Siri natural voices.
- Never shell out to `/usr/bin/say`. It cannot select Siri natural voices and silently falls back to a legacy voice.
- The installed command must run the generated Swift script through the system `swift` interpreter. Apple gates Siri natural voices from independently compiled binaries.
- Do not install the compiled binary as the Siri voice command. Use `scripts/install.sh` and its wrapper.
- The script renders each utterance to a temporary CAF file, plays it with `/usr/bin/afplay`, and deletes the file.
- Keep `.build/say-voice.swift` in sync with `Sources/` through `scripts/build.sh`.
- Prefer the system Spoken Content default voice. Fall back to the locale's Siri Voice 1 only when the default is absent or is not a Siri voice.
- Never download, install, or modify system voice assets. The user downloads voices in System Settings.
- Keep voice catalog, default lookup, and matching logic in `SayVoiceCore`. Keep `SayVoiceCLI` a thin wrapper.
- Add a test for every new alias form or default-selection rule.
- Do not print or store personal voice preferences beyond the selected voice identifier.
