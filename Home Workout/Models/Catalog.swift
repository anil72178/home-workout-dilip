//
//  Catalog.swift
//  Home Workout
//
//  Built-in moves (backed by the licensed clips), curated workouts and programs.
//  Content is placeholder curation for the design review.
//

import Foundation

enum Catalog {

    // MARK: Moves

    static let exercises: [Exercise] = {
        guard let url = Bundle.main.url(forResource: "HomeExercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Exercise].self, from: data) else { return [] }
        return list.sorted { $0.displayName < $1.displayName }
    }()

    private static let byName: [String: Exercise] = Dictionary(
        exercises.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })

    private static let byID: [String: Exercise] = Dictionary(
        exercises.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    static func move(_ name: String) -> Exercise? { byName[name.lowercased()] }
    static func exercise(id: String) -> Exercise? { byID[id] }

    /// Builds blocks from (name, seconds) pairs, skipping anything without a clip.
    private static func timed(_ items: [(String, Int)]) -> [Block] {
        items.compactMap { n, s in move(n).map { Block(exercise: $0, seconds: s) } }
    }
    private static func mixed(_ items: [(String, Int, Bool)]) -> [Block] {
        items.compactMap { n, v, isReps in
            move(n).map { isReps ? Block(exercise: $0, reps: v) : Block(exercise: $0, seconds: v) }
        }
    }

    // MARK: Workouts

    static let wakeUpFlow = Workout(
        id: "wake-up-flow", title: "Wake-Up Flow", subtitle: "Unstick your spine and hips before coffee",
        style: .flow, region: .full, level: .beginner,
        blocks: timed([("Cat Cow Back Stretch", 40), ("Downward Dog Hold", 30), ("Inchworm Walkout", 40),
                       ("Spiderman Lunges", 40), ("Warrior 1 Alignment", 30), ("Shoulder Circle", 30),
                       ("Hip Circle", 30), ("Uttanasana (Standing Forward Fold)", 30)]),
        restSeconds: 10)

    static let livingRoomSweat = Workout(
        id: "living-room-sweat", title: "Living Room Sweat", subtitle: "Two rounds of heart-pumping cardio",
        style: .sweat, region: .full, level: .intermediate,
        blocks: timed([("Jumping Jack", 40), ("High Knee", 40), ("Burpee", 30), ("Mountain Climber", 40),
                       ("Skater Hops", 40), ("Plank Jacks", 30), ("Jump Squat", 30), ("Butt Kick", 40)]),
        rounds: 2, restSeconds: 20)

    static let classic7 = Workout(
        id: "classic-7", title: "The 7-Minute Classic", subtitle: "Twelve moves, thirty seconds each",
        style: .quick, region: .full, level: .beginner,
        blocks: timed([("Jumping Jack", 30), ("Wall Sit", 30), ("Push-up", 30), ("Crunch", 30),
                       ("Air Squat", 30), ("Close Grip Triceps Push-up", 30), ("Plank", 30), ("High Knee", 30),
                       ("Forward Lunges", 30), ("Push Up Arm Lift", 30), ("Side Plank", 30)]),
        restSeconds: 10)

    static let coreCrusher = Workout(
        id: "core-crusher", title: "Core Crusher", subtitle: "Abs, obliques and deep core in 12 minutes",
        style: .core, region: .core, level: .intermediate,
        blocks: mixed([("Crunch", 15, true), ("Bicycle Crunch", 40, false), ("Russian Twist", 40, false),
                       ("V-Up", 12, true), ("Hollow Hold", 30, false), ("Flutter Kicks", 40, false),
                       ("Plank", 45, false), ("Dead Bug", 40, false), ("Side Plank", 30, false)]),
        restSeconds: 15)

    static let glutLab = Workout(
        id: "glute-lab", title: "Glute Lab", subtitle: "Floor-based burn for hips and glutes",
        style: .sculpt, region: .lower, level: .beginner,
        blocks: mixed([("Glute Bridge", 15, true), ("Donkey Single Leg Kick", 40, false), ("Fire Hydrant", 40, false),
                       ("Frog Pump", 20, true), ("Single Leg Glute Bridge", 10, true), ("Glute Bridge March", 40, false),
                       ("Glute Bridge Hold", 30, false), ("Sumo Tap", 40, false)]),
        restSeconds: 15)

    static let legDay = Workout(
        id: "leg-day", title: "Leg Day, No Gym", subtitle: "Squats, lunges and a wall-sit finisher",
        style: .sculpt, region: .lower, level: .intermediate,
        blocks: mixed([("Air Squat", 20, true), ("Forward Lunges", 12, true), ("Bodyweight Bulgarian Split Squat", 10, true),
                       ("Cossack Squat", 40, false), ("Lateral Lunge", 12, true), ("Jump Squat", 30, false),
                       ("Wall Sit", 45, false)]),
        rounds: 2, restSeconds: 20)

    static let upperBuilder = Workout(
        id: "upper-builder", title: "Upper Body Builder", subtitle: "Every push-up variation you need",
        style: .sculpt, region: .upper, level: .intermediate,
        blocks: mixed([("Knee Push-ups", 12, true), ("Push-up", 10, true), ("Pike Push-up", 8, true),
                       ("Wide Push-up", 10, true), ("Diamond Push-up", 8, true), ("Plank to Downward Dog", 40, false),
                       ("Superman", 40, false), ("Prone Back Extension", 30, false)]),
        restSeconds: 20, isPro: true)

    static let deskReset = Workout(
        id: "desk-reset", title: "Desk Reset", subtitle: "Five minutes for necks, wrists and backs",
        style: .flow, region: .upper, level: .beginner,
        blocks: timed([("Neck Half Circle", 30), ("Shoulder Circle", 30), ("Cross-body Shoulder Stretch", 30),
                       ("T-spine Rotation", 40), ("Wrist Circle", 30), ("Standing Hips Stretch", 30),
                       ("Standing Quadriceps Stretch", 30)]),
        restSeconds: 5)

    static let bedtime = Workout(
        id: "bedtime-unwind", title: "Bedtime Unwind", subtitle: "Slow stretches that switch you off",
        style: .flow, region: .full, level: .beginner,
        blocks: timed([("Child Pose", 60), ("Cat Pose Stretching", 40), ("Ardha Matsyendrasana (Seated Spinal Twist)", 45),
                       ("Gentle Fold Seated Forward Fold", 45), ("Hip Stretch", 45), ("Supine Recovery Breathing", 60)]),
        restSeconds: 5)

    static let quietHIIT = Workout(
        id: "quiet-hiit", title: "Neighbor-Friendly HIIT", subtitle: "All the sweat, zero jumping",
        style: .sweat, region: .full, level: .beginner,
        blocks: timed([("Butt Kick (Low Impact)", 40), ("Bear Crawl", 30), ("Mountain Climber", 40), ("Air Squat", 40),
                       ("Inch Worm", 40), ("Lateral Lunge", 40), ("Plank Hip Dip", 30), ("Glute Bridge March", 40)]),
        rounds: 2, restSeconds: 15)

    static let powerPlyo = Workout(
        id: "power-plyo", title: "Power Plyo", subtitle: "Explosive jumps for athletes",
        style: .sweat, region: .lower, level: .advanced,
        blocks: timed([("Tuck Jump", 30), ("Jump Lunges", 30), ("Burpee to Tuck Jump", 30),
                       ("Plyometric Push-ups", 20), ("Skater Jump", 30), ("Split Squat Jump", 30)]),
        rounds: 3, restSeconds: 30, isPro: true)

    static let tabata = Workout(
        id: "tabata-4", title: "4-Minute Tabata", subtitle: "20 on, 10 off. That's it.",
        style: .quick, region: .full, level: .intermediate,
        blocks: timed([("Burpee", 20), ("Mountain Climber", 20), ("Jump Squat", 20), ("High Knee", 20)]),
        rounds: 2, restSeconds: 10)

    static let plankParty = Workout(
        id: "plank-party", title: "Plank Party", subtitle: "Six planks, no boring ones",
        style: .core, region: .core, level: .intermediate,
        blocks: timed([("Plank", 40), ("Plank Jacks", 30), ("Plank Hip Dip", 40), ("Plank T Twist", 40),
                       ("Side Plank Reach Through", 30), ("Plank with Reach", 40)]),
        restSeconds: 15)

    static let mobility = Workout(
        id: "morning-mobility", title: "Joint Tune-Up", subtitle: "Hips, spine and shoulders that move freely",
        style: .flow, region: .full, level: .beginner,
        blocks: timed([("90-90 Rotation", 40), ("Warm Up Squat+goodmorning", 40), ("Spiderman Lunges", 40),
                       ("Reach to W", 30), ("Over Under", 40), ("Warm Up Wiper", 30), ("Crab Walk", 30)]),
        restSeconds: 10, isPro: true)

    static let workouts: [Workout] = [classic7, livingRoomSweat, coreCrusher, glutLab, wakeUpFlow, legDay,
                                      upperBuilder, deskReset, quietHIIT, bedtime, tabata, plankParty,
                                      powerPlyo, mobility].filter { !$0.blocks.isEmpty }

    static func workouts(in region: BodyRegion) -> [Workout] {
        workouts.filter { $0.region == region || region == .full && $0.style == .sweat }
    }

    // MARK: Programs

    static let programs: [Program] = [
        Program(id: "fresh-start", title: "Fresh Start", pitch: "A gentle four-week on-ramp for brand-new movers.",
                weeks: 4, daysPerWeek: 3, level: .beginner, tint: Palette.persimmon,
                cover: move("Air Squat") ?? exercises[0],
                schedule: [classic7, wakeUpFlow, glutLab]),
        Program(id: "core-21", title: "Core 21", pitch: "Twenty-one days to a stronger, steadier middle.",
                weeks: 3, daysPerWeek: 5, level: .intermediate, tint: Palette.mint,
                cover: move("Hollow Hold") ?? exercises[0],
                schedule: [coreCrusher, plankParty, deskReset, coreCrusher, bedtime], isPro: true),
        Program(id: "strong-at-home", title: "Strong at Home", pitch: "Six weeks of progressive bodyweight strength.",
                weeks: 6, daysPerWeek: 4, level: .intermediate, tint: Palette.sun,
                cover: move("Push-up") ?? exercises[0],
                schedule: [upperBuilder, legDay, livingRoomSweat, coreCrusher], isPro: true),
        Program(id: "bend-breathe", title: "Bend & Breathe", pitch: "Two weeks of daily mobility and calm.",
                weeks: 2, daysPerWeek: 7, level: .beginner, tint: Palette.lilac,
                cover: move("Downward Dog Hold") ?? exercises[0],
                schedule: [wakeUpFlow, deskReset, bedtime, mobility], isPro: true),
    ]
}
