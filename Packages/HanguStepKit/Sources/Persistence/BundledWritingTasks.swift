import Domain
import Foundation

/// TOPIK II writing prompts shipped in `Content/writing/*.json` (ADR-012).
/// Read-only and small, so they are decoded on demand rather than imported into Core Data.
public struct BundledWritingTasks: WritingTaskRepository {
    public enum Error: Swift.Error, Equatable, CustomStringConvertible {
        case malformed(file: String, detail: String)
        case invalid(id: String, detail: String)

        public var description: String {
            switch self {
            case let .malformed(file, detail): return "\(file): \(detail)"
            case let .invalid(id, detail): return "\(id): \(detail)"
            }
        }
    }

    private let directory: URL?

    /// The prompts shipped with the app.
    public init() {
        directory = Bundle.module.url(forResource: BundledContent.directory, withExtension: nil)?.appendingPathComponent("writing", isDirectory: true)
    }

    /// Prompts under `<root>/writing`, for `content-lint` on the source tree.
    public init(contentDirectory root: URL) {
        directory = root.appendingPathComponent("writing", isDirectory: true)
    }

    public func tasks() async throws -> [WritingTask] {
        try load()
    }

    /// Decodes and validates every file. Throws on the first problem.
    public func load() throws -> [WritingTask] {
        guard let directory, let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        var tasks: [WritingTask] = []
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where file.pathExtension == "json" {
            let part: Part
            do {
                part = try JSONDecoder().decode(Part.self, from: Data(contentsOf: file))
            } catch {
                throw Error.malformed(file: "writing/\(file.lastPathComponent)", detail: String(describing: error))
            }
            tasks += try part.tasks.map { try $0.task() }
        }
        var seen = Set<WritingTaskID>()
        for task in tasks where !seen.insert(task.id).inserted {
            throw Error.invalid(id: task.id.rawValue, detail: "duplicate id")
        }
        return tasks
    }

    private struct Part: Decodable {
        let tasks: [Item]
    }

    private struct Item: Decodable {
        let id: String
        let type: WritingTaskType
        let level: Int
        let prompt: String
        let material: String
        let minLength: Int?
        let maxLength: Int?
        let modelAnswer: String
        let tips: ContentFile.Text

        func task() throws -> WritingTask {
            func fail(_ detail: String) -> Error { .invalid(id: id, detail: detail) }
            guard let topik = TOPIKLevel(rawValue: level) else { throw fail("level \(level)") }
            for (name, value) in [("prompt", prompt), ("material", material), ("modelAnswer", modelAnswer), ("tips.en", tips.en)] where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw fail("empty \(name)")
            }
            var range: ClosedRange<Int>?
            switch (minLength, maxLength) {
            case let (min?, max?) where min > 0 && min <= max: range = min...max
            case (nil, nil): range = nil
            default: throw fail("invalid length range")
            }
            if type == .shortAnswer {
                guard material.contains("㉠"), material.contains("㉡"), modelAnswer.contains("㉠"), modelAnswer.contains("㉡") else {
                    throw fail("short answer needs ㉠ and ㉡ in material and model answer")
                }
            } else {
                guard let range else { throw fail("\(type.rawValue) needs minLength and maxLength") }
                let count = WritingText.characterCount(modelAnswer)
                guard range.contains(count) else { throw fail("model answer is \(count) characters, outside \(range)") }
            }
            return WritingTask(
                id: WritingTaskID(id), type: type, level: topik, prompt: prompt, material: material,
                lengthRange: range, modelAnswer: modelAnswer, tips: Gloss(english: tips.en, khmer: tips.km)
            )
        }
    }
}
