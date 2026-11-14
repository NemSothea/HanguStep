import Foundation

/// Speaks Korean text. Implemented with on-device TTS in the app layer (PRD FR-V5).
public protocol Pronouncer: Sendable {
    func speak(_ text: String) async
    /// Speaks a listening script line by line, one voice per speaker.
    func speak(_ script: ListeningScript) async
    /// Plays a bundled recording (listening audio, ADR-011).
    func play(_ audio: URL) async
    func stop() async
}

/// Pre-recorded audio for listening questions, when the bundle has it.
public protocol ListeningAudioSource: Sendable {
    func audioURL(for question: QuestionID) -> URL?
}

public struct NoListeningAudio: ListeningAudioSource {
    public init() {}
    public func audioURL(for question: QuestionID) -> URL? { nil }
}

public struct SilentPronouncer: Pronouncer {
    public init() {}
    public func speak(_ text: String) async {}
    public func speak(_ script: ListeningScript) async {}
    public func play(_ audio: URL) async {}
    public func stop() async {}
}
