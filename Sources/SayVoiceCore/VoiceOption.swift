import AVFoundation
import Foundation

/// One installed speech voice, reduced to the values this tool needs.
public struct VoiceOption: Hashable, Sendable {
    public let identifier: String
    public let name: String
    public let language: String
    public let quality: Int
    public let isSiri: Bool

    public init(
        identifier: String,
        name: String,
        language: String,
        quality: Int = 0,
        isSiri: Bool? = nil
    ) {
        self.identifier = identifier
        self.name = name
        self.language = language
        self.quality = quality
        self.isSiri = isSiri ?? identifier.localizedCaseInsensitiveContains("siri")
    }

    public init(voice: AVSpeechSynthesisVoice) {
        self.init(
            identifier: voice.identifier,
            name: voice.name,
            language: voice.language,
            quality: voice.quality.rawValue
        )
    }

    /// The private name in an identifier, for example `Riya` or `Catherine`.
    /// Locale-only identifiers such as `en-AU-C` have no proper name.
    public var properName: String? {
        let ignored: Set<String> = [
            "com", "apple", "siri", "natural", "speech", "synthesis", "voice",
            "custom", "premium", "enhanced", "ttsbundle", "gryphon", "neural",
            "compact", "super", "female", "male",
        ]
        let separators = CharacterSet(charactersIn: ".-_")
        let parts = identifier
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
        let candidate = parts.last { part in
            let lower = part.lowercased()
            return lower.count >= 3
                && !ignored.contains(lower)
                && part.rangeOfCharacter(from: .letters) != nil
                && part.rangeOfCharacter(from: .decimalDigits) == nil
        }
        guard let candidate else { return nil }
        return candidate.prefix(1).uppercased() + candidate.dropFirst().lowercased()
    }

    /// The Siri voice option number, for example `1` in `Voice 1`.
    public var voiceNumber: Int? {
        let digits = name.filter(\.isNumber)
        if !digits.isEmpty {
            return Int(digits)
        }
        let normalized = VoiceText.normalize(name)
        guard let range = normalized.range(
            of: #"voice\s*([0-9]+)"#,
            options: .regularExpression
        ) else {
            return nil
        }
        return Int(normalized[range].filter(\.isNumber))
    }

    public var languageCode: String {
        Locale(identifier: language).language.languageCode?.identifier ?? language
    }

    public var regionCode: String? {
        Locale(identifier: language).region?.identifier
    }

    public var languageName: String {
        Self.namingLocale.localizedString(forLanguageCode: languageCode)?.capitalized
            ?? languageCode
    }

    public var regionName: String? {
        guard let regionCode else { return nil }
        return Self.namingLocale.localizedString(forRegionCode: regionCode)
    }

    public var displayLanguage: String {
        guard let regionName, !regionName.isEmpty else { return languageName }
        return "\(languageName) (\(regionName))"
    }

    public var displayName: String {
        if let properName {
            return "\(properName) - \(name) - \(displayLanguage)"
        }
        return "\(name) - \(displayLanguage)"
    }

    public var aliases: [String] {
        var values = [
            identifier,
            name,
            displayName,
            language,
            languageName,
            displayLanguage,
        ]
        if let properName {
            values.append(properName)
        }
        if let regionName {
            values.append(regionName)
            values.append("\(languageName) \(regionName)")
            values.append("\(regionName) \(languageName)")
        }
        if let voiceNumber {
            values.append("voice \(voiceNumber)")
            values.append("\(voiceNumber)")
            values.append("voice \(VoiceText.spelledNumber(voiceNumber))")
            values.append(VoiceText.spelledNumber(voiceNumber))
        }
        values.append(contentsOf: VoiceText.localeAliases(for: language))
        values.append(contentsOf: VoiceText.regionAliases(for: regionCode))
        return values
    }

    private static let namingLocale = Locale(identifier: "en_US")
}

/// A stable, machine-readable form of a voice.
public struct VoiceDescription: Codable, Sendable {
    public let identifier: String
    public let name: String
    public let language: String
    public let languageName: String
    public let regionName: String?
    public let properName: String?
    public let displayName: String
    public let voiceNumber: Int?
    public let quality: Int
    public let isSiri: Bool

    public init(voice: VoiceOption) {
        self.identifier = voice.identifier
        self.name = voice.name
        self.language = voice.language
        self.languageName = voice.displayLanguage
        self.regionName = voice.regionName
        self.properName = voice.properName
        self.displayName = voice.displayName
        self.voiceNumber = voice.voiceNumber
        self.quality = voice.quality
        self.isSiri = voice.isSiri
    }
}

public enum VoiceText {
    public static func normalize(_ value: String) -> String {
        value
            .folding(
                options: [.diacriticInsensitive, .caseInsensitive],
                locale: Locale(identifier: "en_US")
            )
            .replacingOccurrences(
                of: #"[^a-z0-9]+"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func compact(_ value: String) -> String {
        normalize(value).replacingOccurrences(of: " ", with: "")
    }

    public static func tokens(_ value: String) -> Set<String> {
        Set(normalize(value).split(separator: " ").map(String.init))
    }

    static func spelledNumber(_ number: Int) -> String {
        let names = [
            "zero", "one", "two", "three", "four", "five",
            "six", "seven", "eight", "nine", "ten",
        ]
        guard names.indices.contains(number) else { return "\(number)" }
        return names[number]
    }

    static func numberValue(_ token: String) -> Int? {
        if let value = Int(token) { return value }
        let names = [
            "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        ]
        return names[token]
    }

    static func localeAliases(for language: String) -> [String] {
        let compact = compact(language)
        return [language, compact, normalize(language)]
    }

    static func regionAliases(for region: String?) -> [String] {
        guard let region else { return [] }
        switch region.uppercased() {
        case "US":
            return ["american", "america", "usa", "us"]
        case "GB":
            return ["british", "britain", "uk", "england", "english uk"]
        case "AU":
            return ["australian", "australia", "aussie", "oz"]
        case "IN":
            return ["indian", "india"]
        case "IE":
            return ["irish", "ireland"]
        case "ZA":
            return ["south african", "south africa"]
        case "NZ":
            return ["new zealander", "new zealand", "kiwi"]
        case "CA":
            return ["canadian", "canada"]
        case "SG":
            return ["singaporean", "singapore"]
        default:
            return [region]
        }
    }
}
