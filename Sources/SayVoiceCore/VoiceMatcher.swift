import Foundation

public enum VoiceMatch: Equatable {
    case match(VoiceOption)
    case ambiguous([VoiceOption])
    case notFound
}

public enum VoiceMatcher {
    private static let stopWords: Set<String> = [
        "voice", "siri", "natural", "premium", "enhanced", "compact", "super",
        "the", "a", "an", "my", "default", "female", "male", "please",
        "accent", "dialect", "language", "speak", "say",
    ]

    public static func match(query: String, in voices: [VoiceOption]) -> VoiceMatch {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !voices.isEmpty else { return .notFound }

        let normalizedQuery = VoiceText.normalize(trimmed)
        let compactQuery = VoiceText.compact(trimmed)
        var queryTokens = VoiceText.tokens(trimmed)
        for token in queryTokens where VoiceText.numberValue(token) != nil {
            if let value = VoiceText.numberValue(token) {
                queryTokens.insert("\(value)")
            }
        }
        let required = {
            let filtered = queryTokens.subtracting(stopWords)
            return filtered.isEmpty ? queryTokens : filtered
        }()
        let queryNumber = queryTokens.compactMap(VoiceText.numberValue).first

        var scored: [(voice: VoiceOption, score: Int)] = []
        for voice in voices {
            let aliases = voice.aliases
            let aliasNormalized = Set(aliases.map(VoiceText.normalize))
            let aliasCompact = Set(aliases.map(VoiceText.compact))
            var voiceTokens = Set<String>()
            for alias in aliases {
                voiceTokens.formUnion(VoiceText.tokens(alias))
                voiceTokens.insert(VoiceText.compact(alias))
            }

            if aliasNormalized.contains(normalizedQuery) {
                scored.append((voice, 10_000))
                continue
            }
            if aliasCompact.contains(compactQuery) {
                scored.append((voice, 9_000))
                continue
            }
            if let properName = voice.properName,
                VoiceText.normalize(properName) == normalizedQuery
            {
                scored.append((voice, 8_000))
                continue
            }

            let missing = required.filter { !voiceTokens.contains($0) }
            if missing.isEmpty {
                var score = 1_000 + queryTokens.count * 100
                if let queryNumber, queryNumber == voice.voiceNumber {
                    score += 500
                }
                if let properName = voice.properName,
                    queryTokens.contains(VoiceText.normalize(properName))
                {
                    score += 500
                }
                if let regionName = voice.regionName,
                    queryTokens.contains(VoiceText.normalize(regionName))
                {
                    score += 200
                }
                scored.append((voice, score))
                continue
            }

            // A prefix is enough for a short query such as "cath".
            if required.allSatisfy({ token in
                token.count >= 3 && voiceTokens.contains(where: { $0.hasPrefix(token) })
            }) {
                scored.append((voice, 500 + queryTokens.count * 10))
            }
        }

        guard let best = scored.map(\.score).max(), best > 0 else {
            return .notFound
        }
        let top = scored.filter { $0.score == best }.map(\.voice)
        if top.count == 1 {
            return .match(top[0])
        }
        return .ambiguous(top)
    }

    /// A short list for "did you mean" output. It ranks shared tokens first,
    /// then returns the remaining installed voices so the user always sees
    /// real options.
    public static func suggestions(
        for query: String,
        in voices: [VoiceOption],
        limit: Int = 8
    ) -> [VoiceOption] {
        let queryTokens = VoiceText.tokens(query)
        let ranked = voices
            .map { voice -> (VoiceOption, Int) in
                let tokens = Set(voice.aliases.flatMap { VoiceText.tokens($0) })
                let shared = queryTokens.filter { token in
                    tokens.contains(token)
                        || (token.count >= 3 && tokens.contains(where: { $0.hasPrefix(token) }))
                }
                return (voice, shared.count)
            }
            .sorted { left, right in
                if left.1 != right.1 { return left.1 > right.1 }
                return left.0.displayName.localizedCaseInsensitiveCompare(right.0.displayName)
                    == .orderedAscending
            }
        return ranked.prefix(limit).map(\.0)
    }
}
