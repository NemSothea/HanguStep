import Domain
import Foundation

/// The content library shipped inside the app: `Content/package.json` plus part
/// files under `Content/vocabulary`, `Content/grammar`, `Content/questions`.
public enum BundledContent {
    public static let directory = "Content"

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
