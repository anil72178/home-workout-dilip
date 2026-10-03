//
//  PlayerView.swift
//  Home Workout
//
//  The full-screen session player. The upper half takes on the studio colour
//  of the current clip so the trainer appears to stand right in the screen.
//

import SwiftUI

struct PlayerView: View {
    let workout: Workout
    var options = SessionOptions()
    /// Set when this session is a day of the active program.
    var programDay: Int? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var app

    enum Stage: Equatable { case getReady, exercise, rest, finished }

    @State private var steps: [SessionStep] = []
    @State private var index = 0
    @State private var stage: Stage = .getReady
    @State private var remaining = 5
    @State private var stageLength = 5
    @State private var paused = false
    @State private var showPauseMenu = false
    @State private var guide: Exercise?
    @State private var coach = Coach()
    @State private var restSeconds = 0

    // Measurements
    @State private var elapsed = 0
    @State private var calories = 0.0
    @State private var completed: Set<Int> = []

    private var step: SessionStep? { steps.indices.contains(index) ? steps[index] : nil }
    private var nextStep: SessionStep? { steps.indices.contains(index + 1) ? steps[index + 1] : nil }
    private var summary: SessionSummary {
        SessionSummary(minutes: max(1, Int((Double(elapsed) / 60).rounded())),
                       calories: Int(calories.rounded()), moves: completed.count)
    }

    var body: some View {
        ZStack {
            switch stage {
            case .finished:
                CompletionView(workout: workout, summary: summary) { feeling in
                    save(feeling: feeling)
                    dismiss()
                }
                .transition(.move(edge: .bottom))
            case .rest:
                if let next = step {
                    RestView(next: next, position: index + 1, total: steps.count, remaining: remaining, length: stageLength,
                             onAdd: { remaining += 20; stageLength += 20 },
                             onSkip: { startExercise() },
                             onPause: { paused = true; showPauseMenu = true })
                        .transition(.opacity)
                }
            default:
                if let step { exerciseScreen(step) }
            }
        }
        .animation(.smooth(duration: 0.45), value: stage)
        .animation(.smooth(duration: 0.35), value: index)
        .statusBarHidden(stage != .finished)
        .persistentSystemOverlays(.hidden)
        .task {
            var opts = options
            opts.intensity = app.intensity
            steps = SessionPlan.steps(for: workout, options: opts)
            restSeconds = SessionPlan.restSeconds(for: workout, intensity: app.intensity)
            coach.voiceOn = app.voiceOn
            coach.soundsOn = app.soundsOn
            coach.start()
            UIApplication.shared.isIdleTimerDisabled = true
            if let first = steps.first { coach.say("Get ready. First up, \(first.block.exercise.displayName).") }
            #if DEBUG
            if DebugRoute.screen == "player" { index = 4; startExercise() }
            if DebugRoute.screen == "rest" { index = 4; stage = .rest; remaining = 18; stageLength = 20 }
            if DebugRoute.screen == "done" { elapsed = 600; calories = 74; completed = [0, 1, 2]; stage = .finished }
            #endif
            await runClock()
        }
        .onDisappear {
            coach.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && stage != .finished { paused = true }
        }
        .onChange(of: app.voiceOn) { _, on in coach.voiceOn = on }
        .sheet(isPresented: $showPauseMenu, onDismiss: runPendingAction) {
            PauseMenu(workout: workout, step: step, done: completed.count, total: steps.count,
                      onResume: { close(then: .resume) },
                      onRestart: { close(then: .restart) },
                      onCoolDown: { close(then: .coolDown) },
                      onFinish: { close(then: .finish) },
                      onQuit: { reason in
                          if reason == .tooHard { app.applyFeedback(2) }
                          if reason == .tooEasy { app.applyFeedback(0) }
                          close(then: .quit)
                      })
                .presentationDetents([.height(520)])
                .presentationCornerRadius(36)
        }
        .sheet(item: $guide, onDismiss: { paused = false }) { ex in
            NavigationStack { ExerciseDetailView(exercise: ex, inSheet: true) }
        }
    }

    // MARK: Pause menu actions

    private enum MenuAction { case resume, restart, coolDown, finish, quit }
    @State private var pendingAction: MenuAction?

    /// Actions run after the sheet has gone, so the player can change stage or close safely.
    private func close(then action: MenuAction) {
        pendingAction = action
        showPauseMenu = false
    }

    private func runPendingAction() {
        let action = pendingAction ?? .resume
        pendingAction = nil
        switch action {
        case .resume: paused = false
        case .restart: startExercise()
        case .coolDown:
            if let i = steps.firstIndex(where: { $0.phase == .coolDown }) { index = i; startExercise() } else { paused = false }
        case .finish: finish()
        case .quit: dismiss()
        }
    }

    // MARK: Clock

    private func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard !paused, stage != .finished else { continue }
            elapsed += 1
            if stage == .exercise, let step {
                calories += Calories.burned(kind: step.block.exercise.kind, seconds: 1, bodyWeightKg: app.bodyWeightKg)
            } else {
                calories += Calories.burned(kind: .stretching, seconds: 1, bodyWeightKg: app.bodyWeightKg) * 0.6
            }
            if stage == .exercise, step?.block.reps != nil { continue } // reps wait for "Done"
            if remaining > 1 {
                remaining -= 1
                cue(at: remaining)
            } else {
                advance()
            }
        }
    }

    /// Spoken and audible cues during countdowns.
    private func cue(at seconds: Int) {
        if seconds <= 3 { coach.tick() }
        if stage == .exercise, stageLength >= 20, seconds == stageLength / 2 { coach.say("Halfway. Keep it up.") }
        if stage == .exercise, stageLength >= 20, seconds == 10 { coach.say("Ten seconds.") }
        if stage == .rest, seconds == 5, let step { coach.say("Next, \(step.block.exercise.displayName).") }
    }

    private func startExercise() {
        stage = .exercise
        let block = step?.block
        let secs = block?.seconds ?? 0
        remaining = secs
        stageLength = max(secs, 1)
        paused = false
        coach.go()
        if let block {
            coach.say(block.reps.map { "\(block.exercise.displayName). \($0) reps." }
                      ?? "\(block.exercise.displayName). \(secs) seconds.")
        }
    }

    private func advance() {
        switch stage {
        case .getReady, .rest:
            startExercise()
        case .exercise:
            completed.insert(index)
            if index + 1 >= steps.count {
                finish()
            } else {
                index += 1
                if restSeconds > 0 && steps[index].phase == .main && steps[index - 1].phase == .main {
                    stage = .rest
                    remaining = restSeconds
                    stageLength = restSeconds
                    coach.say("Rest.")
                } else {
                    startExercise()
                }
            }
        case .finished: break
        }
    }

    private func previous() {
        guard index > 0 else { startExercise(); return }
        index -= 1
        startExercise()
    }

    private func finish() {
        guard !completed.isEmpty else { dismiss(); return }
        stage = .finished
        coach.celebrate()
    }

    private func save(feeling: Int) {
        guard !completed.isEmpty else { return }
        let s = summary
        let session = CompletedSession(workoutID: workout.id, title: workout.title, coverID: workout.cover.id,
                                       date: .now, minutes: s.minutes, calories: s.calories, moves: s.moves,
                                       feeling: feeling)
        // A program day counts once most of the main work is done.
        let mainTotal = steps.filter { $0.phase == .main }.count
        let mainDone = completed.filter { steps[$0].phase == .main }.count
        app.log(session, programDayCompleted: programDay != nil && mainDone * 2 >= mainTotal)
        app.applyFeedback(feeling)
        if app.healthOn {
            let start = Date.now.addingTimeInterval(-Double(elapsed))
            Task { await HealthService.shared.saveWorkout(workout, start: start, end: .now, calories: s.calories) }
        }
    }

    // MARK: Exercise screen

    private func exerciseScreen(_ step: SessionStep) -> some View {
        let ex = step.block.exercise
        let onDark = ex.isDarkStage
        return ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        StageMedia(exercise: ex, live: true, isPlaying: !paused,
                                   inset: EdgeInsets(top: 110, leading: 12, bottom: 44, trailing: 12))
                            .id(ex.id)
                            .transition(.opacity)
                            .padding(.bottom, -36)
                            .ignoresSafeArea(edges: .top)
                    }
                    .overlay {
                        if stage == .getReady { getReadyOverlay.padding(.top, -60) }
                    }
                    .contentShape(.rect)
                    .onTapGesture { paused.toggle() }
                controlPanel(step)
            }

            topBar(onDark: onDark)
        }
    }

    private func topBar(onDark: Bool) -> some View {
        let fg: Color = onDark ? .white : Palette.ink
        return VStack(spacing: 12) {
            // Segmented progress, one segment per move
            HStack(spacing: 3) {
                ForEach(steps.indices, id: \.self) { i in
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(fg.opacity(0.18))
                            Capsule().fill(fg)
                                .frame(width: geo.size.width * segmentFill(i))
                        }
                    }
                    .frame(height: 4)
                }
            }
            HStack {
                Button { paused = true; showPauseMenu = true } label: {
                    RoundIcon(symbol: "xmark", size: 40, tint: fg, fill: fg.opacity(0.12))
                }
                Spacer()
                Text(timeString(elapsed))
                    .font(.numeral(15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(fg.opacity(0.7))
                Spacer()
                Button { app.voiceOn.toggle() } label: {
                    RoundIcon(symbol: app.voiceOn ? "speaker.wave.2.fill" : "speaker.slash.fill", size: 40, tint: fg, fill: fg.opacity(0.12))
                        .contentTransition(.symbolEffect(.replace))
                }
                Button { paused = true; guide = step?.block.exercise } label: {
                    RoundIcon(symbol: "info", size: 40, tint: fg, fill: fg.opacity(0.12))
                }
            }
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.top, 6)
    }

    private func segmentFill(_ i: Int) -> CGFloat {
        if i < index { return 1 }
        if i > index || stage != .exercise { return 0 }
        if step?.block.reps != nil { return 0.5 }
        return 1 - CGFloat(remaining) / CGFloat(max(stageLength, 1))
    }

    private var getReadyOverlay: some View {
        VStack(spacing: 14) {
            Text("Get ready")
                .font(.display(24))
                .foregroundStyle(.white)
            Text("\(remaining)")
                .font(.numeral(96, weight: .heavy))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: remaining)
            Button("Start now") { startExercise() }
                .font(.ui(15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 22).frame(height: 44)
                .background(.white, in: .capsule)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ink.opacity(0.3))
    }

    // MARK: Control panel

    private func controlPanel(_ step: SessionStep) -> some View {
        let block = step.block
        let isReps = block.reps != nil
        return VStack(spacing: 18) {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Eyebrow(step.phase == .main && workout.rounds > 1 ? "Round \(step.round) of \(workout.rounds)" : step.phase.rawValue,
                            color: step.phase == .main ? Palette.persimmon : Palette.plum)
                    Text("·").foregroundStyle(Palette.inkFaint)
                    Text("\(index + 1) of \(steps.count)")
                        .font(.ui(11, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                }
                Text(block.exercise.displayName)
                    .font(.display(28))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            // Big readout
            Group {
                if isReps {
                    Text("×\(block.reps!)")
                } else {
                    Text(timeString(remaining))
                        .contentTransition(.numericText(countsDown: true))
                }
            }
            .font(.numeral(72, weight: .heavy))
            .monospacedDigit()
            .foregroundStyle(paused ? Palette.inkFaint : Palette.ink)
            .animation(.snappy, value: remaining)
            .frame(height: 76)

            // Transport
            HStack(spacing: 34) {
                Button { previous() } label: {
                    RoundIcon(symbol: "backward.end.fill", size: 54, fill: Palette.raised)
                }
                .disabled(index == 0)
                .opacity(index == 0 ? 0.4 : 1)

                Button {
                    if isReps { advance() } else { paused.toggle() }
                } label: {
                    ZStack {
                        if !isReps {
                            Circle().stroke(Palette.persimmon.opacity(0.2), lineWidth: 5)
                            Circle()
                                .trim(from: 0, to: 1 - CGFloat(remaining) / CGFloat(max(stageLength, 1)))
                                .stroke(Palette.persimmon, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: remaining)
                        }
                        Circle().fill(isReps ? Palette.persimmon : Palette.ink).padding(9)
                        if isReps {
                            Text("Done").font(.ui(17, weight: .bold)).foregroundStyle(.white)
                        } else {
                            Image(systemName: paused ? "play.fill" : "pause.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Palette.canvas)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .frame(width: 92, height: 92)
                }

                Button { advance() } label: {
                    RoundIcon(symbol: "forward.end.fill", size: 54, fill: Palette.raised)
                }
            }

            // Up next
            if let next = nextStep {
                HStack(spacing: 12) {
                    MoveStage(exercise: next.block.exercise, radius: 10).frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Eyebrow("Up next")
                        Text(next.block.exercise.displayName)
                            .font(.ui(15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                    }
                    Spacer()
                    Text(next.block.target).font(.numeral(15, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                }
                .padding(8)
                .padding(.trailing, 8)
                .background(Palette.surface, in: .rect(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.top, 22)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 36, topTrailingRadius: 36, style: .continuous)
                .fill(Palette.canvas)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

func timeString(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}

// MARK: - Rest

struct RestView: View {
    let next: SessionStep
    let position: Int
    let total: Int
    let remaining: Int
    let length: Int
    var onAdd: () -> Void
    var onSkip: () -> Void
    var onPause: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.plum.ignoresSafeArea()
            Button(action: onPause) {
                RoundIcon(symbol: "xmark", size: 40, tint: .white, fill: .white.opacity(0.12))
            }
            .padding(.leading, Metric.gutter)
            .padding(.top, 8)
            .zIndex(1)
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Eyebrow("Breathe", color: Palette.lilac)
                    Text(timeString(remaining))
                        .font(.numeral(96, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: remaining)
                    // Breathing bubble
                    Capsule()
                        .fill(Palette.lilac.opacity(0.25))
                        .frame(width: 220, height: 6)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Palette.lilac)
                                .frame(width: 220 * CGFloat(remaining) / CGFloat(max(length, 1)), height: 6)
                                .animation(.linear(duration: 1), value: remaining)
                        }
                        .padding(.top, 6)
                }
                .padding(.top, 70)

                HStack(spacing: 12) {
                    Button(action: onAdd) {
                        Label("20s", systemImage: "plus")
                            .font(.ui(16, weight: .semibold))
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .foregroundStyle(.white)
                            .background(.white.opacity(0.12), in: .capsule)
                    }
                    Button(action: onSkip) {
                        Text("Skip rest")
                            .font(.ui(16, weight: .semibold))
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .foregroundStyle(Palette.plum)
                            .background(.white, in: .capsule)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 28)

                Spacer(minLength: 24)

                // Next move preview
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Eyebrow("Up next · \(position) of \(total)", color: Palette.lilac)
                        Spacer()
                        Text(next.block.target).font(.numeral(18)).foregroundStyle(.white)
                    }
                    Text(next.block.exercise.displayName).font(.display(28)).foregroundStyle(.white)
                    MoveStage(exercise: next.block.exercise, live: true, radius: 26)
                    if let tip = next.block.exercise.steps.first {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lightbulb.fill").foregroundStyle(Palette.sun)
                            Text(tip).font(.ui(14)).foregroundStyle(.white.opacity(0.8)).lineLimit(2)
                        }
                    }
                }
                .padding(18)
                .background(.white.opacity(0.08), in: .rect(cornerRadius: 32, style: .continuous))
                .padding(.horizontal, Metric.gutter)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Pause menu

struct PauseMenu: View {
    let workout: Workout
    let step: SessionStep?
    let done: Int
    let total: Int
    var onResume: () -> Void
    var onRestart: () -> Void
    var onCoolDown: () -> Void
    var onFinish: () -> Void
    var onQuit: (QuitReason) -> Void
    @State private var askingWhy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow("Paused")
                Text(askingWhy ? "Mind telling us why?" : "Take a breather.")
                    .font(.display(28)).foregroundStyle(Palette.ink)
                Text(askingWhy ? "We'll use it to tune your next session." : "\(done) of \(total) moves done in \(workout.title).")
                    .font(.ui(15)).foregroundStyle(Palette.inkSoft)
            }
            if askingWhy {
                VStack(spacing: 10) {
                    ForEach(QuitReason.allCases, id: \.self) { reason in
                        Button(reason.title) { onQuit(reason) }.buttonStyle(MenuRowStyle())
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Button(action: onRestart) { Label("Restart this move", systemImage: "arrow.counterclockwise") }
                        .buttonStyle(MenuRowStyle())
                    Button(action: onCoolDown) { Label("Skip to cool-down", systemImage: "wind") }
                        .buttonStyle(MenuRowStyle())
                    Button(action: onFinish) { Label("Finish & save progress", systemImage: "checkmark.circle") }
                        .buttonStyle(MenuRowStyle())
                    Button { withAnimation(.smooth) { askingWhy = true } } label: {
                        Label("End workout", systemImage: "xmark.circle")
                    }
                    .buttonStyle(MenuRowStyle(destructive: true))
                }
            }
            Spacer(minLength: 0)
            Button("Resume", action: onResume).buttonStyle(.accent)
        }
        .padding(Metric.gutter)
        .padding(.top, 12)
        .background(Palette.canvas)
    }
}

enum QuitReason: CaseIterable {
    case tooHard, tooEasy, noTime, browsing
    var title: String {
        switch self {
        case .tooHard: "Too hard right now"
        case .tooEasy: "Too easy"
        case .noTime: "Not enough time"
        case .browsing: "Just looking around"
        }
    }
}

struct SessionSummary {
    let minutes: Int
    let calories: Int
    let moves: Int
}

struct MenuRowStyle: ButtonStyle {
    var destructive = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(16, weight: .semibold))
            .foregroundStyle(destructive ? Color(hex: "D63B1F") : Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(Palette.surface, in: .rect(cornerRadius: 18, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
