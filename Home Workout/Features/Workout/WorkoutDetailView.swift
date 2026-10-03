//
//  WorkoutDetailView.swift
//  Home Workout
//

import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var options = SessionOptions()
    @State private var playing: Workout?
    @State private var guide: Exercise?
    @State private var showPaywall = false
    @State private var confirmDelete = false
    @State private var scheduledNote: String?

    private var steps: [SessionStep] { SessionPlan.steps(for: workout, options: options) }
    private var restSeconds: Int { SessionPlan.restSeconds(for: workout, intensity: options.intensity) }
    private var totalMinutes: Int {
        max(1, Int((Double(steps.reduce(0) { $0 + $1.block.estimatedSeconds } + restSeconds * max(0, steps.count - 1)) / 60).rounded()))
    }
    private var estimatedCalories: Int {
        let active = steps.reduce(0.0) {
            $0 + Calories.burned(kind: $1.block.exercise.kind, seconds: Double($1.block.estimatedSeconds), bodyWeightKg: app.bodyWeightKg)
        }
        return Int(active.rounded())
    }
    private var locked: Bool { workout.isPro && !app.isPro }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 26) {
                    titleBlock
                    statsRow
                    if app.intensity != 0 && !workout.isCustom {
                        Label(app.intensity > 0 ? "Turned up a notch based on your feedback" : "Eased off a little based on your feedback",
                              systemImage: "arrow.triangle.2.circlepath")
                            .font(.ui(13, weight: .medium))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    tuneCard
                    exerciseList
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.top, 22)
                .padding(.bottom, 120)
                .background(Palette.canvas)
            }
        }
        .scrollIndicators(.hidden)
        .background(Palette.canvas)
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) { startBar }
        .onAppear {
            options.quiet = app.quietMode
            options.intensity = app.intensity
        }
        .confirmationDialog("Delete \(workout.title)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete workout", role: .destructive) {
                app.deleteCustom(workout)
                dismiss()
            }
        }
        .overlay(alignment: .top) {
            if let note = scheduledNote {
                Label(note, systemImage: "calendar.badge.checkmark")
                    .font(.ui(14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).frame(height: 40)
                    .background(Palette.ink, in: .capsule)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .fullScreenCover(item: $playing) { PlayerView(workout: $0, options: options) }
        .sheet(item: $guide) { ex in
            NavigationStack { ExerciseDetailView(exercise: ex, inSheet: true) }
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    // MARK: Hero

    private var hero: some View {
        ZStack(alignment: .top) {
            workout.cover.stageColor
            MoveStage(exercise: workout.cover, live: true, radius: 0)
                .padding(.top, 70)
                .padding(.horizontal, 30)
            HStack {
                Button { dismiss() } label: { RoundIcon(symbol: "chevron.left", fill: .white, floating: true) }
                Spacer()
                Button { app.toggleFavorite(workout) } label: {
                    RoundIcon(symbol: app.favorites.contains(workout.id) ? "heart.fill" : "heart",
                              tint: app.favorites.contains(workout.id) ? Palette.persimmon : Palette.ink,
                              fill: .white, floating: true)
                        .contentTransition(.symbolEffect(.replace))
                }
                Menu {
                    Menu("Add to my week", systemImage: "calendar.badge.plus") {
                        ForEach(Weekday.all) { day in
                            Button(day.index == app.todayIndex ? "\(day.name) (today)" : day.name) { schedule(on: day) }
                        }
                    }
                    ShareLink(item: "I'm doing \(workout.title) on Mova — \(totalMinutes) minutes, no equipment.") {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    if workout.isCustom {
                        Button("Delete workout", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    }
                } label: {
                    RoundIcon(symbol: "ellipsis", fill: .white, floating: true)
                }
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 60)
        }
        .frame(height: 430)
        .clipped()
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Tag(title: workout.style.title, tint: workout.style.tint)
                Tag(title: workout.region.title, tint: Palette.ink.opacity(0.4))
                if workout.isPro { ProBadge() }
            }
            Text(workout.title).font(.display(34)).foregroundStyle(Palette.ink)
            Text(workout.subtitle).font(.ui(16)).foregroundStyle(Palette.inkSoft)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat("\(totalMinutes)", "minutes")
            divider
            stat("\(steps.count)", "moves")
            divider
            stat("~\(estimatedCalories)", "kcal")
            divider
            VStack(spacing: 6) {
                LevelBars(level: workout.level, tint: Palette.persimmon).frame(height: 22)
                Text(workout.level.title).font(.ui(12, weight: .medium)).foregroundStyle(Palette.inkSoft)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .cardBackground(radius: Metric.tileRadius)
    }

    private func schedule(on day: Weekday) {
        app.week[day.index] = workout
        app.trainingDays.insert(day.index)
        withAnimation(.snappy) { scheduledNote = "Added to \(day.name)" }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.snappy) { scheduledNote = nil }
        }
    }

    private var divider: some View { Rectangle().fill(Palette.hairline).frame(width: 1, height: 34) }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.numeral(22)).foregroundStyle(Palette.ink).contentTransition(.numericText())
            Text(label).font(.ui(12, weight: .medium)).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: value)
    }

    // MARK: Tune

    private var tuneCard: some View {
        VStack(spacing: 0) {
            tuneRow("flame", "Warm-up", "3 gentle moves to start", $options.warmUp)
            Divider().overlay(Palette.hairline).padding(.leading, 56)
            tuneRow("wind", "Cool-down", "Stretch it out at the end", $options.coolDown)
            Divider().overlay(Palette.hairline).padding(.leading, 56)
            tuneRow("speaker.slash", "Quiet mode", "Swap jumps for low-impact moves", $options.quiet)
        }
        .padding(.vertical, 4)
        .cardBackground(radius: Metric.tileRadius)
        .opacity(workout.style == .flow ? 0.9 : 1)
    }

    private func tuneRow(_ symbol: String, _ title: String, _ detail: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding.animation(.smooth)) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(Palette.raised, in: .circle)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.ui(15, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text(detail).font(.ui(13)).foregroundStyle(Palette.inkSoft)
                }
            }
        }
        .tint(Palette.persimmon)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: List

    private var exerciseList: some View {
        let groups: [(String, [SessionStep])] = {
            var result: [(String, [SessionStep])] = []
            for step in steps {
                let key = step.phase == .main && workout.rounds > 1 ? "Round \(step.round) of \(workout.rounds)" : step.phase.rawValue
                if result.last?.0 == key { result[result.count - 1].1.append(step) } else { result.append((key, [step])) }
            }
            return result
        }()

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("The moves").font(.display(22)).foregroundStyle(Palette.ink)
                Spacer()
                Text(restSeconds > 0 ? "\(restSeconds)s rest between" : "No rest between")
                    .font(.ui(13, weight: .medium)).foregroundStyle(Palette.inkSoft)
            }
            ForEach(groups, id: \.0) { title, items in
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(title)
                    VStack(spacing: 8) {
                        ForEach(items) { step in
                            Button { guide = step.block.exercise } label: { MoveRow(block: step.block) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: Start bar

    private var startBar: some View {
        Button {
            if locked { showPaywall = true } else { playing = workout }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: locked ? "lock.fill" : "play.fill")
                Text(locked ? "Unlock with Plus" : "Start · \(totalMinutes) min")
            }
        }
        .buttonStyle(locked ? PrimaryButtonStyle(tint: Palette.plum, foreground: .white) : .accent)
        .padding(.horizontal, Metric.gutter)
        .padding(.top, 10)
        .background(
            LinearGradient(colors: [Palette.canvas.opacity(0), Palette.canvas], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
    }
}

/// Row for one move inside a workout.
struct MoveRow: View {
    let block: Block
    var body: some View {
        HStack(spacing: 14) {
            MoveStage(exercise: block.exercise, radius: 14)
                .frame(width: 60, height: 60)
            VStack(alignment: .leading, spacing: 3) {
                Text(block.exercise.displayName)
                    .font(.ui(16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(block.exercise.muscle.title)
                    .font(.ui(13)).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            Text(block.target)
                .font(.numeral(16, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Palette.raised, in: .capsule)
        }
        .padding(8)
        .padding(.trailing, 6)
        .cardBackground(radius: 20)
    }
}
