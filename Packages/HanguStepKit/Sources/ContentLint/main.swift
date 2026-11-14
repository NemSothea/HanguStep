import Domain
import Foundation
import Persistence

/// Content authoring tool.
///
///   swift run content-lint [path]                      validate and summarise
///   swift run content-lint generate-questions [path]   write questions/generated-meaning.json and summary.json
///
/// `path` defaults to the bundled content directory in the source tree.
let arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first.flatMap { $0.hasPrefix("-") || $0.contains("/") ? nil : $0 } ?? "lint"
let pathArgument = arguments.last.flatMap { $0.contains("/") ? $0 : nil }
let defaultPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Persistence/Resources/Content", isDirectory: true)
let root = pathArgument.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? defaultPath

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func summarise(_ result: ContentFile.LoadResult) {
    let package = result.package
    print("content version \(package.version) · \(result.source.name) · \(result.source.license)")
    print("vocabulary \(package.vocabulary.count) · grammar \(package.grammar.count) · questions \(package.questions.count)")
    for level in TOPIKLevel.allCases {
        let v = package.vocabulary.filter { $0.level == level }.count
        let g = package.grammar.filter { $0.level == level }.count
        let q = package.questions.filter { $0.level == level }.count
        if v + g + q > 0 { print("  level \(level.rawValue): \(v) words, \(g) patterns, \(q) questions") }
    }
    let targets = Set(package.questions.compactMap(\.learningTarget))
    let untargeted = package.vocabulary.filter { !targets.contains(.vocabulary($0.id)) }.count
    print("vocabulary without a question: \(untargeted) · items pending Khmer review: \(result.pendingReview)")
}

switch command {
case "lint":
    do {
        let result = try BundledContent.load(directory: root)
        summarise(result)
        guard BundledContent.summary(directory: root) == result.info else {
            fail("FAIL \(BundledContent.summaryFile) is missing or stale: run `swift run content-lint generate-questions`")
        }
        let writing = try BundledWritingTasks(contentDirectory: root).load()
        let byType = Dictionary(grouping: writing, by: \.type)
        print("writing tasks \(writing.count): " + WritingTaskType.allCases.map { "\($0.rawValue) \(byType[$0]?.count ?? 0)" }.joined(separator: " · "))
        print("OK")
    } catch {
        fail("FAIL \(error)")
    }
case "generate-questions":
    let packageURL = root.appendingPathComponent("package.json")
    let vocabularyURL = root.appendingPathComponent("vocabulary", isDirectory: true)
    guard let packageData = try? Data(contentsOf: packageURL),
          let package = try? ContentFile.decoder().decode(ContentFile.Package.self, from: packageData)
    else { fail("cannot read \(packageURL.path)") }
    var vocabulary = package.vocabulary
    let files = (try? FileManager.default.contentsOfDirectory(at: vocabularyURL, includingPropertiesForKeys: nil)) ?? []
    for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where file.pathExtension == "json" {
        guard let data = try? Data(contentsOf: file), let part = try? ContentFile.decoder().decode(ContentFile.Part.self, from: data) else { fail("cannot read \(file.path)") }
        vocabulary += part.vocabulary
    }
    let generated = MeaningQuestionGenerator.generate(from: vocabulary, source: ContentFile.Source(origin: .curated, name: "HanguStep question generator", license: package.source.license))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let output = root.appendingPathComponent("questions/generated-meaning.json")
    do {
        try encoder.encode(ContentFile.Part(questions: generated)).write(to: output)
        print("wrote \(generated.count) questions to \(output.path)")
        let result = try BundledContent.load(directory: root)
        try BundledContent.writeSummary(result.info, directory: root)
        print("wrote \(BundledContent.summaryFile)")
        summarise(result)
    } catch {
        fail("FAIL \(error)")
    }
default:
    fail("unknown command \(command)")
}
