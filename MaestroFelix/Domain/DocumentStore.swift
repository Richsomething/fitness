import Foundation

/// Small documents kept by key: the profile, the log, the schedule and the rest. Each is one value
/// that is read and written whole.
@MainActor
protocol DocumentStore {
    func load<T: Decodable>(_ type: T.Type, key: String) throws -> T?
    func save<T: Encodable>(_ value: T, key: String) throws
    func remove(key: String) throws
    /// Everything, for "delete all data".
    func removeAll() throws
}

enum StoreKey {
    static let draft = "draft"
    static let profile = "profile"
    static let workoutLogs = "workoutLogs"
    static let schedule = "schedule"
    static let weights = "weights"
    static let coach = "coach"
    static let reminders = "reminders"
    static let achievements = "achievements"
    static let activeSession = "activeSession"
}

/// The person's data as one portable file. Nothing in it leaves the device unless they send it.
struct ExportBundle: Codable {
    var format = "maestro-felix-export"
    var version = 1
    var exportedAt: Date
    var profile: LocalProfile?
    var workouts: [WorkoutLog]
    var weights: [WeightEntry]
    var schedule: ScheduleState
    var achievements: AchievementsState
    var coach: CoachState
    var reminders: ReminderSettings
    var adaptiveTraining: AdaptiveTrainingState? = nil

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
