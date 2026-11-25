@preconcurrency import AVFoundation
import Foundation

public enum SpeechError: Error, CustomStringConvertible, Equatable {
    case noText
    case voiceUnavailable(String)
    case noAudio
    case timedOut
    case playback(String)

    public var description: String {
        switch self {
        case .noText:
            return "no text to speak"
        case let .voiceUnavailable(identifier):
            return "the voice is not available: \(identifier)"
        case .noAudio:
            return "the synthesizer produced no audio"
        case .timedOut:
            return "speech did not finish before the timeout"
        case let .playback(message):
            return "audio playback failed: \(message)"
        }
    }
}

/// Renders one utterance to a temporary file, then plays it with afplay.
///
/// The system Swift interpreter can use Siri natural voices. A compiled
/// third-party binary cannot enumerate or construct them. The installed
/// command runs this code through `swift`, so the requested Siri voice is the
/// voice that speaks.
public final class VoiceSpeaker {
    public init() {}

    public func speak(
        text: String,
        voice: VoiceOption,
        rate: Float = AVSpeechUtteranceDefaultSpeechRate,
        volume: Float = 1.0,
        timeout: TimeInterval = 120
    ) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SpeechError.noText
        }
        guard let avVoice = AVSpeechSynthesisVoice(identifier: voice.identifier) else {
            throw SpeechError.voiceUnavailable(voice.identifier)
        }

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("say-voice-\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: output) }

        let lock = NSLock()
        var finished = false
        var audioFile: AVAudioFile?
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = avVoice
        utterance.rate = max(0, min(1, rate))
        utterance.volume = max(0, min(1, volume))

        synthesizer.write(utterance) { buffer in
            guard let pcm = buffer as? AVAudioPCMBuffer else { return }
            lock.lock()
            defer { lock.unlock() }
            if pcm.frameLength == 0 {
                finished = true
                return
            }
            if audioFile == nil {
                audioFile = try? AVAudioFile(
                    forWriting: output,
                    settings: pcm.format.settings
                )
            }
            try? audioFile?.write(from: pcm)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while true {
            lock.lock()
            let done = finished
            lock.unlock()
            if done { break }
            if Date() >= deadline {
                throw SpeechError.timedOut
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: output.path),
            let size = attributes[.size] as? NSNumber,
            size.intValue > 0
        else {
            throw SpeechError.noAudio
        }

        let player = Process()
        player.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
        player.arguments = ["-v", String(max(0, min(1, volume))), output.path]
        do {
            try player.run()
        } catch {
            throw SpeechError.playback(error.localizedDescription)
        }
        player.waitUntilExit()
        guard player.terminationStatus == 0 else {
            throw SpeechError.playback("afplay exited with status \(player.terminationStatus)")
        }
    }
}
