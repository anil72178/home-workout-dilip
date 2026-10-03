//
//  Persistence.swift
//  Home Workout
//
//  Saves the user's data as one JSON file in Application Support.
//  Small, versioned and easy to migrate later.
//

import Foundation

struct Snapshot: Codable {
    var version = 1
    var hasOnboarded: Bool
    var name: String
    var goal: Goal
    var focus: [String]
    var level: Level
    var trainingDays: [Int]
    var sessionMinutes: Int
    var quietMode: Bool
    var remindersOn: Bool
    var reminder: Date
    var voiceOn: Bool
    var soundsOn: Bool
    var healthOn: Bool
    var intensity: Int
    var isPro: Bool
    var activeProgramID: String?
    var programDay: Int
    var week: [String: String]          // weekday index → workout id
    var favorites: [String]
    var customWorkouts: [CustomWorkoutRecord]
    var history: [CompletedSession]
    var weights: [WeightEntry]
}

/// A user-built workout, stored by exercise id.
struct CustomWorkoutRecord: Codable {
    struct Item: Codable {
        let exerciseID: String
        let seconds: Int?
        let reps: Int?
    }
    let id: String
    let title: String
    let items: [Item]
    let rounds: Int
    let restSeconds: Int

    init(_ w: Workout) {
        id = w.id
        title = w.title
        items = w.blocks.map { Item(exerciseID: $0.exercise.id, seconds: $0.seconds, reps: $0.reps) }
        rounds = w.rounds
        restSeconds = w.restSeconds
    }

    var workout: Workout? {
        let blocks = items.compactMap { item in
            Catalog.exercise(id: item.exerciseID).map { Block(exercise: $0, seconds: item.seconds, reps: item.reps) }
        }
        guard !blocks.isEmpty else { return nil }
        return Workout.custom(id: id, title: title, blocks: blocks, rounds: rounds, restSeconds: restSeconds)
    }
}

struct Persistence {
    let url: URL

    init(filename: String = "mova-state.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent(filename)
    }

    func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    func save(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}
