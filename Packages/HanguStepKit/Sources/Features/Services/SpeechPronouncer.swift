import AVFoundation
import Domain
import Foundation

/// On-device Korean text-to-speech. No network, no audio files (PRD FR-V5).
/// Lives in Features because it is a platform presentation service, not persistence.
public actor SpeechPronouncer: Pronouncer {
    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    /// Best installed Korean voice: premium or enhanced when the learner downloaded one.
    private let voice = SpeechPronouncer.koreanVoices().first ?? AVSpeechSynthesisVoice(language: "ko-KR")

    public init() {}

    public func speak(_ text: String) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }

    /// Queues one utterance per line. Speakers get different Korean voices when the
    /// device has both genders installed; otherwise the man's lines are pitched slightly lower.
    /// Enhanced or premium voices are preferred when the learner has downloaded them.
    public func speak(_ script: ListeningScript) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let voices = Self.speakerVoices()
        for line in script.lines {
            let utterance = AVSpeechUtterance(string: line.text)
            let assigned = voices[line.speaker] ?? (voice, 1.0)
            utterance.voice = assigned.voice
            utterance.pitchMultiplier = assigned.pitch
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
            utterance.postUtteranceDelay = 0.5
            synthesizer.speak(utterance)
        }
    }

    /// Plays a bundled recording. Listening practice uses these when present (ADR-011).
    public func play(_ audio: URL) {
        stop()
        #if os(iOS)
        // Spoken audio the learner asked for: plays with the ring switch on silent.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        player = try? AVAudioPlayer(contentsOf: audio)
        player?.play()
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        player?.stop()
        player = nil
    }

    /// False when the device has no Korean voice installed.
    public static var isKoreanVoiceAvailable: Bool {
        AVSpeechSynthesisVoice(language: "ko-KR") != nil
    }

    private static func speakerVoices() -> [ListeningScript.Speaker: (voice: AVSpeechSynthesisVoice?, pitch: Float)] {
        let korean = koreanVoices()
        let best = korean.first ?? AVSpeechSynthesisVoice(language: "ko-KR")
        let woman = korean.first { $0.gender != .male } ?? best
        if let man = korean.first(where: { $0.gender == .male }) {
            return [.man: (man, 1.0), .woman: (woman, 1.0), .narrator: (woman, 1.0)]
        }
        // One voice only: a slight pitch drop keeps the man distinct without sounding synthetic.
        return [.man: (woman, 0.9), .woman: (woman, 1.0), .narrator: (woman, 1.0)]
    }

    /// Installed Korean voices, best quality first (premium, enhanced, default).
    private static func koreanVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "ko-KR" }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
    }
}
