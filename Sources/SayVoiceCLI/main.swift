import AVFoundation
import Darwin
import Foundation
import SayVoiceCore

private let version = "0.1.0"

private struct Options {
    var voiceQuery: String?
    var locale: String?
    var list = false
    var json = false
    var allVoices = false
    var dryRun = false
    var rate = AVSpeechUtteranceDefaultSpeechRate
    var volume: Float = 1.0
    var text: [String] = []
    var help = false
    var showVersion = false
}

private enum CLIError: Error, CustomStringConvertible {
    case usage(String)
    case noVoices(String)
    case invalidValue(String)
    case notFound(String, [VoiceOption])
    case ambiguous(String, [VoiceOption])
    case speech(SpeechError)

    var description: String {
        switch self {
        case let .usage(message), let .noVoices(message), let .invalidValue(message):
            return message
        case let .notFound(query, suggestions):
            return """
            No voice matched "\(query)".

            Did you mean:
            \(formatList(suggestions))
            Run `say-voice --list` to see all installed voices.
            """
        case let .ambiguous(query, candidates):
            return """
            More than one voice matched "\(query)".

            Did you mean:
            \(formatList(candidates))
            Add a language or a voice number to choose one.
            """
        case let .speech(error):
            return error.description
        }
    }

    var exitCode: Int32 {
        switch self {
        case .usage, .invalidValue:
            return 64
        case .noVoices, .notFound, .ambiguous:
            return 2
        case .speech:
            return 3
        }
    }
}

private struct SpeechResult: Codable {
    let voice: VoiceDescription
    let spoken: Bool
}

private func main() {
    do {
        let options = try parse(Array(CommandLine.arguments.dropFirst()))
        try run(options)
    } catch let error as CLIError {
        writeError("error: \(error.description)")
        exit(error.exitCode)
    } catch {
        writeError("error: \(error.localizedDescription)")
        exit(1)
    }
}

private func run(_ options: Options) throws {
    if options.help {
        writeOutput(usage())
        return
    }
    if options.showVersion {
        writeOutput("say-voice \(version)")
        return
    }

    let allVoices = VoiceCatalog.installed()
    var voices = options.allVoices ? allVoices : allVoices.filter(\.isSiri)
    if let locale = options.locale {
        let query = VoiceText.normalize(locale)
        voices = voices.filter { voice in
            let language = VoiceText.normalize(voice.language)
            return language == query || language.hasPrefix(query + " ")
        }
    }

    if options.list {
        try listVoices(options, voices: voices)
        return
    }

    guard !voices.isEmpty else {
        let kind = options.allVoices ? "voices" : "Siri voices"
        throw CLIError.noVoices(
            "No \(kind) are installed for \(options.locale ?? "this Mac"). Open System Settings > Accessibility > Spoken Content > System Voice > Manage Voices, then download an English Siri voice."
        )
    }

    let voice = try resolveVoice(options, voices: voices)
    if options.dryRun {
        if options.json {
            writeOutput(try encode(SpeechResult(voice: VoiceDescription(voice: voice), spoken: false)))
        } else {
            writeOutput(voice.displayName)
            writeOutput(voice.identifier)
        }
        return
    }

    var text = options.text.joined(separator: " ")
    if text.isEmpty && isatty(STDIN_FILENO) == 0 {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        text = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard !text.isEmpty else {
        throw CLIError.usage("No text to speak. Pass text as arguments or pipe it on stdin.")
    }

    let speaker = VoiceSpeaker()
    do {
        try speaker.speak(
            text: text,
            voice: voice,
            rate: options.rate,
            volume: options.volume
        )
    } catch let error as SpeechError {
        throw CLIError.speech(error)
    }

    if options.json {
        writeOutput(try encode(SpeechResult(voice: VoiceDescription(voice: voice), spoken: true)))
    }
}

private func resolveVoice(_ options: Options, voices: [VoiceOption]) throws -> VoiceOption {
    if let query = options.voiceQuery {
        switch VoiceMatcher.match(query: query, in: voices) {
        case let .match(voice):
            return voice
        case let .ambiguous(candidates):
            throw CLIError.ambiguous(query, candidates)
        case .notFound:
            throw CLIError.notFound(
                query,
                VoiceMatcher.suggestions(for: query, in: voices)
            )
        }
    }

    if let locale = options.locale {
        guard let voice = DefaultVoice.resolveForLocale(
            voices: voices,
            locale: Locale(identifier: locale)
        ) else {
            throw CLIError.noVoices(
                "No Siri voice is installed for \(locale). Download one in System Settings > Accessibility > Spoken Content > System Voice > Manage Voices."
            )
        }
        return voice
    }

    let siriVoices = voices.filter(\.isSiri)
    let defaultVoices = siriVoices.isEmpty ? voices : siriVoices
    guard let voice = DefaultVoice.resolve(voices: defaultVoices) else {
        throw CLIError.noVoices(
            "No Siri voice is installed. Open System Settings > Accessibility > Spoken Content > System Voice > Manage Voices, then download an English Siri voice."
        )
    }
    return voice
}

private func listVoices(_ options: Options, voices: [VoiceOption]) throws {
    var selected = voices
    if let query = options.voiceQuery {
        switch VoiceMatcher.match(query: query, in: voices) {
        case let .match(voice):
            selected = [voice]
        case let .ambiguous(candidates):
            selected = candidates
        case .notFound:
            selected = VoiceMatcher.suggestions(for: query, in: voices)
            if selected.isEmpty {
                throw CLIError.notFound(query, voices)
            }
        }
    }

    if options.json {
        writeOutput(try encode(selected.map(VoiceDescription.init)))
        return
    }

    let rows = selected.map { voice in
        [
            voice.properName ?? voice.name,
            voice.voiceNumber.map(String.init) ?? "-",
            voice.displayLanguage,
            voice.identifier,
        ]
    }
    let headers = ["NAME", "VOICE", "LANGUAGE", "IDENTIFIER"]
    var widths = headers.map(\.count)
    for row in rows {
        for (index, value) in row.enumerated() {
            widths[index] = max(widths[index], value.count)
        }
    }
    var lines = [formatRow(headers, widths: widths)]
    lines.append(contentsOf: rows.map { formatRow($0, widths: widths) })
    writeOutput(lines.joined(separator: "\n"))
}

private func formatRow(_ values: [String], widths: [Int]) -> String {
    values.enumerated().map { index, value in
        value.padding(
            toLength: widths[index] + (index == widths.count - 1 ? 0 : 2),
            withPad: " ",
            startingAt: 0
        )
    }.joined()
}

private func formatList(_ voices: [VoiceOption]) -> String {
    voices.map { voice in
        "  \(voice.displayName) - \(voice.identifier)"
    }.joined(separator: "\n")
}

private func encode<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(value)
    return String(decoding: data, as: UTF8.self)
}

private func writeOutput(_ value: String) {
    FileHandle.standardOutput.write(Data((value + "\n").utf8))
}

private func writeError(_ value: String) {
    FileHandle.standardError.write(Data((value + "\n").utf8))
}

private func parse(_ arguments: [String]) throws -> Options {
    var options = Options()
    var index = 0
    var positionalOnly = false

    func value(for argument: String, name: String) throws -> String {
        if let separator = argument.firstIndex(of: "=") {
            return String(argument[argument.index(after: separator)...])
        }
        index += 1
        guard index < arguments.count else {
            throw CLIError.usage("Missing value for \(name).")
        }
        return arguments[index]
    }

    while index < arguments.count {
        let argument = arguments[index]
        if positionalOnly {
            options.text.append(argument)
        } else if argument == "--" {
            positionalOnly = true
        } else if argument == "--help" || argument == "-h" {
            options.help = true
        } else if argument == "--version" {
            options.showVersion = true
        } else if argument == "--list" {
            options.list = true
        } else if argument == "--json" {
            options.json = true
        } else if argument == "--all-voices" {
            options.allVoices = true
        } else if argument == "--dry-run" {
            options.dryRun = true
        } else if argument == "--voice" || argument == "-v"
            || argument.hasPrefix("--voice=") || argument.hasPrefix("-v=")
        {
            options.voiceQuery = try value(for: argument, name: "--voice")
        } else if argument == "--locale" || argument == "-l"
            || argument.hasPrefix("--locale=") || argument.hasPrefix("-l=")
        {
            options.locale = try value(for: argument, name: "--locale")
        } else if argument == "--rate" || argument.hasPrefix("--rate=") {
            let raw = try value(for: argument, name: "--rate")
            guard let rate = Float(raw), (0...1).contains(rate) else {
                throw CLIError.invalidValue("Rate must be a number from 0 to 1.")
            }
            options.rate = rate
        } else if argument == "--volume" || argument.hasPrefix("--volume=") {
            let raw = try value(for: argument, name: "--volume")
            guard let volume = Float(raw), (0...1).contains(volume) else {
                throw CLIError.invalidValue("Volume must be a number from 0 to 1.")
            }
            options.volume = volume
        } else if argument.hasPrefix("-") {
            throw CLIError.usage("Unknown option: \(argument)\n\n\(usage())")
        } else {
            options.text.append(argument)
        }
        index += 1
    }
    return options
}

private func usage() -> String {
    """
    say-voice \(version)
    Speak text with an installed Siri voice on macOS.

    Usage:
      say-voice [options] <text...>
      say-voice --list [--json]
      say-voice --dry-run --voice <query>
      echo "text" | say-voice [options]

    Options:
      -v, --voice <query>   Voice alias, name, language, or number.
      -l, --locale <code>   Restrict voices to a locale, for example en-IN.
          --list            List matching installed voices.
          --all-voices      Include non-Siri voices.
          --json            Print machine-readable JSON.
          --dry-run         Resolve the voice but do not speak.
          --rate <0...1>    Speech rate. The default is 0.5.
          --volume <0...1>  Speech volume. The default is 1.0.
      -h, --help            Show this help.
          --version         Show the version.

    Voice aliases:
      riya
      english india voice 1
      india 2
      australia 2
      voice 3
      en-in 1

    Examples:
      say-voice "The light will fade to minimum."
      say-voice --voice "english india voice 1" "The light will fade to minimum."
      say-voice --voice riya "The light will fade to minimum."
      say-voice --voice "australia 2" "The light will fade to minimum."
      say-voice --list
      say-voice --dry-run --json --voice "india 1"
    """
}

main()
