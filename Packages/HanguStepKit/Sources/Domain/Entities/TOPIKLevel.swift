import Foundation

public enum TOPIKExam: String, Sendable, Codable, CaseIterable {
    case topikI
    case topikII
}

/// TOPIK proficiency level 1 to 6. Levels 1 and 2 belong to TOPIK I; 3 to 6 to TOPIK II.
public enum TOPIKLevel: Int, Sendable, Codable, CaseIterable, Comparable {
    case level1 = 1
    case level2 = 2
    case level3 = 3
    case level4 = 4
    case level5 = 5
    case level6 = 6

    public var exam: TOPIKExam { rawValue <= 2 ? .topikI : .topikII }

    public static func < (lhs: TOPIKLevel, rhs: TOPIKLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
