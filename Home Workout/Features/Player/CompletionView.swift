//
//  CompletionView.swift
//  Home Workout
//

import SwiftUI

struct CompletionView: View {
    let workout: Workout
    let summary: SessionSummary
    var onDone: (Int) -> Void

    @Environment(AppState.self) private var app
    @State private var feeling: Int?
    @State private var appeared = false

    private var minutes: Int { summary.minutes }
    /// Streak including this session (it's saved when the user taps Done).
    private var projectedStreak: Int { app.didWorkout(on: .now) ? app.streak : app.streak + 1 }

    private let feelings: [(String, String)] = [("Too easy", "tortoise.fill"), ("Just right", "hand.thumbsup.fill"), ("Tough", "flame.fill")]

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            Confetti(active: appeared).ignoresSafeArea().allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 26) {
                    // Medal
                    ZStack {
                        Circle().fill(Palette.persimmon).frame(width: 150, height: 150)
                            .shadow(color: Palette.persimmon.opacity(0.4), radius: 30, y: 12)
                        Circle().strokeBorder(.white.opacity(0.35), lineWidth: 3).frame(width: 128, height: 128)
                        VStack(spacing: 0) {
                            MovaMark(size: 44, color: .white)
                            Text("\(minutes) min").font(.numeral(20)).foregroundStyle(.white)
                        }
                    }
                    .scaleEffect(appeared ? 1 : 0.4)
                    .rotationEffect(.degrees(appeared ? 0 : -30))
                    .padding(.top, 50)

                    VStack(spacing: 8) {
                        Text("Nailed it, \(app.displayName)!")
                            .font(.display(34)).foregroundStyle(Palette.ink)
                        Text("\(workout.title) is in the books.")
                            .font(.ui(16)).foregroundStyle(Palette.inkSoft)
                    }

                    HStack(spacing: 10) {
                        StatTile(value: "\(minutes)", label: plural(minutes, "minute"), symbol: "clock.fill", tint: Palette.persimmon)
                        StatTile(value: "\(summary.moves)", label: plural(summary.moves, "move"), symbol: "figure.cross.training", tint: Palette.sky)
                        StatTile(value: "\(summary.calories)", label: "kcal", symbol: "flame.fill", tint: Palette.sun)
                    }

                    HStack(spacing: 14) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 22)).foregroundStyle(Palette.persimmon)
                            .symbolEffect(.bounce, value: appeared)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(projectedStreak == 1 ? "Day one of your streak" : "\(projectedStreak)-day streak").font(.display(20)).foregroundStyle(Palette.ink)
                            Text("Come back tomorrow to keep it alive.").font(.ui(14)).foregroundStyle(Palette.inkSoft)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .cardBackground(Palette.persimmonSoft, radius: Metric.tileRadius)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("How did that feel?").font(.display(22)).foregroundStyle(Palette.ink)
                        HStack(spacing: 10) {
                            ForEach(feelings.indices, id: \.self) { i in
                                Button { feeling = i } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: feelings[i].1).font(.system(size: 20))
                                        Text(feelings[i].0).font(.ui(14, weight: .semibold))
                                    }
                                    .foregroundStyle(feeling == i ? .white : Palette.ink)
                                    .frame(maxWidth: .infinity).frame(height: 84)
                                    .background(feeling == i ? Palette.ink : Palette.surface,
                                                in: .rect(cornerRadius: 20, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if let feeling {
                            Text(["Noted — we'll turn it up next time.", "Perfect. We'll keep this pace.", "Thanks! Next session will be a touch lighter."][feeling])
                                .font(.ui(14)).foregroundStyle(Palette.inkSoft)
                                .transition(.opacity)
                        }
                    }
                    .animation(.snappy, value: feeling)
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                ShareLink(item: "I just finished \(workout.title) on Mova 💪") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 58, height: 58)
                        .background(Palette.raised, in: .circle)
                }
                Button("Done") { onDone(feeling ?? 1) }.buttonStyle(.accent)
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 8)
            .background(Palette.canvas)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.45).delay(0.15)) { appeared = true }
        }
    }
}

/// Lightweight falling confetti.
struct Confetti: View {
    let active: Bool
    private struct Piece {
        let x: CGFloat
        let delay: Double
        let color: Color
        let size: CGFloat
        let spin: Double
    }

    private static let colors: [Color] = [Palette.persimmon, Palette.sun, Palette.lilac, Palette.mint, Palette.sky]

    private let pieces: [Piece] = (0..<40).map { (i: Int) -> Piece in
        let x = CGFloat((i * 37) % 100) / 100
        let delay = Double(i % 10) * 0.08
        let size = CGFloat(6 + (i % 4) * 3)
        let spin = Double((i * 53) % 360)
        return Piece(x: x, delay: delay, color: Confetti.colors[i % 5], size: size, spin: spin)
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(pieces.indices, id: \.self) { i in
                let p = pieces[i]
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 1.6)
                    .rotationEffect(.degrees(active ? p.spin + 360 : p.spin))
                    .position(x: geo.size.width * p.x, y: active ? geo.size.height + 40 : -40)
                    .animation(.easeIn(duration: 2.4).delay(p.delay), value: active)
            }
        }
    }
}
