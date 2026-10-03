//
//  SessionPlan.swift
//  Home Workout
//
//  Flattens a workout (plus optional warm-up / cool-down) into the
//  ordered list of steps the player walks through, scaled to the user's
//  adaptive intensity.
//

import Foundation

enum Phase: String {
    case warmUp = "Warm-up", main = "Workout", coolDown = "Cool-down"
}

struct SessionStep: Identifiable, Hashable {
    let id = UUID()
    let block: Block
    let phase: Phase
    let round: Int
}

struct SessionOptions: Hashable {
    var warmUp = true
    var coolDown = true
    var quiet = false
    /// -2 … +2, from post-workout feedback.
    var intensity = 0
}

enum SessionPlan {
    static let warmUpBlocks: [Block] = [("Dynamic Arms Stretch", 30), ("Hip Circle", 30), ("Leg Swing", 30)]
        .compactMap { n, s in Catalog.move(n).map { Block(exercise: $0, seconds: s) } }

    static let coolDownBlocks: [Block] = [("Standing Hamstring Stretch", 30), ("Child Pose", 40)]
        .compactMap { n, s in Catalog.move(n).map { Block(exercise: $0, seconds: s) } }

    /// Moves that involve jumping; swapped out in quiet mode.
    static func isLoud(_ e: Exercise) -> Bool {
        e.kind == .plyometrics || ["jump", "jack", "burpee", "hop", "skater"].contains { e.name.lowercased().contains($0) }
    }

    static func quietSwap(for e: Exercise) -> Exercise {
        let pool = Catalog.exercises.filter { $0.muscle.region == e.muscle.region && !isLoud($0) && $0.kind != .stretching }
        return pool.first { $0.kind == .cardio } ?? pool.first ?? e
    }

    /// Work time and reps grow or shrink with intensity; rest moves the other way.
    static func scaled(_ block: Block, intensity: Int) -> Block {
        guard intensity != 0, block.exercise.kind != .stretching else { return block }
        var b = block
        if let s = b.seconds { b.seconds = max(15, s + intensity * 5) }
        if let r = b.reps { b.reps = max(4, r + intensity * 2) }
        return b
    }

    static func restSeconds(for workout: Workout, intensity: Int) -> Int {
        guard workout.restSeconds > 0 else { return 0 }
        return max(5, workout.restSeconds - intensity * 5)
    }

    static func steps(for workout: Workout, options: SessionOptions) -> [SessionStep] {
        var out: [SessionStep] = []
        if options.warmUp && workout.style != .flow {
            out += warmUpBlocks.map { SessionStep(block: $0, phase: .warmUp, round: 1) }
        }
        for r in 1...max(1, workout.rounds) {
            for b in workout.blocks {
                var block = b
                if options.quiet && isLoud(b.exercise) {
                    block = Block(exercise: quietSwap(for: b.exercise), seconds: b.seconds ?? 30, reps: nil)
                }
                out.append(SessionStep(block: scaled(block, intensity: options.intensity), phase: .main, round: r))
            }
        }
        if options.coolDown && workout.style != .flow {
            out += coolDownBlocks.map { SessionStep(block: $0, phase: .coolDown, round: 1) }
        }
        return out
    }
}

/// MET-based calorie estimates: kcal = MET × kg × hours.
enum Calories {
    static func met(for kind: MoveKind) -> Double {
        switch kind {
        case .cardio: 8
        case .plyometrics: 9
        case .strength: 5
        case .balance: 3
        case .mobility, .rehab: 2.5
        case .stretching: 2.3
        }
    }

    static func burned(kind: MoveKind, seconds: Double, bodyWeightKg: Double) -> Double {
        met(for: kind) * bodyWeightKg * seconds / 3600
    }

    static func estimate(for workout: Workout, bodyWeightKg: Double) -> Int {
        let active = workout.blocks.reduce(0.0) {
            $0 + burned(kind: $1.exercise.kind, seconds: Double($1.estimatedSeconds), bodyWeightKg: bodyWeightKg)
        } * Double(workout.rounds)
        let rest = Double(workout.restSeconds * max(0, workout.exerciseCount - 1))
        return Int((active + 1.5 * bodyWeightKg * rest / 3600).rounded())
    }
}
