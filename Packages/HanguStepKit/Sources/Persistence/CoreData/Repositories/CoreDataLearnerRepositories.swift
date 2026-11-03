import CoreData
import Domain
import Foundation

public struct CoreDataAttemptRepository: AttemptRepository {
    private let context: NSManagedObjectContext

    public init(controller: PersistenceController) {
        context = controller.newBackgroundContext()
    }

    public func record(_ attempt: Attempt) async throws {
        let target = attempt.target
        try await context.perform {
            let duplicate = NSFetchRequest<CDAttempt>(entityName: "CDAttempt")
            duplicate.predicate = NSPredicate(format: "sessionID == %@ AND questionID == %@", attempt.sessionID.rawValue, attempt.questionID.rawValue)
            if try context.count(for: duplicate) > 0 {
                throw DomainError.duplicateSubmission(questionID: attempt.questionID)
            }
            let row = CDAttempt(context: context)
            row.id = attempt.id.rawValue
            row.sessionID = attempt.sessionID.rawValue
            row.questionID = attempt.questionID.rawValue
            row.selectedOptionID = attempt.selectedOptionID.rawValue
            row.isCorrect = attempt.isCorrect
            row.answeredAt = attempt.answeredAt
            row.responseTime = attempt.responseTime
            row.targetKind = target?.kind ?? ""
            row.targetID = target?.contentID ?? ""
            try context.save()
        }
    }

    public func attempts(inSession sessionID: StudySessionID) async throws -> [Attempt] {
        try await fetch(field: "sessionID", value: sessionID.rawValue)
    }

    public func attempts(forQuestion questionID: QuestionID) async throws -> [Attempt] {
        try await fetch(field: "questionID", value: questionID.rawValue)
    }

    public func allAttempts() async throws -> [Attempt] {
        try await context.perform {
            let request = NSFetchRequest<CDAttempt>(entityName: "CDAttempt")
            request.sortDescriptors = [NSSortDescriptor(key: "answeredAt", ascending: true)]
            return try context.fetch(request).map(Self.map)
        }
    }

    public func summary() async throws -> AttemptSummary {
        try await context.perform {
            let all = NSFetchRequest<CDAttempt>(entityName: "CDAttempt")
            let correct = NSFetchRequest<CDAttempt>(entityName: "CDAttempt")
            correct.predicate = NSPredicate(format: "isCorrect == YES")
            return AttemptSummary(total: try context.count(for: all), correct: try context.count(for: correct))
        }
    }

    /// Predicates are built inside `perform` because `NSPredicate` is not Sendable.
    private func fetch(field: String, value: String) async throws -> [Attempt] {
        try await context.perform {
            let request = NSFetchRequest<CDAttempt>(entityName: "CDAttempt")
            request.predicate = NSPredicate(format: "%K == %@", field, value)
            request.sortDescriptors = [NSSortDescriptor(key: "answeredAt", ascending: true)]
            return try context.fetch(request).map(Self.map)
        }
    }

    static func map(_ row: CDAttempt) -> Attempt {
        Attempt(
            id: AttemptID(row.id),
            sessionID: StudySessionID(row.sessionID),
            questionID: QuestionID(row.questionID),
            selectedOptionID: OptionID(row.selectedOptionID),
            isCorrect: row.isCorrect,
            answeredAt: row.answeredAt ?? .distantPast,
            responseTime: row.responseTime,
            target: LearningTarget(kind: row.targetKind, contentID: row.targetID)
        )
    }
}

public struct CoreDataBookmarkRepository: BookmarkRepository {
    private let context: NSManagedObjectContext

    public init(controller: PersistenceController) {
        context = controller.newBackgroundContext()
    }

    public func add(_ bookmark: Bookmark) async throws {
        try await context.perform {
            if try Self.row(for: bookmark.target, in: context) != nil { return }
            let row = CDBookmark(context: context)
            row.id = bookmark.id.rawValue
            row.targetKind = bookmark.target.kind
            row.targetID = bookmark.target.contentID
            row.createdAt = bookmark.createdAt
            row.modifiedAt = bookmark.createdAt
            try context.save()
        }
    }

    public func remove(target: LearningTarget) async throws {
        try await context.perform {
            let request = NSFetchRequest<CDBookmark>(entityName: "CDBookmark")
            request.predicate = Self.targetPredicate(target)
            for row in try context.fetch(request) { context.delete(row) }
            try context.save()
        }
    }

    public func contains(target: LearningTarget) async throws -> Bool {
        try await context.perform { try Self.row(for: target, in: context) != nil }
    }

    public func all() async throws -> [Bookmark] {
        try await context.perform {
            let request = NSFetchRequest<CDBookmark>(entityName: "CDBookmark")
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            return try context.fetch(request).compactMap { row in
                guard let target = LearningTarget(kind: row.targetKind, contentID: row.targetID) else { return nil }
                return Bookmark(id: BookmarkID(row.id), target: target, createdAt: row.createdAt ?? .distantPast)
            }
        }
    }

    static func targetPredicate(_ target: LearningTarget) -> NSPredicate {
        NSPredicate(format: "targetKind == %@ AND targetID == %@", target.kind, target.contentID)
    }

    static func row(for target: LearningTarget, in context: NSManagedObjectContext) throws -> CDBookmark? {
        let request = NSFetchRequest<CDBookmark>(entityName: "CDBookmark")
        request.predicate = targetPredicate(target)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

public struct CoreDataReviewScheduleRepository: ReviewScheduleRepository {
    private let context: NSManagedObjectContext

    public init(controller: PersistenceController) {
        context = controller.newBackgroundContext()
    }

    public func schedule(for target: LearningTarget) async throws -> ReviewSchedule? {
        try await context.perform {
            try Self.row(for: target, in: context).flatMap(Self.map)
        }
    }

    public func upsert(_ schedule: ReviewSchedule) async throws {
        try await context.perform {
            let row = try Self.row(for: schedule.target, in: context) ?? {
                let new = CDReviewSchedule(context: context)
                new.id = schedule.id.rawValue
                new.targetKind = schedule.target.kind
                new.targetID = schedule.target.contentID
                return new
            }()
            row.easeFactor = schedule.easeFactor
            row.intervalDays = Int32(schedule.intervalDays)
            row.repetitions = Int32(schedule.repetitions)
            row.nextReviewDate = schedule.nextReviewDate
            row.lastReviewedAt = schedule.lastReviewedAt
            row.modifiedAt = Date()
            try context.save()
        }
    }

    public func due(onOrBefore date: Date, limit: Int) async throws -> [ReviewSchedule] {
        try await context.perform {
            let request = NSFetchRequest<CDReviewSchedule>(entityName: "CDReviewSchedule")
            request.predicate = NSPredicate(format: "nextReviewDate <= %@", date as NSDate)
            request.sortDescriptors = [NSSortDescriptor(key: "nextReviewDate", ascending: true)]
            request.fetchLimit = limit
            return try context.fetch(request).compactMap(Self.map)
        }
    }

    static func row(for target: LearningTarget, in context: NSManagedObjectContext) throws -> CDReviewSchedule? {
        let request = NSFetchRequest<CDReviewSchedule>(entityName: "CDReviewSchedule")
        request.predicate = NSPredicate(format: "targetKind == %@ AND targetID == %@", target.kind, target.contentID)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    static func map(_ row: CDReviewSchedule) -> ReviewSchedule? {
        guard let target = LearningTarget(kind: row.targetKind, contentID: row.targetID) else { return nil }
        return ReviewSchedule(
            id: ReviewScheduleID(row.id),
            target: target,
            easeFactor: row.easeFactor,
            intervalDays: Int(row.intervalDays),
            repetitions: Int(row.repetitions),
            nextReviewDate: row.nextReviewDate ?? .distantPast,
            lastReviewedAt: row.lastReviewedAt
        )
    }
}

public struct CoreDataStudySessionRepository: StudySessionRepository {
    private let context: NSManagedObjectContext

    public init(controller: PersistenceController) {
        context = controller.newBackgroundContext()
    }

    public func save(_ session: StudySession) async throws {
        try await context.perform {
            let row = try Self.row(id: session.id.rawValue, in: context) ?? {
                let new = CDStudySession(context: context)
                new.id = session.id.rawValue
                return new
            }()
            row.mode = session.mode.rawValue
            row.startedAt = session.startedAt
            row.endedAt = session.endedAt
            row.questionIDs = CoreDataSupport.encodeIDs(session.questionIDs.map(\.rawValue))
            row.currentIndex = Int16(session.currentIndex)
            row.deviceName = session.deviceName
            row.modifiedAt = Date()
            try context.save()
        }
    }

    public func session(id: StudySessionID) async throws -> StudySession? {
        try await context.perform { try Self.row(id: id.rawValue, in: context).map(Self.map) }
    }

    public func unfinishedSession() async throws -> StudySession? {
        try await context.perform {
            let request = NSFetchRequest<CDStudySession>(entityName: "CDStudySession")
            request.predicate = NSPredicate(format: "endedAt == nil")
            request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
            request.fetchLimit = 1
            return try context.fetch(request).first.map(Self.map)
        }
    }

    public func sessions(limit: Int) async throws -> [StudySession] {
        try await context.perform {
            let request = NSFetchRequest<CDStudySession>(entityName: "CDStudySession")
            request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
            request.fetchLimit = limit
            return try context.fetch(request).map(Self.map)
        }
    }

    static func row(id: String, in context: NSManagedObjectContext) throws -> CDStudySession? {
        let request = NSFetchRequest<CDStudySession>(entityName: "CDStudySession")
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    static func map(_ row: CDStudySession) -> StudySession {
        StudySession(
            id: StudySessionID(row.id),
            mode: StudyMode(rawValue: row.mode) ?? .quiz,
            startedAt: row.startedAt ?? .distantPast,
            endedAt: row.endedAt,
            questionIDs: CoreDataSupport.decodeIDs(row.questionIDs).map { QuestionID($0) },
            currentIndex: Int(row.currentIndex),
            deviceName: row.deviceName
        )
    }
}

public struct CoreDataLearnerNoteRepository: LearnerNoteRepository {
    private let context: NSManagedObjectContext

    public init(controller: PersistenceController) {
        context = controller.newBackgroundContext()
    }

    public func note(for target: LearningTarget) async throws -> LearnerNote? {
        try await context.perform {
            guard let row = try Self.row(for: target, in: context) else { return nil }
            return LearnerNote(id: LearnerNoteID(row.id), target: target, text: row.text, modifiedAt: row.modifiedAt ?? .distantPast)
        }
    }

    public func upsert(_ note: LearnerNote) async throws {
        let trimmed = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return try await remove(target: note.target) }
        try await context.perform {
            let row = try Self.row(for: note.target, in: context) ?? {
                let new = CDLearnerNote(context: context)
                new.id = note.id.rawValue
                new.targetKind = note.target.kind
                new.targetID = note.target.contentID
                return new
            }()
            row.text = trimmed
            row.modifiedAt = note.modifiedAt
            try context.save()
        }
    }

    public func remove(target: LearningTarget) async throws {
        try await context.perform {
            let request = NSFetchRequest<CDLearnerNote>(entityName: "CDLearnerNote")
            request.predicate = NSPredicate(format: "targetKind == %@ AND targetID == %@", target.kind, target.contentID)
            for row in try context.fetch(request) { context.delete(row) }
            try context.save()
        }
    }

    static func row(for target: LearningTarget, in context: NSManagedObjectContext) throws -> CDLearnerNote? {
        let request = NSFetchRequest<CDLearnerNote>(entityName: "CDLearnerNote")
        request.predicate = NSPredicate(format: "targetKind == %@ AND targetID == %@", target.kind, target.contentID)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

public struct CoreDataLearnerSettingsRepository: LearnerSettingsRepository {
    private let context: NSManagedObjectContext

    public init(controller: PersistenceController) {
        context = controller.newBackgroundContext()
    }

    public func load() async throws -> LearnerSettings {
        try await context.perform {
            guard let row = try Self.row(in: context) else { return .default }
            return LearnerSettings(
                glossLanguage: GlossLanguage(rawValue: row.glossLanguage) ?? .english,
                dailyGoal: Int(row.dailyGoal),
                reviewLimit: Int(row.reviewLimit),
                pronunciationEnabled: row.pronunciationEnabled,
                modifiedAt: row.modifiedAt ?? .distantPast
            )
        }
    }

    public func save(_ settings: LearnerSettings) async throws {
        try await context.perform {
            let row = try Self.row(in: context) ?? {
                let new = CDLearnerSettings(context: context)
                new.id = "settings"
                return new
            }()
            row.glossLanguage = settings.glossLanguage.rawValue
            row.dailyGoal = Int32(settings.dailyGoal)
            row.reviewLimit = Int32(settings.reviewLimit)
            row.pronunciationEnabled = settings.pronunciationEnabled
            row.modifiedAt = settings.modifiedAt
            try context.save()
        }
    }

    static func row(in context: NSManagedObjectContext) throws -> CDLearnerSettings? {
        let request = NSFetchRequest<CDLearnerSettings>(entityName: "CDLearnerSettings")
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
