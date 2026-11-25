import AVFoundation
import Foundation

public enum VoiceCatalog {
    /// Every voice that AVSpeechSynthesizer exposes on this Mac.
    public static func installed() -> [VoiceOption] {
        var seen = Set<String>()
        return AVSpeechSynthesisVoice.speechVoices()
            .map(VoiceOption.init)
            .filter { seen.insert($0.identifier).inserted }
            .sorted(by: isOrderedBefore)
    }

    /// Voices that belong to the Siri natural voice family.
    public static func siriVoices() -> [VoiceOption] {
        installed().filter(\.isSiri)
    }

    /// Siri natural voices for English locales.
    public static func englishSiriVoices() -> [VoiceOption] {
        siriVoices().filter { $0.languageCode == "en" }
    }

    /// Siri voices for one language, such as `en` or `en-AU`.
    public static func siriVoices(matching language: String) -> [VoiceOption] {
        let query = VoiceText.normalize(language)
        let compact = VoiceText.compact(language)
        return siriVoices().filter { voice in
            let normalized = VoiceText.normalize(voice.language)
            return normalized == query
                || VoiceText.compact(voice.language) == compact
                || normalized.hasPrefix(query + " ")
        }
    }

    private static func isOrderedBefore(_ left: VoiceOption, _ right: VoiceOption) -> Bool {
        if left.language != right.language {
            return left.language < right.language
        }
        let leftNumber = left.voiceNumber ?? Int.max
        let rightNumber = right.voiceNumber ?? Int.max
        if leftNumber != rightNumber {
            return leftNumber < rightNumber
        }
        return left.displayName.localizedCaseInsensitiveCompare(right.displayName) == .orderedAscending
    }
}
