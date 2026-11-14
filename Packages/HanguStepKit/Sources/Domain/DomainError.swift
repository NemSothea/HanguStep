import Foundation

/// Errors that cross the domain boundary. Repositories map their framework
/// errors (Core Data, CloudKit) into `.storage`; views never see raw framework errors.
public enum DomainError: Error, Sendable, Equatable {
    case notFound(entity: String, id: String)
    case invalidContent(issues: [ContentValidationIssue])
    case invalidPackage(issues: [String])
    case duplicateSubmission(questionID: QuestionID)
    case emptyPool
    case storage(description: String)
}

extension DomainError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .notFound(entity, id):
            return "\(entity) \(id) was not found."
        case let .invalidContent(issues):
            return "Content is invalid: \(issues.map(\.description).joined(separator: ", "))"
        case let .duplicateSubmission(questionID):
            return "Question \(questionID) was already answered in this session."
        case let .invalidPackage(issues):
            return "Content package is invalid: \(issues.joined(separator: "; "))"
        case .emptyPool:
            return "No questions match the selected filters."
        case let .storage(description):
            return "Storage error: \(description)"
        }
    }
}
