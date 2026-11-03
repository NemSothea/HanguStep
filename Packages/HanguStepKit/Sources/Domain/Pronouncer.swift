import Foundation

/// Speaks Korean text. Implemented with on-device TTS in the app layer (PRD FR-V5).
public protocol Pronouncer: Sendable {
    func speak(_ text: String) async
    func stop() async
}

public struct SilentPronouncer: Pronouncer {
    public init() {}
    public func speak(_ text: String) async {}
    public func stop() async {}
}
