import CoreData

@objc(CDStudySession)
final class CDStudySession: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var mode: String
    @NSManaged var startedAt: Date?
    @NSManaged var endedAt: Date?
    @NSManaged var questionIDs: String
    @NSManaged var currentIndex: Int16
    @NSManaged var deviceName: String
    @NSManaged var modifiedAt: Date?
}

@objc(CDAttempt)
final class CDAttempt: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var sessionID: String
    @NSManaged var questionID: String
    @NSManaged var selectedOptionID: String
    @NSManaged var isCorrect: Bool
    @NSManaged var answeredAt: Date?
    @NSManaged var responseTime: Double
    @NSManaged var targetKind: String
    @NSManaged var targetID: String
}

@objc(CDBookmark)
final class CDBookmark: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var targetKind: String
    @NSManaged var targetID: String
    @NSManaged var createdAt: Date?
    @NSManaged var modifiedAt: Date?
}

@objc(CDReviewSchedule)
final class CDReviewSchedule: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var targetKind: String
    @NSManaged var targetID: String
    @NSManaged var easeFactor: Double
    @NSManaged var intervalDays: Int32
    @NSManaged var repetitions: Int32
    @NSManaged var nextReviewDate: Date?
    @NSManaged var lastReviewedAt: Date?
    @NSManaged var modifiedAt: Date?
}

@objc(CDLearnerNote)
final class CDLearnerNote: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var targetKind: String
    @NSManaged var targetID: String
    @NSManaged var text: String
    @NSManaged var modifiedAt: Date?
}

@objc(CDLearnerSettings)
final class CDLearnerSettings: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var glossLanguage: String
    @NSManaged var dailyGoal: Int32
    @NSManaged var reviewLimit: Int32
    @NSManaged var pronunciationEnabled: Bool
    @NSManaged var modifiedAt: Date?
}
