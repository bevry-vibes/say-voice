# say-voice

Speak text with an installed Siri natural voice on macOS.
The tool selects the system Spoken Content default voice, or a voice that matches a flexible alias.

## Why this exists

The macOS `say` command cannot use Siri natural voices.
It accepts a Siri voice name and then silently falls back to the default legacy voice, often Karen.

Independently compiled third-party binaries cannot use Siri natural voices either.
macOS exposes the Siri voices only to Apple-signed processes, such as the Swift interpreter in Xcode Command Line Tools.
`say-voice` therefore runs a small Swift script through the system Swift interpreter.
The script renders the text to a temporary CAF file with `AVSpeechSynthesizer` and plays the file with `afplay`.

## Requirements

- macOS 14 or later.
- Xcode Command Line Tools, so the `swift` interpreter is in `PATH`.
- At least one Siri voice installed for the language you want to use.

## Install

```sh
./scripts/install.sh
```

The install script builds the SwiftPM targets, generates the Swift script, and installs:

- the wrapper at `$BIN_DIR/say-voice`, default `~/.local/bin/say-voice`;
- the script at `$SHARE_DIR/say-voice.swift`, default `~/.local/share/say-voice/say-voice.swift`.

Set `BIN_DIR` or `SHARE_DIR` to install somewhere else:

```sh
BIN_DIR=/usr/local/bin SHARE_DIR=/usr/local/share/say-voice ./scripts/install.sh
```

The wrapper needs `swift` in `PATH`.
If the wrapper cannot find `swift`, install Xcode Command Line Tools.

To run from the repository without installing:

```sh
./scripts/dev.sh --help
```

The compiled binary at `.build/release/say-voice` is for development and tests.
It cannot see Siri natural voices.
Use the wrapper or `scripts/dev.sh` for Siri voices.

## Usage

```sh
say-voice "The light will fade to minimum and hold for three seconds."
say-voice --voice "english india voice 1" "The light will fade to minimum."
say-voice --voice riya "This uses Riya."
say-voice --voice "australia 2" "This uses Catherine."
say-voice --voice "india 2" "This uses Akash."
say-voice --voice "voice 3" "This uses the third installed voice."
```

Read text from standard input:

```sh
printf 'The light will fade to minimum.\n' | say-voice --voice riya
```

List the installed voices:

```sh
say-voice --list
say-voice --list --json
say-voice --list --voice "english india"
```

Resolve a voice without speaking:

```sh
say-voice --dry-run --voice "india 1"
say-voice --dry-run --json --voice "australia 2"
```

## Default voice

When you omit `--voice`, `say-voice` uses this order:

1. The Spoken Content default voice from `com.apple.Accessibility`.
2. The system speech default from `com.apple.speech.voice.prefs`.
3. The first Siri Voice 1 for the current locale.
4. The first Siri voice for the current locale.
5. The first installed Siri voice.

A non-Siri system default is ignored.
This keeps the default on the Siri natural voice family.

Use `--locale en-IN` to force the fallback for a locale.
This is useful when the system default is not the voice you want.

## Voice matching

The `--voice` value accepts aliases, not only the exact identifier.
Matching ignores case, punctuation, and diacritics.

Examples:

- `riya`
- `english india voice 1`
- `english india 1`
- `en-in 1`
- `enin 1`
- `india 2`
- `australia 2`
- `australian voice 3`
- `voice 4`
- `catherine`

A name, a language, a region, a voice number, or a combination of them can select a voice.
The matcher understands number words such as `one` and `two`.

If a query matches more than one voice, the command lists the candidates and exits.
If a query matches no voice, the command prints `Did you mean:` and lists installed options.
Run `say-voice --list` to see every installed voice.

## Voice downloads

macOS exposes only the voices that are installed.
Download more Siri voices in System Settings > Accessibility > Spoken Content > System Voice > Manage Voices.
After the download, `say-voice --list` shows the new voices.

## Options

| Option | Meaning |
| --- | --- |
| `-v`, `--voice <query>` | Select a voice by alias, name, language, region, or number. |
| `-l`, `--locale <code>` | Restrict the voice list to a locale such as `en-IN`. |
| `--list` | List matching installed voices. |
| `--all-voices` | Include non-Siri voices in the list and the search. |
| `--json` | Print machine-readable JSON. |
| `--dry-run` | Resolve the voice but do not speak. |
| `--rate <0...1>` | Set the speech rate. The default is `0.5`. |
| `--volume <0...1>` | Set the speech volume. The default is `1.0`. |
| `-h`, `--help` | Show the help text. |
| `--version` | Show the version. |

## Limitations

- This tool is macOS-only.
- The installed command needs Xcode Command Line Tools and the `swift` interpreter.
- The interpreter startup adds about one second to each command.
- The tool renders each utterance to a temporary CAF file and deletes it after playback.
- The compiled SwiftPM binary cannot use Siri natural voices.
- The tool does not download or install system voice assets.
- The tool does not save audio to a chosen file yet.

## Development

```sh
swift test
./scripts/build.sh
./scripts/dev.sh --list
```

The voice catalog, default lookup, and fuzzy matcher live in `Sources/SayVoiceCore`.
The command-line code lives in `Sources/SayVoiceCLI`.
`scripts/build.sh` concatenates the core and the CLI into `.build/say-voice.swift`.
The installed wrapper runs that script with `swift`.
Run `scripts/build.sh` after a source change to refresh the generated script.

<!-- LICENSE/ -->

## License

Unless stated otherwise all works are:

- Copyright &copy; [Benjamin Lupton](https://balupton.com)

and licensed under:

- [Reciprocal Public License 1.5](http://spdx.org/licenses/RPL-1.5.html)

<!-- /LICENSE -->
