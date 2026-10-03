//
//  Components.swift
//  Home Workout
//

import SwiftUI

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Palette.ink
    var foreground: Color = Palette.canvas

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(17, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(tint, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(15, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(Palette.raised, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var accent: PrimaryButtonStyle { PrimaryButtonStyle(tint: Palette.persimmon, foreground: .white) }
}

extension ButtonStyle where Self == SoftButtonStyle {
    static var soft: SoftButtonStyle { SoftButtonStyle() }
}

/// Circular icon button used on top bars and the player.
struct RoundIcon: View {
    let symbol: String
    var size: CGFloat = 44
    var tint: Color = Palette.ink
    var fill: Color = Palette.surface
    /// Adds a soft shadow so the button reads on top of video.
    var floating = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(fill, in: .circle)
            .shadow(color: .black.opacity(floating ? 0.12 : 0), radius: 10, y: 3)
    }
}

// MARK: - Chips & tags

struct Chip: View {
    let title: String
    var symbol: String? = nil
    var selected: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let symbol { Image(systemName: symbol).font(.system(size: 13, weight: .semibold)) }
            Text(title).font(.ui(14, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .foregroundStyle(selected ? Palette.canvas : Palette.ink)
        .background(selected ? Palette.ink : Palette.surface, in: .capsule)
        .overlay(Capsule().strokeBorder(selected ? .clear : Palette.hairline))
        .animation(.snappy(duration: 0.2), value: selected)
    }
}

/// Little coloured dot + label.
struct Tag: View {
    let title: String
    let tint: Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 7, height: 7)
            Text(title).font(.ui(12, weight: .semibold)).foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(.ultraThinMaterial, in: .capsule)
    }
}

/// Three ascending bars for difficulty.
struct LevelBars: View {
    let level: Level
    var tint: Color = Palette.ink
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i <= level.bars ? tint : tint.opacity(0.2))
                    .frame(width: 4, height: CGFloat(4 + i * 3))
            }
        }
        .accessibilityLabel(level.title)
    }
}

/// "12 min · 8 moves · Beginner" row.
struct MetaLine: View {
    let workout: Workout
    var color: Color = Palette.inkSoft
    /// Drops the level name (bars only) for narrow rows.
    var compact = false
    var body: some View {
        HStack(spacing: 10) {
            Label("\(workout.minutes) min", systemImage: "clock")
            Text("·")
            Text("\(workout.blocks.count) moves")
            Text("·")
            HStack(spacing: 5) {
                LevelBars(level: workout.level, tint: color)
                if !compact { Text(workout.level.title) }
            }
        }
        .lineLimit(1)
        .labelStyle(.titleOnly)
        .font(.ui(13, weight: .medium))
        .foregroundStyle(color)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.display(22))
                .foregroundStyle(Palette.ink)
            Spacer()
            if let action {
                Button(action) { onAction?() }
                    .font(.ui(14, weight: .semibold))
                    .foregroundStyle(Palette.persimmon)
            }
        }
        .padding(.horizontal, Metric.gutter)
    }
}

// MARK: - Workout cards

/// Tall poster card used in carousels.
struct WorkoutPoster: View {
    let workout: Workout
    var width: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                MoveStage(exercise: workout.cover, radius: Metric.tileRadius)
                    .frame(width: width, height: width)
                HStack {
                    Tag(title: workout.style.title, tint: workout.style.tint)
                    Spacer()
                    if workout.isPro { ProBadge() }
                }
                .padding(12)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                    .font(.display(19))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                MetaLine(workout: workout)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: width)
    }
}

/// Compact row with square thumbnail.
struct WorkoutRow: View {
    let workout: Workout
    var body: some View {
        HStack(spacing: 14) {
            MoveStage(exercise: workout.cover, radius: 18)
                .frame(width: 76, height: 76)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Circle().fill(workout.style.tint).frame(width: 7, height: 7)
                    Text(workout.style.title.uppercased())
                        .font(.ui(11, weight: .bold)).tracking(1)
                        .foregroundStyle(Palette.inkSoft)
                    if workout.isPro { ProBadge(compact: true) }
                }
                Text(workout.title).font(.display(18)).foregroundStyle(Palette.ink).lineLimit(1)
                MetaLine(workout: workout, compact: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.inkFaint)
        }
        .padding(10)
        .background(Palette.surface, in: .rect(cornerRadius: Metric.tileRadius, style: .continuous))
    }
}

struct ProBadge: View {
    var compact = false
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkle")
            if !compact { Text("PLUS") }
        }
        .font(.ui(10, weight: .heavy))
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 5 : 8)
        .frame(height: compact ? 18 : 24)
        .background(Palette.plum, in: .capsule)
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let value: String
    let label: String
    var symbol: String
    var tint: Color = Palette.persimmon

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.15), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.numeral(24)).foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Text(label).font(.ui(12, weight: .medium)).foregroundStyle(Palette.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Palette.surface, in: .rect(cornerRadius: Metric.tileRadius, style: .continuous))
    }
}

// MARK: - Misc

/// Squiggle mark used as the brand glyph.
struct MovaMark: View {
    var size: CGFloat = 28
    var color: Color = Palette.persimmon
    var body: some View {
        Canvas { ctx, s in
            var p = Path()
            let w = s.width, h = s.height
            p.move(to: CGPoint(x: w * 0.08, y: h * 0.78))
            p.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.5),
                       control1: CGPoint(x: w * 0.2, y: h * 0.1), control2: CGPoint(x: w * 0.38, y: h * 0.1))
            p.addCurve(to: CGPoint(x: w * 0.92, y: h * 0.22),
                       control1: CGPoint(x: w * 0.62, y: h * 0.9), control2: CGPoint(x: w * 0.8, y: h * 0.9))
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: w * 0.16, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

struct Wordmark: View {
    var size: CGFloat = 26
    var color: Color = Palette.ink
    var body: some View {
        HStack(spacing: size * 0.18) {
            MovaMark(size: size * 0.95)
            Text(Brand.name)
                .font(.display(size, weight: .black))
                .foregroundStyle(color)
        }
    }
}

extension View {
    func cardBackground(_ color: Color = Palette.surface, radius: CGFloat = Metric.cardRadius) -> some View {
        background(color, in: .rect(cornerRadius: radius, style: .continuous))
    }
}
