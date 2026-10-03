//
//  AppState.swift
//  Home Workout
//
//  The single source of truth for the user's profile, plan, library and
//  history. Every change is persisted to disk (see Persistence.swift).
//

import SwiftUI
import Observation

enum Goal: String, CaseIterable, Identifiable, Codable {
    case loseWeight, getStronger, moveDaily, feelFlexible
    var id: String { rawValue }
    var title: String {
        switch self {
        case .loseWeight: "Burn & slim down"
        case .getStronger: "Get stronger"
        case .moveDaily: "Build a daily habit"
        case .feelFlexible: "Loosen up & de-stress"
        }
    }
    var detail: String {
        switch self {
        case .loseWeight: "Cardio-forward sessions that keep you moving"
        case .getStronger: "Progressive bodyweight strength"
        case .moveDaily: "Short, doable sessions every day"
        case .feelFlexible: "Mobility, stretching and calm"
        }
    }
    var symbol: String {
        switch self {
        case .loseWeight: "flame.fill"
        case .getStronger: "bolt.fill"
        case .moveDaily: "sun.max.fill"
        case .feelFlexible: "leaf.fill"
        }
    }
    var tint: Color {
        switch self {
        case .loseWeight: Palette.sun
        case .getStronger: Palette.persimmon
        case .moveDaily: Palette.sky
        case .feelFlexible: Palette.lilac
        }
    }
}

struct Weekday: Identifiable, Hashable {
    let index: Int          // 0 = Monday
    var id: Int { index }
    var short: String { ["M", "T", "W", "T", "F", "S", "S"][index] }
    var name: String { ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][index] }
    var calendarWeekday: Int { index == 6 ? 1 : index + 2 }   // Calendar: 1 = Sunday
    static let all = (0..<7).map(Weekday.init)
}

/// A finished (or partly finished) session in the log.
struct CompletedSession: Identifiable, Hashable, Codable {
    var id = UUID()
    let workoutID: String
    let title: String
    let coverID: String
    let date: Date
    let minutes: Int
    let calories: Int
    let moves: Int
    let feeling: Int   // 0 easy … 2 tough

    var cover: Exercise? { Catalog.exercise(id: coverID) }
}

struct WeightEntry: Identifiable, Hashable, Codable {
    var id = UUID()
    let date: Date
    let kg: Double
}

@Observable
final class AppState {

    // MARK: Profile (onboarding answers)
    var hasOnboarded = false { didSet { persist(); reschedule() } }
    var name = "" { didSet { persist() } }
    var goal: Goal = .moveDaily { didSet { persist() } }
    var focus: Set<BodyRegion> = [.full, .core] { didSet { persist() } }
    var level: Level = .beginner { didSet { persist() } }
    var trainingDays: Set<Int> = [0, 2, 4] { didSet { persist(); reschedule() } }
    var sessionMinutes = 15 { didSet { persist() } }
    var quietMode = false { didSet { persist() } }

    // MARK: Preferences
    var remindersOn = true { didSet { persist(); reschedule() } }
    var reminder = Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: .now) ?? .now {
        didSet { persist(); reschedule() }
    }
    var voiceOn = true { didSet { persist() } }
    var soundsOn = true { didSet { persist() } }
    var healthOn = false { didSet { persist() } }
    /// Adaptive difficulty from post-workout feedback: -2 (lighter) … +2 (harder).
    var intensity = 0 { didSet { persist() } }

    // MARK: Subscription (owned by Store, cached here for instant UI)
    var isPro = false { didSet { persist() } }

    // MARK: Plan
    var activeProgramID: String? { didSet { persist() } }
    /// 1-based index of the next program session.
    var programDay = 1 { didSet { persist() } }
    /// Workout scheduled for each weekday index (0 = Monday).
    var week: [Int: Workout] = [:] { didSet { persist(); reschedule() } }

    // MARK: Library
    var favorites: Set<String> = [] { didSet { persist() } }
    var customWorkouts: [Workout] = [] { didSet { persist() } }

    // MARK: History
    var history: [CompletedSession] = [] { didSet { persist() } }
    var weights: [WeightEntry] = [] { didSet { persist() } }

    /// Suppresses saving while loading from disk.
    @ObservationIgnored private var isRestoring = false
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private let persistence: Persistence?

    init(persistence: Persistence? = Persistence()) {
        self.persistence = persistence
        if let snapshot = persistence?.load() { restore(from: snapshot) }
    }

    // MARK: Derived

    var displayName: String { name.trimmingCharacters(in: .whitespaces).isEmpty ? "friend" : name }
    var activeProgram: Program? { Catalog.programs.first { $0.id == activeProgramID } }
    var todayIndex: Int { (Calendar.current.component(.weekday, from: .now) + 5) % 7 }
    var todaysWorkout: Workout? { week[todayIndex] }
    var latestWeight: Double? { weights.last?.kg }
    /// Body weight used for calorie estimates.
    var bodyWeightKg: Double { latestWeight ?? 70 }

    var allWorkouts: [Workout] { customWorkouts + Catalog.workouts }
    func workout(id: String) -> Workout? { allWorkouts.first { $0.id == id } }

    private var workoutDays: Set<Date> { Set(history.map { Calendar.current.startOfDay(for: $0.date) }) }

    var streak: Int {
        let cal = Calendar.current
        let days = workoutDays
        var day = cal.startOfDay(for: .now)
        if !days.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var count = 0
        while days.contains(day) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    var bestStreak: Int {
        let cal = Calendar.current
        let days = workoutDays.sorted()
        var best = 0, run = 0
        var previous: Date?
        for d in days {
            if let p = previous, cal.dateComponents([.day], from: p, to: d).day == 1 { run += 1 } else { run = 1 }
            best = max(best, run)
            previous = d
        }
        return best
    }

    var totalMinutes: Int { history.reduce(0) { $0 + $1.minutes } }
    var totalCalories: Int { history.reduce(0) { $0 + $1.calories } }
    var thisWeekCount: Int {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return history.filter { $0.date >= start }.count
    }

    func didWorkout(on date: Date) -> Bool {
        history.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: Actions

    func log(_ session: CompletedSession, programDayCompleted: Bool) {
        history.insert(session, at: 0)
        if programDayCompleted, let program = activeProgram {
            programDay = min(programDay + 1, program.totalDays + 1)
        }
    }

    /// Post-workout feedback nudges future sessions easier or harder.
    func applyFeedback(_ feeling: Int) {
        switch feeling {
        case 0: intensity = min(2, intensity + 1)
        case 2: intensity = max(-2, intensity - 1)
        default: break
        }
    }

    func toggleFavorite(_ w: Workout) {
        if favorites.contains(w.id) { favorites.remove(w.id) } else { favorites.insert(w.id) }
    }

    func startProgram(_ program: Program) {
        activeProgramID = program.id
        programDay = 1
    }

    func leaveProgram() {
        activeProgramID = nil
        programDay = 1
    }

    func deleteCustom(_ w: Workout) {
        customWorkouts.removeAll { $0.id == w.id }
        for (day, scheduled) in week where scheduled.id == w.id { week[day] = nil }
        favorites.remove(w.id)
    }

    func logWeight(_ kg: Double) {
        weights.append(WeightEntry(date: .now, kg: (kg * 10).rounded() / 10))
        if healthOn { Task { await HealthService.shared.saveWeight(kg) } }
    }

    // MARK: Plan generation

    /// Workouts that suit the user's answers, best first.
    func recommendedWorkouts() -> [Workout] {
        let ceiling = max(level, .intermediate)
        let pool = Catalog.workouts.filter { (!$0.isPro || isPro) && $0.level <= ceiling }
        var ranked: [Workout] = []
        let target = sessionMinutes
        /// Adds new workouts, closest to the preferred session length first.
        func add(_ list: [Workout]) {
            for w in list.sorted(by: { abs($0.minutes - target) < abs($1.minutes - target) }) where !ranked.contains(w) {
                ranked.append(w)
            }
        }
        switch goal {
        case .feelFlexible: add(pool.filter { $0.style == .flow })
        case .loseWeight: add(pool.filter { $0.style == .sweat || $0.style == .quick })
        case .getStronger: add(pool.filter { $0.style == .sculpt || $0.style == .core })
        case .moveDaily: add(pool.filter { $0.minutes <= max(sessionMinutes, 8) })
        }
        add(pool.filter { focus.contains($0.region) })
        add(pool)
        return ranked
    }

    /// Fills training days with recommended workouts and clears the rest.
    func generateWeek() {
        let picks = recommendedWorkouts()
        guard !picks.isEmpty else { return }
        var plan: [Int: Workout] = [:]
        for (i, day) in trainingDays.sorted().enumerated() { plan[day] = picks[i % min(picks.count, 5)] }
        week = plan
    }

    /// Adds workouts for newly picked days and drops deselected ones, keeping manual choices.
    func syncWeekToTrainingDays() {
        var plan = week
        for day in plan.keys where !trainingDays.contains(day) { plan[day] = nil }
        let picks = recommendedWorkouts().filter { w in !plan.values.contains(w) }
        var i = 0
        for day in trainingDays.sorted() where plan[day] == nil && !picks.isEmpty {
            plan[day] = picks[i % picks.count]
            i += 1
        }
        week = plan
    }

    // MARK: Reset & demo

    func resetEverything() {
        let fresh = AppState(persistence: nil)
        isRestoring = true
        restore(from: fresh.snapshot())
        isRestoring = false
        persist()
        reschedule()
    }

    /// Fills a few weeks of history so stats screens can be reviewed.
    func loadDemoHistory() {
        let cal = Calendar.current
        let picks = Catalog.workouts.filter { !$0.isPro }
        let offsets = [1, 2, 3, 5, 6, 8, 9, 10, 12, 15, 16, 19, 22, 23, 26]
        let sessions: [CompletedSession] = offsets.enumerated().map { i, off in
            let w = picks[i % picks.count]
            return CompletedSession(workoutID: w.id, title: w.title, coverID: w.cover.id,
                                    date: cal.date(byAdding: .day, value: -off, to: .now)!,
                                    minutes: w.minutes, calories: w.minutes * 7, moves: w.exerciseCount, feeling: i % 3)
        }
        history = (history + sessions).sorted { $0.date > $1.date }
        if weights.isEmpty {
            weights = [72.4, 72.1, 71.9, 71.6, 71.8, 71.2, 70.9].enumerated().map { i, kg in
                WeightEntry(date: cal.date(byAdding: .day, value: -(6 - i) * 4, to: .now)!, kg: kg)
            }
        }
    }

    // MARK: Persistence plumbing

    private func persist() {
        guard !isRestoring, let persistence else { return }
        saveTask?.cancel()
        let snapshot = snapshot()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            persistence.save(snapshot)
        }
    }

    private func reschedule() {
        guard !isRestoring, persistence != nil else { return }
        Reminders.shared.schedule(for: self)
    }

    func snapshot() -> Snapshot {
        Snapshot(hasOnboarded: hasOnboarded, name: name, goal: goal, focus: focus.map(\.rawValue),
                 level: level, trainingDays: Array(trainingDays), sessionMinutes: sessionMinutes,
                 quietMode: quietMode, remindersOn: remindersOn, reminder: reminder, voiceOn: voiceOn,
                 soundsOn: soundsOn, healthOn: healthOn, intensity: intensity, isPro: isPro,
                 activeProgramID: activeProgramID, programDay: programDay,
                 week: Dictionary(uniqueKeysWithValues: week.map { (String($0.key), $0.value.id) }),
                 favorites: Array(favorites), customWorkouts: customWorkouts.map(CustomWorkoutRecord.init),
                 history: history, weights: weights)
    }

    private func restore(from s: Snapshot) {
        isRestoring = true
        defer { isRestoring = false }
        hasOnboarded = s.hasOnboarded
        name = s.name
        goal = s.goal
        focus = Set(s.focus.compactMap(BodyRegion.init(rawValue:)))
        level = s.level
        trainingDays = Set(s.trainingDays)
        sessionMinutes = s.sessionMinutes
        quietMode = s.quietMode
        remindersOn = s.remindersOn
        reminder = s.reminder
        voiceOn = s.voiceOn
        soundsOn = s.soundsOn
        healthOn = s.healthOn
        intensity = s.intensity
        isPro = s.isPro
        activeProgramID = s.activeProgramID
        programDay = s.programDay
        customWorkouts = s.customWorkouts.compactMap(\.workout)
        favorites = Set(s.favorites)
        week = Dictionary(uniqueKeysWithValues: s.week.compactMap { key, id -> (Int, Workout)? in
            guard let day = Int(key), let w = workout(id: id) else { return nil }
            return (day, w)
        })
        history = s.history
        weights = s.weights
    }
}
