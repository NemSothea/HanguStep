import Domain
import Foundation

/// The content library shipped inside the app: `Content/package.json` plus part
/// files under `Content/vocabulary`, `Content/grammar`, `Content/questions`.
public enum BundledContent {
    public static let directory = "Content"
    /// Precomputed `ContentInfo` for the bundled library, written by
    /// `content-lint generate-questions`. Lets a warm launch skip decoding the library.
    public static let summaryFile = "summary.json"

    /// Loads, merges and validates the bundled library (AC-10). Throws rather than
    /// returning a partial package so a broken bundle fails loudly at launch.
    public static func load() throws -> ContentFile.LoadResult {
        try load(from: .module)
    }

    public static func load(from bundle: Bundle) throws -> ContentFile.LoadResult {
        guard let root = bundle.url(forResource: directory, withExtension: nil) else {
            throw ContentFile.Error.malformed(file: "\(directory)/", detail: "missing from bundle")
        }
        return try load(directory: root)
    }

    /// The precomputed summary of the library shipped in this module.
    public static func summary() -> ContentInfo? {
        summary(from: .module)
    }

    /// The precomputed summary, or nil when the bundle has none.
    public static func summary(from bundle: Bundle) -> ContentInfo? {
        bundle.url(forResource: directory, withExtension: nil).flatMap { summary(directory: $0) }
    }

    /// The summary stored in a library directory on disk, or nil.
    public static func summary(directory root: URL) -> ContentInfo? {
        guard let data = try? Data(contentsOf: root.appendingPathComponent(summaryFile)) else { return nil }
        return try? JSONDecoder().decode(ContentInfo.self, from: data)
    }

    /// Writes `summary.json` for a library directory on disk (`content-lint`).
    public static func writeSummary(_ info: ContentInfo, directory root: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try (encoder.encode(info) + Data("\n".utf8)).write(to: root.appendingPathComponent(summaryFile))
    }

    /// Same, from any directory on disk. Used by `content-lint` on the source tree.
    public static func load(directory root: URL) throws -> ContentFile.LoadResult {
        let packageURL = root.appendingPathComponent("package.json")
        guard let packageData = try? Data(contentsOf: packageURL) else {
            throw ContentFile.Error.malformed(file: "package.json", detail: "missing at \(packageURL.path)")
        }
        var parts: [(name: String, data: Data)] = []
        for folder in ["vocabulary", "grammar", "questions"] {
            let folderURL = root.appendingPathComponent(folder, isDirectory: true)
            guard let files = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.pathExtension == "json" {
                parts.append((name: "\(folder)/\(file.lastPathComponent)", data: try Data(contentsOf: file)))
            }
        }
        return try ContentFile.load(package: packageData, parts: parts)
    }
}

public extension ContentFile.LoadResult {
    /// What Settings shows about this library.
    var info: ContentInfo {
        ContentInfo(
            version: package.version,
            vocabularyCount: package.vocabulary.count,
            grammarCount: package.grammar.count,
            questionCount: package.questions.count,
            sourceName: source.name,
            license: source.license,
            pendingReview: pendingReview,
            credits: package.importedCredits
        )
    }
}
