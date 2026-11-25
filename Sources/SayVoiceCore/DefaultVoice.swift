import CoreFoundation
import Foundation

/// The voice macOS selected for Spoken Content or for the system speech service.
public struct SystemDefaultVoice: Equatable, Sendable {
    public let identifier: String?
    public let name: String?

    public init(identifier: String? = nil, name: String? = nil) {
        self.identifier = identifier
        self.name = name
    }
}

public enum DefaultVoice {
    /// The system preference is the first choice. The locale is only a fallback.
    public static func resolve(
        voices: [VoiceOption],
        locale: Locale = .current,
        systemDefault: SystemDefaultVoice = systemDefault()
    ) -> VoiceOption? {
        let siriVoices = voices.filter(\.isSiri)
        let candidates = siriVoices.isEmpty ? voices : siriVoices
        if let identifier = systemDefault.identifier,
            let match = matchIdentifier(identifier, in: candidates)
        {
            return match
        }
        if let name = systemDefault.name,
            case let .match(voice) = VoiceMatcher.match(query: name, in: candidates)
        {
            return voice
        }
        return resolveForLocale(voices: candidates, locale: locale)
    }

    /// Pick the locale's Voice 1, then the first Siri voice for that locale.
    public static func resolveForLocale(
        voices: [VoiceOption],
        locale: Locale
    ) -> VoiceOption? {
        let siriVoices = voices.filter(\.isSiri)
        let candidates = siriVoices.isEmpty ? voices : siriVoices
        let language = locale.language.languageCode?.identifier ?? "en"
        let region = locale.region?.identifier
        let languageVoices = candidates.filter { $0.languageCode == language }
        guard !languageVoices.isEmpty else {
            return candidates.first
        }
        let regional = region.map { region in
            languageVoices.filter { $0.regionCode == region }
        } ?? []
        let regionalCandidates = regional.isEmpty ? languageVoices : regional
        return regionalCandidates.first { $0.voiceNumber == 1 } ?? regionalCandidates.first
    }

    /// Reads the current user's Spoken Content and speech defaults.
    public static func systemDefault() -> SystemDefaultVoice {
        if let identifier = spokenContentIdentifier() {
            return SystemDefaultVoice(identifier: identifier)
        }
        if let identifier = speechIdentifier() {
            return SystemDefaultVoice(identifier: identifier)
        }
        if let name = speechSelectedName() {
            return SystemDefaultVoice(name: name)
        }
        return SystemDefaultVoice()
    }

    private static func matchIdentifier(
        _ identifier: String,
        in voices: [VoiceOption]
    ) -> VoiceOption? {
        if let exact = voices.first(where: { $0.identifier == identifier }) {
            return exact
        }
        let normalized = VoiceText.normalize(identifier)
        let compact = VoiceText.compact(identifier)
        let named = voices.filter { voice in
            guard let properName = voice.properName else { return false }
            let name = VoiceText.normalize(properName)
            return normalized.contains(name) || compact.contains(VoiceText.compact(properName))
        }
        if named.count == 1 {
            return named[0]
        }
        let localized = named.filter { voice in
            let language = VoiceText.normalize(voice.language)
            return normalized.contains(language)
                || compact.contains(VoiceText.compact(voice.language))
        }
        if localized.count == 1 {
            return localized[0]
        }
        return localized.first ?? named.first
    }

    private static func spokenContentIdentifier() -> String? {
        guard let value = preference(
            domain: "com.apple.Accessibility",
            key: "SpokenContentDefaultVoiceSelectionsByLanguage"
        ), let entries = value as? [Any] else {
            return nil
        }
        let currentLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        var firstIdentifier: String?
        var index = 0
        while index + 1 < entries.count {
            let language = entries[index] as? String
            let selection = entries[index + 1] as? [String: Any]
            if let identifier = selection?["voiceId"] as? String {
                if firstIdentifier == nil {
                    firstIdentifier = identifier
                }
                if language == currentLanguage || language == "en" {
                    return identifier
                }
            }
            index += 2
        }
        return firstIdentifier
    }

    private static func speechIdentifier() -> String? {
        guard let value = preference(
            domain: "com.apple.Accessibility",
            key: "SpeechVoiceIdentifierForLanguage"
        ), let groups = value as? [String: Any] else {
            return nil
        }
        let currentLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        var firstIdentifier: String?
        for group in groups.values {
            guard let languages = group as? [String: Any] else { continue }
            for (language, value) in languages {
                guard let identifier = value as? String else { continue }
                if firstIdentifier == nil {
                    firstIdentifier = identifier
                }
                if language == currentLanguage || language == "en" {
                    return identifier
                }
            }
        }
        return firstIdentifier
    }

    private static func speechSelectedName() -> String? {
        preference(
            domain: "com.apple.speech.voice.prefs",
            key: "SelectedVoiceName"
        ) as? String
    }

    private static func preference(domain: String, key: String) -> Any? {
        guard let value = CFPreferencesCopyAppValue(
            key as CFString,
            domain as CFString
        ) else {
            return nil
        }
        return value
    }
}
