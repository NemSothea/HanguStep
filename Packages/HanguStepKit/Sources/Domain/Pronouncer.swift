import Foundation

/// Speaks Korean text. Implemented with on-device TTS in the app layer (PRD FR-V5).
public protocol Pronouncer: Sendable {
    func speak(_ text: String) async
    /// Speaks a listening script line by line, one voice per speaker.
    func speak(_ script: ListeningScript) async
    func stop() async
}

public struct SilentPronouncer: Pronouncer {
    public init() {}
    public func speak(_ text: String) async {}
    public func speak(_ script: ListeningScript) async {}
    public func stop() async {}
}
