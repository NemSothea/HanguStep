import AVFoundation
import Domain
import Foundation

/// On-device Korean text-to-speech. No network, no audio files (PRD FR-V5).
/// Lives in Features because it is a platform presentation service, not persistence.
public actor SpeechPronouncer: Pronouncer {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "ko-KR")

    public init() {}

    public func speak(_ text: String) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// False when the device has no Korean voice installed.
    public static var isKoreanVoiceAvailable: Bool {
        AVSpeechSynthesisVoice(language: "ko-KR") != nil
    }
}
