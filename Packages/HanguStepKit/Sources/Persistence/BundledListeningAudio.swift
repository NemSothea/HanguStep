import Domain
import Foundation

/// Recordings for listening questions in `Audio/listening/<question id>.m4a`,
/// generated offline with MeloTTS (Tools/listening-audio, ADR-011).
public struct BundledListeningAudio: ListeningAudioSource {
    public static let directory = "Audio/listening"
    private let root: URL?

    public init() {
        root = Bundle.module.resourceURL?.appendingPathComponent(Self.directory, isDirectory: true)
    }

    /// Recordings next to a content directory on disk (`content-lint` on the source tree).
    public init(contentDirectory: URL) {
        root = contentDirectory.deletingLastPathComponent().appendingPathComponent(Self.directory, isDirectory: true)
    }

    public func audioURL(for question: QuestionID) -> URL? {
        guard let url = root?.appendingPathComponent("\(question.rawValue).m4a"),
              FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return url
    }
}
