import XCTest
@testable import SayVoiceCore

final class VoiceMatcherTests: XCTestCase {
    private let riya = VoiceOption(
        identifier: "com.apple.siri.natural.Riya",
        name: "Voice 1",
        language: "en-IN"
    )
    private let akash = VoiceOption(
        identifier: "com.apple.siri.natural.Akash",
        name: "Voice 2",
        language: "en-IN"
    )
    private let catherine = VoiceOption(
        identifier: "com.apple.siri.natural.Catherine",
        name: "Voice 2",
        language: "en-AU"
    )
    private let voiceThree = VoiceOption(
        identifier: "com.apple.siri.natural.en-AU-C",
        name: "Voice 3",
        language: "en-AU"
    )
    private let voiceFour = VoiceOption(
        identifier: "com.apple.siri.natural.en-AU-D",
        name: "Voice 4",
        language: "en-AU"
    )
    private let karen = VoiceOption(
        identifier: "com.apple.voice.compact.en-AU.Karen",
        name: "Karen",
        language: "en-AU"
    )

    private var voices: [VoiceOption] {
        [riya, akash, catherine, voiceThree, voiceFour, karen]
    }

    func testMatchesProperName() {
        XCTAssertEqual(VoiceMatcher.match(query: "riya", in: voices), .match(riya))
        XCTAssertEqual(VoiceMatcher.match(query: "Catherine", in: voices), .match(catherine))
        XCTAssertEqual(VoiceMatcher.match(query: "akash", in: voices), .match(akash))
    }

    func testMatchesLanguageAndVoiceNumber() {
        XCTAssertEqual(
            VoiceMatcher.match(query: "english india voice 1", in: voices),
            .match(riya)
        )
        XCTAssertEqual(
            VoiceMatcher.match(query: "english india voice 2", in: voices),
            .match(akash)
        )
        XCTAssertEqual(
            VoiceMatcher.match(query: "australia voice 2", in: voices),
            .match(catherine)
        )
        XCTAssertEqual(
            VoiceMatcher.match(query: "australia 3", in: voices),
            .match(voiceThree)
        )
    }

    func testMatchesNumberWordsAndCompactLocale() {
        XCTAssertEqual(
            VoiceMatcher.match(query: "english india voice one", in: voices),
            .match(riya)
        )
        XCTAssertEqual(VoiceMatcher.match(query: "enin 1", in: voices), .match(riya))
        XCTAssertEqual(VoiceMatcher.match(query: "en-au voice 4", in: voices), .match(voiceFour))
    }

    func testAmbiguousVoiceNumber() {
        guard case let .ambiguous(candidates) =
            VoiceMatcher.match(query: "voice 2", in: voices)
        else {
            return XCTFail("Expected an ambiguous match.")
        }
        XCTAssertEqual(
            Set(candidates.map(\.identifier)),
            Set([catherine.identifier, akash.identifier])
        )
    }

    func testMissingAccentIsNotFound() {
        guard case .notFound = VoiceMatcher.match(query: "british voice 3", in: voices) else {
            return XCTFail("Expected no match for an uninstalled accent.")
        }
    }

    func testSuggestionsReturnInstalledVoices() {
        let suggestions = VoiceMatcher.suggestions(for: "british voice 3", in: voices)
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.contains { $0.identifier == voiceThree.identifier })
    }

    func testSystemIdentifierWins() {
        let defaultVoice = SystemDefaultVoice(identifier: riya.identifier)
        XCTAssertEqual(
            DefaultVoice.resolve(
                voices: voices,
                locale: Locale(identifier: "en_AU"),
                systemDefault: defaultVoice
            ),
            riya
        )
    }

    func testNonSiriDefaultFallsBackToLocaleVoiceOne() {
        let defaultVoice = SystemDefaultVoice(identifier: karen.identifier)
        XCTAssertEqual(
            DefaultVoice.resolve(
                voices: voices,
                locale: Locale(identifier: "en_IN"),
                systemDefault: defaultVoice
            ),
            riya
        )
        XCTAssertEqual(
            DefaultVoice.resolve(
                voices: voices,
                locale: Locale(identifier: "en_AU"),
                systemDefault: defaultVoice
            ),
            catherine
        )
    }

    func testGryphonIdentifierMapsToSiriVoice() {
        let defaultVoice = SystemDefaultVoice(
            identifier: "com.apple.ttsbundle.gryphon-neural_riya_en-IN_premium"
        )
        XCTAssertEqual(
            DefaultVoice.resolve(
                voices: voices,
                locale: Locale(identifier: "en_AU"),
                systemDefault: defaultVoice
            ),
            riya
        )
    }

    func testVoiceMetadata() {
        XCTAssertEqual(riya.voiceNumber, 1)
        XCTAssertEqual(riya.properName, "Riya")
        XCTAssertEqual(riya.regionName, "India")
        XCTAssertEqual(riya.languageName, "English")
        XCTAssertEqual(riya.isSiri, true)
        XCTAssertEqual(karen.isSiri, false)
        XCTAssertEqual(voiceThree.properName, nil)
        XCTAssertEqual(voiceThree.voiceNumber, 3)
    }
}
