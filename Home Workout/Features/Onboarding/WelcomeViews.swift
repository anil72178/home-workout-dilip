//
//  WelcomeViews.swift
//  Home Workout
//

import SwiftUI

// MARK: - Welcome

struct WelcomeView: View {
    var onStart: () -> Void
    @Environment(Store.self) private var store
    @State private var drift = false
    @State private var restoring = false

    private let columns: [[String]] = [
        ["Jumping Jack", "Glute Bridge", "Downward Dog Hold", "Mountain Climber", "Air Squat"],
        ["Push-up", "Plank", "Burpee", "Child Pose", "Forward Lunges"],
        ["High Knee", "Side Plank", "Cat Cow Back Stretch", "Jump Squat", "Superman"],
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.canvas.ignoresSafeArea()

            // Drifting wall of moves
            HStack(alignment: .top, spacing: 10) {
                ForEach(columns.indices, id: \.self) { c in
                    let moves = (columns[c] + columns[c]).compactMap(Catalog.move)
                    VStack(spacing: 10) {
                        ForEach(Array(moves.enumerated()), id: \.offset) { i, ex in
                            MoveStage(exercise: ex, live: i == 1 && c != 1 || i == 2 && c == 1, radius: 22)
                        }
                    }
                    .offset(y: drift ? (c == 1 ? -260 : -520) : (c == 1 ? -120 : 0))
                }
            }
            .padding(.horizontal, 10)
            .frame(maxHeight: .infinity, alignment: .top)
            .rotationEffect(.degrees(-6))
            .scaleEffect(1.12)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.linear(duration: 40).repeatForever(autoreverses: true)) { drift = true }
            }

            VStack(spacing: 0) {
                LinearGradient(colors: [Palette.canvas.opacity(0), Palette.canvas],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 220)
                Palette.canvas.frame(height: 300)
            }
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 18) {
                Wordmark(size: 24)
                Text("Your living room\nis the gym now.")
                    .font(.display(40))
                    .foregroundStyle(Palette.ink)
                Text("180+ guided moves, a plan that fits your week, and zero equipment.")
                    .font(.ui(17))
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.bottom, 8)
                Button("Let's get moving", action: onStart)
                    .buttonStyle(.accent)
                Button(restoring ? "Checking…" : "Restore purchases") {
                    restoring = true
                    Task { await store.restore(); restoring = false }
                }
                    .font(.ui(15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Building

struct BuildingPlanView: View {
    var onDone: () -> Void
    @Environment(AppState.self) private var app
    @State private var progress = 0.0
    @State private var checked = 0

    private var lines: [String] {
        ["Matching moves to \(app.focus.map(\.title).sorted().first?.lowercased() ?? "your goals")",
         "Pacing for \(app.level.title.lowercased()) level",
         "Fitting \(app.sessionMinutes)-minute sessions into your week",
         app.quietMode ? "Leaving out the jumping" : "Mixing in some cardio bursts"]
    }

    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            ZStack {
                Circle().stroke(Palette.hairline, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Palette.persimmon, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Text("\(Int(progress * 100))%")
                        .font(.numeral(44))
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                    Text("building").font(.ui(14)).foregroundStyle(Palette.inkSoft)
                }
            }
            .frame(width: 190, height: 190)

            VStack(alignment: .leading, spacing: 14) {
                Text("Crafting your plan, \(app.displayName)").font(.display(26)).foregroundStyle(Palette.ink)
                ForEach(lines.indices, id: \.self) { i in
                    HStack(spacing: 12) {
                        Image(systemName: i < checked ? "checkmark.circle.fill" : "circle.dotted")
                            .foregroundStyle(i < checked ? Palette.persimmon : Palette.inkFaint)
                            .font(.system(size: 20))
                            .contentTransition(.symbolEffect(.replace))
                        Text(lines[i]).font(.ui(16)).foregroundStyle(i < checked ? Palette.ink : Palette.inkFaint)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            Spacer()
        }
        .task {
            for i in 1...lines.count {
                withAnimation(.easeInOut(duration: 0.6)) { progress = Double(i) / Double(lines.count) }
                try? await Task.sleep(for: .milliseconds(650))
                withAnimation(.snappy) { checked = i }
            }
            try? await Task.sleep(for: .milliseconds(450))
            onDone()
        }
    }
}

// MARK: - Plan reveal

struct PlanRevealView: View {
    var onContinue: () -> Void
    @Environment(AppState.self) private var app

    private var plan: [(Weekday, Workout?)] {
        Weekday.all.map { ($0, app.week[$0.index]) }
    }

    /// The first scheduled session from today onwards.
    private var firstUp: Workout? {
        (0..<7).lazy.compactMap { app.week[(app.todayIndex + $0) % 7] }.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Your plan is ready", color: Palette.persimmon)
                    Text("\(app.displayName), here's\nyour first week.")
                        .font(.display(36))
                        .foregroundStyle(Palette.ink)
                    Text("\(app.trainingDays.count) sessions · about \(app.sessionMinutes) min each · \(app.goal.title.lowercased())")
                        .font(.ui(15))
                        .foregroundStyle(Palette.inkSoft)
                }
                .padding(.top, 24)

                if let first = firstUp {
                    VStack(alignment: .leading, spacing: 0) {
                        MoveCover(exercise: first.cover, live: true)
                            .frame(height: 210)
                            .overlay(alignment: .topLeading) {
                                Tag(title: app.todaysWorkout == first ? "Up first · today" : "Up first", tint: Palette.persimmon).padding(14)
                            }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(first.title).font(.display(24)).foregroundStyle(Palette.ink)
                            MetaLine(workout: first)
                        }
                        .padding(18)
                    }
                    .cardBackground()
                    .clipShape(.rect(cornerRadius: Metric.cardRadius, style: .continuous))
                }

                VStack(spacing: 0) {
                    ForEach(plan, id: \.0.index) { day, workout in
                        HStack(spacing: 14) {
                            Text(day.name)
                                .font(.ui(13, weight: .bold))
                                .foregroundStyle(workout == nil ? Palette.inkFaint : Palette.ink)
                                .frame(width: 40, alignment: .leading)
                            if let workout {
                                MoveStage(exercise: workout.cover, radius: 10).frame(width: 40, height: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(workout.title).font(.ui(15, weight: .semibold)).foregroundStyle(Palette.ink)
                                    Text("\(workout.minutes) min · \(workout.style.title)").font(.ui(13)).foregroundStyle(Palette.inkSoft)
                                }
                            } else {
                                Text("Rest & recover").font(.ui(15)).foregroundStyle(Palette.inkFaint)
                                    .frame(height: 40)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        if day.index < 6 { Divider().overlay(Palette.hairline) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .cardBackground()
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Button("Start my plan", action: onContinue)
                .buttonStyle(.accent)
                .padding(.horizontal, Metric.gutter)
                .padding(.top, 12)
                .background(Palette.canvas.opacity(0.95))
        }
        .onAppear { app.generateWeek() }
    }
}
