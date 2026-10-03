//
//  Exercise.swift
//  Home Workout
//

import SwiftUI
import AVFoundation

enum Muscle: String, Codable, CaseIterable, Identifiable {
    case core, quads, glutes, shoulders, back, hamstrings, chest, fullBody, triceps, traps, forearms, calves, biceps
    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullBody: "Full body"
        default: rawValue.capitalized
        }
    }

    /// Coarse body region used for filters and focus pickers.
    var region: BodyRegion {
        switch self {
        case .core: .core
        case .quads, .glutes, .hamstrings, .calves: .lower
        case .shoulders, .back, .chest, .triceps, .traps, .forearms, .biceps: .upper
        case .fullBody: .full
        }
    }
}

enum BodyRegion: String, CaseIterable, Identifiable {
    case full, core, upper, lower
    var id: String { rawValue }
    var title: String {
        switch self {
        case .full: "Full body"
        case .core: "Abs & core"
        case .upper: "Upper body"
        case .lower: "Legs & glutes"
        }
    }
    var symbol: String {
        switch self {
        case .full: "figure.mixed.cardio"
        case .core: "figure.core.training"
        case .upper: "figure.arms.open"
        case .lower: "figure.step.training"
        }
    }
}

enum MoveKind: String, Codable, CaseIterable, Identifiable {
    case strength, cardio, plyometrics, stretching, mobility, rehab, balance
    var id: String { rawValue }

    var title: String {
        switch self {
        case .plyometrics: "Power"
        case .stretching: "Stretch"
        case .rehab: "Recovery"
        default: rawValue.capitalized
        }
    }

    var tint: Color {
        switch self {
        case .strength: Palette.persimmon
        case .cardio, .plyometrics: Palette.sun
        case .stretching, .rehab: Palette.lilac
        case .mobility, .balance: Palette.mint
        }
    }
}

enum Level: String, Codable, CaseIterable, Identifiable, Comparable {
    case beginner, intermediate, advanced
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var bars: Int { switch self { case .beginner: 1; case .intermediate: 2; case .advanced: 3 } }
    static func < (a: Level, b: Level) -> Bool { a.bars < b.bars }
}

/// The only kit a home move may need.
enum Equipment: String, Codable, CaseIterable, Identifiable {
    case none, mat, band, chair, wall
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "No equipment"
        case .mat: "Mat"
        case .band: "Band"
        case .chair: "Chair"
        case .wall: "Wall"
        }
    }
    var symbol: String {
        switch self {
        case .none: "figure.stand"
        case .mat: "rectangle.portrait"
        case .band: "point.topleft.down.to.point.bottomright.curvepath"
        case .chair: "chair.fill"
        case .wall: "square.split.1x2"
        }
    }
}

struct Exercise: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let muscle: Muscle
    let secondary: [Muscle]
    let kind: MoveKind
    let level: Level
    let video: String
    let steps: [String]
    let about: String
    let bg: String
    /// Missing in older catalogs; treated as bodyweight.
    let equipment: Equipment?

    var gear: Equipment { equipment ?? .none }

    /// Background colour of the studio in the clip, so cards can blend into it.
    var stageColor: Color { Color(hex: bg) }
    /// Darker studio backgrounds need light overlays.
    var isDarkStage: Bool {
        var v: UInt64 = 0
        Scanner(string: bg).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF), g = Double((v >> 8) & 0xFF), b = Double(v & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) < 150
    }

    var videoURL: URL? { Bundle.main.url(forResource: video, withExtension: "mp4") }
    var thumbnail: UIImage? {
        if let cached = ThumbnailCache.shared.object(forKey: video as NSString) { return cached }
        guard let url = Bundle.main.url(forResource: video, withExtension: "jpg"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        ThumbnailCache.shared.setObject(image, forKey: video as NSString)
        return image
    }

    /// Display name with the clip-library suffixes tidied away.
    var displayName: String {
        name.replacingOccurrences(of: " Cardio", with: "")
            .replacingOccurrences(of: " Workout", with: "")
    }

    static func == (a: Exercise, b: Exercise) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

enum ThumbnailCache {
    static let shared = NSCache<NSString, UIImage>()
    static let backdrops = NSCache<NSString, UIImage>()
}

extension Exercise {
    /// The studio without the trainer: the still's outer columns averaged and
    /// stretched, giving the wall-to-floor gradient to paint behind the clip.
    var backdrop: UIImage? {
        if let cached = ThumbnailCache.backdrops.object(forKey: video as NSString) { return cached }
        guard let cg = thumbnail?.cgImage, let image = Self.edgeGradient(from: cg) else { return nil }
        ThumbnailCache.backdrops.setObject(image, forKey: video as NSString)
        return image
    }

    /// Same as `backdrop`, but sampled from a decoded video frame so it matches
    /// the colour the player actually renders.
    func videoBackdrop() async -> UIImage? {
        let key = "\(video)-live" as NSString
        if let cached = ThumbnailCache.backdrops.object(forKey: key) { return cached }
        guard let url = videoURL else { return nil }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        guard let frame = try? await generator.image(at: CMTime(value: 1, timescale: 10)).image,
              let image = Self.edgeGradient(from: frame) else { return nil }
        ThumbnailCache.backdrops.setObject(image, forKey: key)
        return image
    }

    private static func edgeGradient(from cg: CGImage) -> UIImage? {
        // Skip the outermost pixels: some clips carry a thin dark border.
        let strip = max(2, cg.width / 40)
        let inset = max(3, cg.width / 40)
        let rows = CGRect(x: 0, y: inset, width: strip, height: cg.height - inset * 2)
        guard let left = cg.cropping(to: rows.offsetBy(dx: CGFloat(inset), dy: 0)),
              let right = cg.cropping(to: rows.offsetBy(dx: CGFloat(cg.width - inset - strip), dy: 0)) else { return nil }
        let size = CGSize(width: 8, height: CGFloat(cg.height) / 4)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            UIImage(cgImage: left).draw(in: CGRect(origin: .zero, size: size))
            UIImage(cgImage: right).draw(in: CGRect(origin: .zero, size: size), blendMode: .normal, alpha: 0.5)
        }
        return image
    }
}

// MARK: - Workouts

/// One slot in a workout: an exercise done for time or for reps.
struct Block: Identifiable, Hashable {
    let id = UUID()
    let exercise: Exercise
    var seconds: Int?
    var reps: Int?

    var target: String {
        if let reps { return "×\(reps)" }
        return "\(seconds ?? 30)s"
    }
    /// Rough duration for totals; reps assume ~3s each.
    var estimatedSeconds: Int { seconds ?? (reps ?? 10) * 3 }
}

enum WorkoutStyle: String, CaseIterable {
    case sweat, sculpt, flow, core, quick
    var title: String {
        switch self {
        case .sweat: "Sweat"
        case .sculpt: "Sculpt"
        case .flow: "Flow"
        case .core: "Core"
        case .quick: "Quick hit"
        }
    }
    var tint: Color {
        switch self {
        case .sweat: Palette.sun
        case .sculpt: Palette.persimmon
        case .flow: Palette.lilac
        case .core: Palette.mint
        case .quick: Palette.sky
        }
    }
}

struct Workout: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let style: WorkoutStyle
    let region: BodyRegion
    let level: Level
    var blocks: [Block]
    var rounds: Int = 1
    var restSeconds: Int = 20
    var isPro: Bool = false
    var isCustom: Bool = false

    static func custom(id: String = "custom-\(UUID().uuidString)", title: String, blocks: [Block],
                       rounds: Int, restSeconds: Int) -> Workout {
        Workout(id: id, title: title, subtitle: "Built by you", style: .sculpt,
                region: dominantRegion(of: blocks), level: blocks.map(\.exercise.level).max() ?? .beginner,
                blocks: blocks, rounds: rounds, restSeconds: restSeconds, isCustom: true)
    }

    private static func dominantRegion(of blocks: [Block]) -> BodyRegion {
        let counts = Dictionary(grouping: blocks, by: { $0.exercise.muscle.region }).mapValues(\.count)
        let top = counts.max { $0.value < $1.value }
        return (top?.value ?? 0) * 2 > blocks.count ? top!.key : .full
    }

    var exerciseCount: Int { blocks.count * rounds }
    var minutes: Int {
        let work = blocks.reduce(0) { $0 + $1.estimatedSeconds } * rounds
        let rest = restSeconds * max(0, exerciseCount - 1)
        return max(1, Int((Double(work + rest) / 60).rounded()))
    }
    /// Estimate for a 70 kg person; the player measures the real number.
    var calories: Int { Calories.estimate(for: self, bodyWeightKg: 70) }
    /// Clip used for the cover image.
    var cover: Exercise { blocks.first!.exercise }
    var muscles: [Muscle] {
        var seen: [Muscle] = []
        for b in blocks where !seen.contains(b.exercise.muscle) { seen.append(b.exercise.muscle) }
        return seen
    }

    static func == (a: Workout, b: Workout) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

/// A multi-week guided plan.
struct Program: Identifiable, Hashable {
    let id: String
    let title: String
    let pitch: String
    let weeks: Int
    let daysPerWeek: Int
    let level: Level
    let tint: Color
    let cover: Exercise
    let schedule: [Workout]
    var isPro: Bool = false

    var totalDays: Int { weeks * daysPerWeek }
    /// Workout for a 1-based program day.
    func workout(forDay day: Int) -> Workout { schedule[(max(day, 1) - 1) % schedule.count] }

    static func == (a: Program, b: Program) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}
