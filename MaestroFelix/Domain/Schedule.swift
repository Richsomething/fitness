import Foundation

/// The training days in force from a day on. The schedule is kept as a history, so changing the days
/// never rewrites the past: a day is judged by the revision that was in force on it.
struct ScheduleRevision: Codable, Equatable {
    var from: DayKey
    var weekdays: Set<Int>
}

/// Days the person put on hold. Sessions on them are neither due nor missed, and the streak waits.
struct SchedulePause: Codable, Equatable {
    var from: DayKey
    var until: DayKey

    func covers(_ day: DayKey) -> Bool { day >= from && day <= until }
}

/// Everything about the schedule that does not follow from the profile: its history and the person's
/// one-off changes, each keyed by the slot (the day a session was planned for) it belongs to.
struct ScheduleState: Codable, Equatable {
    var revisions: [ScheduleRevision] = []
    /// Slot → the day the session was moved to.
    var moves: [String: DayKey] = [:]
    var skipped: Set<String> = []
    var pauses: [SchedulePause] = []
    /// Slot → exercise the planner chose → the exercise the person put in its place.
    var swaps: [String: [String: String]] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        revisions = try container.decodeIfPresent([ScheduleRevision].self, forKey: .revisions) ?? []
        moves = try container.decodeIfPresent([String: DayKey].self, forKey: .moves) ?? [:]
        skipped = try container.decodeIfPresent(Set<String>.self, forKey: .skipped) ?? []
        pauses = try container.decodeIfPresent([SchedulePause].self, forKey: .pauses) ?? []
        swaps = try container.decodeIfPresent([String: [String: String]].self, forKey: .swaps) ?? [:]
    }

    func revision(for day: DayKey) -> ScheduleRevision? { revisions.last { $0.from <= day } }

    func pause(covering day: DayKey) -> SchedulePause? { pauses.first { $0.covers(day) } }

    /// The day a slot's session falls on now.
    func day(of slot: DayKey) -> DayKey { moves[slot.rawValue] ?? slot }

    /// Notes the training days from `day` on. Days already lived stay as they were; a change that
    /// has not started yet is replaced; writing the days already in force adds nothing.
    mutating func record(weekdays: Set<Int>, from day: DayKey) {
        guard !weekdays.isEmpty else { return }
        revisions.removeAll { $0.from >= day }
        guard revisions.last?.weekdays != weekdays else { return }
        revisions.append(ScheduleRevision(from: day, weekdays: weekdays))
    }

    mutating func move(_ slot: DayKey, to day: DayKey) {
        if day == slot { moves[slot.rawValue] = nil } else { moves[slot.rawValue] = day }
    }

    mutating func skip(_ slot: DayKey) { skipped.insert(slot.rawValue) }

    mutating func unskip(_ slot: DayKey) { skipped.remove(slot.rawValue) }

    /// Puts `from`…`until` on hold, replacing any hold that reaches into that range.
    mutating func pause(from: DayKey, until: DayKey) {
        guard from <= until else { return }
        pauses.removeAll { $0.until >= from }
        pauses.append(SchedulePause(from: from, until: until))
    }

    /// Ends the hold that covers `day`, from that day on.
    mutating func resume(on day: DayKey, calendar: Calendar = .current) {
        pauses = pauses.compactMap { pause in
            guard pause.covers(day) else { return pause }
            let last = day.adding(days: -1, calendar: calendar)
            return last >= pause.from ? SchedulePause(from: pause.from, until: last) : nil
        }
    }

    /// Puts `replacement` in the place of `exerciseID` in the session of `slot`.
    mutating func swap(_ exerciseID: String, to replacement: String, in slot: DayKey) {
        swaps[slot.rawValue, default: [:]][exerciseID] = replacement
    }

    /// Brings the planner's own exercise back.
    mutating func restore(_ exerciseID: String, in slot: DayKey) {
        swaps[slot.rawValue]?[exerciseID] = nil
        if swaps[slot.rawValue]?.isEmpty == true { swaps[slot.rawValue] = nil }
    }

    private enum CodingKeys: String, CodingKey { case revisions, moves, skipped, pauses, swaps }
}

// MARK: - Planned sessions

enum SessionStatus: Equatable {
    case planned
    case done(UUID)
    case skipped
    /// Its day is over and nothing was done.
    case missed
    case paused

    var isDone: Bool {
        if case .done = self { return true }
        return false
    }
}

/// One planned session without its exercises: which slot it belongs to, where it stands now, and how
/// it fared. Streaks, weeks and reminders need no more than this.
struct PlannedSlot: Equatable, Identifiable {
    let slot: DayKey
    let day: DayKey
    let status: SessionStatus

    var id: String { slot.rawValue }
    var isMoved: Bool { slot != day }
}

struct PlannedSession: Equatable, Identifiable {
    let slot: PlannedSlot
    let plan: WorkoutPlan

    var id: String { slot.id }
    var day: DayKey { slot.day }
    var key: DayKey { slot.slot }
    var status: SessionStatus { slot.status }
    var isMoved: Bool { slot.isMoved }
}

enum SchedulePlanner {
    /// How far a session may be moved from its slot, and so how far outside a range its slots can lie.
    static let moveHorizonDays = 14

    /// The slots whose sessions fall on `from`…`through`, in day order, with their standing on `today`.
    static func slots(state: ScheduleState, logs: [WorkoutLog], from: DayKey, through: DayKey, today: DayKey,
                      calendar: Calendar = .current) -> [PlannedSlot] {
        guard from <= through else { return [] }
        let completions = Completions(logs, calendar: calendar)
        var found: [PlannedSlot] = []
        var slot = from.adding(days: -moveHorizonDays, calendar: calendar)
        let last = through.adding(days: moveHorizonDays, calendar: calendar)
        while slot <= last {
            defer { slot = slot.adding(days: 1, calendar: calendar) }
            guard let revision = state.revision(for: slot), revision.weekdays.contains(slot.isoWeekday(calendar: calendar)) else { continue }
            let day = state.day(of: slot)
            guard day >= from, day <= through else { continue }
            found.append(PlannedSlot(slot: slot, day: day, status: status(of: slot, on: day, state: state, completions: completions, today: today)))
        }
        return found.sorted { ($0.day, $0.slot) < ($1.day, $1.slot) }
    }

    /// The same slots with their exercises.
    static func sessions(profile: OnboardingDraft, state: ScheduleState, logs: [WorkoutLog], from: DayKey, through: DayKey,
                         today: DayKey, calendar: Calendar = .current) -> [PlannedSession] {
        slots(state: state, logs: logs, from: from, through: through, today: today, calendar: calendar).compactMap { slot in
            guard let revision = state.revision(for: slot.slot),
                  let plan = WorkoutPlanner.plan(for: profile, weekdays: revision.weekdays, on: slot.slot.date(calendar: calendar),
                                                 logs: logs, calendar: calendar) else { return nil }
            return PlannedSession(slot: slot, plan: ExerciseSwaps.apply(state.swaps[slot.slot.rawValue] ?? [:], to: plan))
        }
    }

    /// The days a session may be moved to: from today, up to the horizon, without the day it is on now
    /// and without days that already hold another session. Only an open session can move, and never
    /// from a closed day.
    static func movableDays(for session: PlannedSlot, among slots: [PlannedSlot], today: DayKey,
                            calendar: Calendar = .current) -> [DayKey] {
        guard session.status == .planned, session.day >= today else { return [] }
        let taken = Set(slots.filter { $0.slot != session.slot }.map(\.day))
        return (0...moveHorizonDays)
            .map { today.adding(days: $0, calendar: calendar) }
            .filter { $0 != session.day && !taken.contains($0) }
    }

    private static func status(of slot: DayKey, on day: DayKey, state: ScheduleState, completions: Completions,
                               today: DayKey) -> SessionStatus {
        if let id = completions.log(for: slot, on: day) { return .done(id) }
        if state.skipped.contains(slot.rawValue) { return .skipped }
        if state.pause(covering: day) != nil { return .paused }
        return day < today ? .missed : .planned
    }

    /// Which finished strength workouts completed which slots. A workout made before slots existed
    /// counts for the session on the day it was finished.
    private struct Completions {
        private var byKey: [String: UUID] = [:]
        private var byFinishDay: [String: UUID] = [:]

        init(_ logs: [WorkoutLog], calendar: Calendar) {
            for log in logs where log.kind == .strength {
                if let key = log.sessionKey {
                    byKey[key.rawValue] = byKey[key.rawValue] ?? log.id
                } else {
                    let day = log.day(calendar: calendar).rawValue
                    byFinishDay[day] = byFinishDay[day] ?? log.id
                }
            }
        }

        func log(for slot: DayKey, on day: DayKey) -> UUID? {
            byKey[slot.rawValue] ?? byFinishDay[day.rawValue]
        }
    }
}

// MARK: - Today

/// What the first tab shows for today, decided from the plan and what was done.
enum TodayState: Equatable {
    case training(PlannedSession)
    case trainingDone(PlannedSession, WorkoutLog)
    case skipped(PlannedSession)
    case paused(until: DayKey, next: PlannedSession?)
    /// `movedTo` is set when today's session was moved to another day.
    case rest(next: PlannedSession?, movedTo: DayKey?, activity: [WorkoutLog])
}

enum TodayResolver {
    /// `sessions` must cover today and the days after it.
    static func resolve(sessions: [PlannedSession], state: ScheduleState, logs: [WorkoutLog], today: DayKey,
                        calendar: Calendar = .current) -> TodayState {
        let next = sessions.first { $0.day > today && $0.status == .planned }
        if let session = sessions.first(where: { $0.day == today }) {
            switch session.status {
            case let .done(id):
                if let log = logs.first(where: { $0.id == id }) { return .trainingDone(session, log) }
                return .training(session)
            case .skipped: return .skipped(session)
            case .paused: return .paused(until: state.pause(covering: today)?.until ?? today, next: next)
            case .planned, .missed: return .training(session)
            }
        }
        if let pause = state.pause(covering: today) { return .paused(until: pause.until, next: next) }
        let movedTo = state.moves[today.rawValue].flatMap { $0 != today ? $0 : nil }
        let activity = logs.filter { $0.kind != .strength && $0.day(calendar: calendar) == today }
        return .rest(next: next, movedTo: movedTo, activity: activity)
    }
}
