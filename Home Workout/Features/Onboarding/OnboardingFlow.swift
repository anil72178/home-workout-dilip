//
//  OnboardingFlow.swift
//  Home Workout
//
//  Welcome → six short questions → plan reveal → optional Plus offer.
//

import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome, name, goal, focus, level, rhythm, home, building, reveal
    static let questions: [OnboardingStep] = [.name, .goal, .focus, .level, .rhythm, .home]
}

struct OnboardingFlow: View {
    @Environment(AppState.self) private var app
    @State private var step: OnboardingStep = {
        #if DEBUG
        return DebugRoute.onboardingStep ?? .welcome
        #else
        return .welcome
        #endif
    }()
    @State private var forward = true
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            switch step {
            case .welcome:
                WelcomeView { go(.name) }
                    .transition(.opacity)
            case .building:
                BuildingPlanView { go(.reveal) }
                    .transition(.opacity)
            case .reveal:
                PlanRevealView { showPaywall = true }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            default:
                questionScaffold
            }
        }
        .sheet(isPresented: $showPaywall, onDismiss: { app.hasOnboarded = true }) {
            PaywallView()
        }
    }

    private var questionScaffold: some View {
        let index = OnboardingStep.questions.firstIndex(of: step) ?? 0
        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { back() } label: { RoundIcon(symbol: "chevron.left", size: 40) }
                HStack(spacing: 5) {
                    ForEach(0..<OnboardingStep.questions.count, id: \.self) { i in
                        Capsule()
                            .fill(i <= index ? Palette.persimmon : Palette.hairline)
                            .frame(height: 5)
                    }
                }
                Text("\(index + 1)/\(OnboardingStep.questions.count)")
                    .font(.numeral(14, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .monospacedDigit()
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 8)
            .animation(.smooth, value: step)

            ZStack {
                question(step)
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
            }
            .frame(maxHeight: .infinity, alignment: .top)

            Button(step == .home ? "Build my plan" : "Continue") { next() }
                .buttonStyle(.primary)
                .padding(.horizontal, Metric.gutter)
                .padding(.bottom, 8)
                .disabled(step == .name && app.name.trimmingCharacters(in: .whitespaces).isEmpty
                          || step == .rhythm && app.trainingDays.isEmpty
                          || step == .focus && app.focus.isEmpty)
                .opacity(canContinue ? 1 : 0.4)
        }
    }

    @ViewBuilder private func question(_ step: OnboardingStep) -> some View {
        switch step {
        case .name: NameQuestion()
        case .goal: GoalQuestion()
        case .focus: FocusQuestion()
        case .level: LevelQuestion()
        case .rhythm: RhythmQuestion()
        case .home: HomeSetupQuestion()
        default: EmptyView()
        }
    }

    private func next() {
        if step == .home && app.remindersOn {
            Task { await Reminders.shared.requestAuthorization() }
        }
        let all = OnboardingStep.allCases
        guard let i = all.firstIndex(of: step), i + 1 < all.count else { return }
        go(all[i + 1])
    }

    private var canContinue: Bool {
        !(step == .name && app.name.trimmingCharacters(in: .whitespaces).isEmpty
          || step == .rhythm && app.trainingDays.isEmpty
          || step == .focus && app.focus.isEmpty)
    }

    private func back() {
        let all = OnboardingStep.allCases
        guard let i = all.firstIndex(of: step), i > 0 else { return }
        forward = false
        withAnimation(.smooth(duration: 0.4)) { step = all[i - 1] }
    }

    private func go(_ s: OnboardingStep) {
        forward = true
        withAnimation(.smooth(duration: 0.4)) { step = s }
    }
}

// MARK: - Shared question layout

struct QuestionHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.display(32))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.ui(16))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metric.gutter)
        .padding(.top, 28)
        .padding(.bottom, 24)
    }
}

/// Large selectable option card.
struct OptionCard<Leading: View>: View {
    let title: String
    var detail: String? = nil
    let selected: Bool
    @ViewBuilder var leading: Leading

    var body: some View {
        HStack(spacing: 14) {
            leading
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.ui(17, weight: .semibold)).foregroundStyle(Palette.ink)
                if let detail {
                    Text(detail).font(.ui(14)).foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().strokeBorder(selected ? Palette.persimmon : Palette.hairline, lineWidth: 2)
                if selected {
                    Circle().fill(Palette.persimmon).padding(5)
                }
            }
            .frame(width: 24, height: 24)
        }
        .padding(16)
        .background(Palette.surface, in: .rect(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(selected ? Palette.persimmon : .clear, lineWidth: 2)
        )
        .animation(.snappy(duration: 0.2), value: selected)
    }
}

// MARK: - Questions

private struct NameQuestion: View {
    @Environment(AppState.self) private var app
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var app = app
        VStack(alignment: .leading, spacing: 0) {
            QuestionHeader(title: "First things first —\nwhat should we call you?",
                           subtitle: "Your coach will cheer you on by name.")
            TextField("Your name", text: $app.name)
                .onSubmit { if !app.name.isEmpty { focused = false } }
                .font(.display(34, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .textInputAutocapitalization(.words)
                .submitLabel(.continue)
                .focused($focused)
                .padding(.horizontal, Metric.gutter)
            Rectangle().fill(Palette.persimmon).frame(height: 2)
                .padding(.horizontal, Metric.gutter)
                .padding(.top, 8)
        }
        .onAppear { focused = true }
    }
}

private struct GoalQuestion: View {
    @Environment(AppState.self) private var app
    var body: some View {
        VStack(spacing: 0) {
            QuestionHeader(title: "What would feel like a win, \(app.displayName)?",
                           subtitle: "Pick the one that matters most right now.")
            VStack(spacing: 12) {
                ForEach(Goal.allCases) { goal in
                    Button { app.goal = goal } label: {
                        OptionCard(title: goal.title, detail: goal.detail, selected: app.goal == goal) {
                            Image(systemName: goal.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                                .frame(width: 46, height: 46)
                                .background(goal.tint.opacity(0.35), in: .rect(cornerRadius: 14))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metric.gutter)
        }
    }
}

private struct FocusQuestion: View {
    @Environment(AppState.self) private var app
    var body: some View {
        VStack(spacing: 0) {
            QuestionHeader(title: "Where do you want to feel it?",
                           subtitle: "Choose as many as you like.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(BodyRegion.allCases) { region in
                    let on = app.focus.contains(region)
                    Button {
                        if on { app.focus.remove(region) } else { app.focus.insert(region) }
                    } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            if let ex = sample(for: region) {
                                MoveStage(exercise: ex, radius: 18)
                            }
                            HStack {
                                Text(region.title).font(.ui(15, weight: .semibold))
                                Spacer()
                                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(on ? Palette.persimmon : Palette.hairline)
                            }
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 6)
                            .padding(.top, 10)
                        }
                        .padding(8)
                        .padding(.bottom, 4)
                        .background(Palette.surface, in: .rect(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(on ? Palette.persimmon : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .animation(.snappy(duration: 0.2), value: on)
                }
            }
            .padding(.horizontal, Metric.gutter)
        }
    }

    private func sample(for region: BodyRegion) -> Exercise? {
        switch region {
        case .full: Catalog.move("Burpee")
        case .core: Catalog.move("Plank")
        case .upper: Catalog.move("Push-up")
        case .lower: Catalog.move("Glute Bridge")
        }
    }
}

private struct LevelQuestion: View {
    @Environment(AppState.self) private var app

    private let options: [(Level, String, String, String)] = [
        (.beginner, "Just getting started", "Knee push-ups feel like plenty", "Knee Push-ups"),
        (.intermediate, "I move regularly", "A set of 10 push-ups is doable", "Push-up"),
        (.advanced, "Bring on the challenge", "Explosive push-ups? Sure.", "Plyometric Push-ups"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            QuestionHeader(title: "How does this feel today?",
                           subtitle: "No wrong answers — we'll adjust as you go.")
            let current = options.first { $0.0 == app.level } ?? options[0]
            if let ex = Catalog.move(current.3) {
                MoveStage(exercise: ex, live: true, radius: 28)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .background(ex.stageColor, in: .rect(cornerRadius: 28, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        Tag(title: ex.displayName, tint: Palette.persimmon).padding(12)
                    }
                    .padding(.horizontal, Metric.gutter)
                    .padding(.bottom, 16)
                    .animation(.smooth, value: app.level)
            }
            VStack(spacing: 10) {
                ForEach(options, id: \.0) { level, title, detail, _ in
                    Button { app.level = level } label: {
                        OptionCard(title: title, detail: detail, selected: app.level == level) {
                            LevelBars(level: level, tint: Palette.persimmon)
                                .frame(width: 30)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metric.gutter)
        }
    }
}

private struct RhythmQuestion: View {
    @Environment(AppState.self) private var app
    private let lengths = [5, 10, 15, 20, 30]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuestionHeader(title: "Let's find your rhythm.",
                           subtitle: "Which days work, and for how long?")
            Eyebrow("Workout days").padding(.horizontal, Metric.gutter)
            HStack(spacing: 8) {
                ForEach(Weekday.all) { day in
                    let on = app.trainingDays.contains(day.index)
                    Button {
                        if on { app.trainingDays.remove(day.index) } else { app.trainingDays.insert(day.index) }
                    } label: {
                        Text(day.short)
                            .font(.ui(16, weight: .bold))
                            .foregroundStyle(on ? .white : Palette.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(on ? Palette.persimmon : Palette.surface, in: .rect(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .animation(.snappy(duration: 0.2), value: on)
                }
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 12)

            Text(daysCopy)
                .font(.ui(14))
                .foregroundStyle(Palette.inkSoft)
                .padding(.horizontal, Metric.gutter)
                .padding(.top, 10)
                .contentTransition(.opacity)

            Eyebrow("Session length").padding(.horizontal, Metric.gutter).padding(.top, 32)
            HStack(spacing: 8) {
                ForEach(lengths, id: \.self) { m in
                    let on = app.sessionMinutes == m
                    Button { app.sessionMinutes = m } label: {
                        VStack(spacing: 0) {
                            Text("\(m)").font(.numeral(24))
                            Text("min").font(.ui(12, weight: .medium)).opacity(0.7)
                        }
                        .foregroundStyle(on ? Palette.canvas : Palette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 76)
                        .background(on ? Palette.ink : Palette.surface, in: .rect(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .animation(.snappy(duration: 0.2), value: on)
                }
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 12)
        }
    }

    private var daysCopy: String {
        switch app.trainingDays.count {
        case 0: "Pick at least one day."
        case 1...2: "A gentle start. Consistency beats intensity."
        case 3...4: "The sweet spot for steady progress."
        default: "Ambitious! We'll mix in lighter recovery days."
        }
    }
}

private struct HomeSetupQuestion: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        VStack(alignment: .leading, spacing: 0) {
            QuestionHeader(title: "Tell us about your space.",
                           subtitle: "We'll fit workouts to your home, not the other way round.")
            VStack(spacing: 12) {
                Toggle(isOn: $app.quietMode) {
                    HStack(spacing: 14) {
                        Image(systemName: "speaker.slash.fill")
                            .frame(width: 46, height: 46)
                            .background(Palette.lilac.opacity(0.35), in: .rect(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Quiet mode").font(.ui(17, weight: .semibold))
                            Text("No jumping, no thuds").font(.ui(14)).foregroundStyle(Palette.inkSoft)
                        }
                    }
                    .foregroundStyle(Palette.ink)
                }
                .tint(Palette.persimmon)
                .padding(16)
                .cardBackground(radius: 22)

                VStack(spacing: 0) {
                    Toggle(isOn: $app.remindersOn.animation(.smooth)) {
                        HStack(spacing: 14) {
                            Image(systemName: "bell.fill")
                                .frame(width: 46, height: 46)
                                .background(Palette.sun.opacity(0.4), in: .rect(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Workout reminders").font(.ui(17, weight: .semibold))
                                Text("A nudge on your workout days").font(.ui(14)).foregroundStyle(Palette.inkSoft)
                            }
                        }
                        .foregroundStyle(Palette.ink)
                    }
                    .tint(Palette.persimmon)
                    if app.remindersOn {
                        Divider().overlay(Palette.hairline).padding(.vertical, 12)
                        HStack {
                            Text("Remind me at").font(.ui(15, weight: .medium)).foregroundStyle(Palette.inkSoft)
                            Spacer()
                            DatePicker("", selection: $app.reminder, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                }
                .padding(16)
                .cardBackground(radius: 22)

                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.mint)
                    Text("Every move uses just your body and a bit of floor. A mat is nice, a towel works too.")
                        .font(.ui(14))
                        .foregroundStyle(Palette.inkSoft)
                }
                .padding(.top, 8)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, Metric.gutter)
        }
    }
}
