import Foundation

/// A listening question's script, split into spoken lines (TOPIK II 듣기 style).
///
/// Lines starting with `남자:` or `여자:` belong to that speaker; any other
/// non-empty line is narration. The pronouncer gives each speaker a voice.
public struct ListeningScript: Hashable, Sendable {
    public enum Speaker: String, Hashable, Sendable {
        case man = "남자"
        case woman = "여자"
        case narrator
    }

    public struct Line: Hashable, Sendable {
        public let speaker: Speaker
        public let text: String

        public init(speaker: Speaker, text: String) {
            self.speaker = speaker
            self.text = text
        }
    }

    public let lines: [Line]

    public init(lines: [Line]) {
        self.lines = lines
    }

    public init(_ text: String) {
        lines = text.split(whereSeparator: \.isNewline).compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { return nil }
            for speaker in [Speaker.man, .woman] {
                for separator in [":", "："] where line.hasPrefix(speaker.rawValue + separator) {
                    let spoken = line.dropFirst(speaker.rawValue.count + 1).trimmingCharacters(in: .whitespaces)
                    return spoken.isEmpty ? nil : Line(speaker: speaker, text: spoken)
                }
            }
            return Line(speaker: .narrator, text: line)
        }
    }
}
