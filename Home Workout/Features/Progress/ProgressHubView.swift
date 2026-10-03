//
//  ProgressHubView.swift
//  Home Workout
//

import SwiftUI
import Charts
import StoreKit

struct ProgressHubView: View {
    @Environment(AppState.self) private var app
    @State private var showSettings = false
    @State private var logWeight = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .bottom) {
                        Text("Progress").font(.display(38)).foregroundStyle(Palette.ink)
                        Spacer()
                        Button { showSettings = true } label: { RoundIcon(symbol: "gearshape.fill", size: 40) }
                            .accessibilityLabel("Settings")
                    }
                    .padding(.top, 8)

                    streakCard
                    HStack(spacing: 10) {
                        StatTile(value: "\(app.history.count)", label: plural(app.history.count, "workout"), symbol: "checkmark.seal.fill", tint: Palette.persimmon)
                        StatTile(value: "\(app.totalMinutes)", label: plural(app.totalMinutes, "minute"), symbol: "clock.fill", tint: Palette.sky)
                        StatTile(value: "\(app.totalCalories)", label: "kcal", symbol: "flame.fill", tint: Palette.sun)
                    }
                    if app.history.isEmpty { emptyState } else { minutesChart }
                    weightCard
                    milestones
                    if !app.history.isEmpty { history }
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Palette.canvas)
            .appDestinations()
            .navigationDestination(for: HistoryRoute.self) { _ in HistoryView() }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        #if DEBUG
        .onAppear { if DebugRoute.screen == "settings" { showSettings = true } }
        #endif
        .sheet(isPresented: $logWeight) { LogWeightSheet().presentationDetents([.height(340)]) }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Palette.persimmon)
                .frame(width: 64, height: 64)
                .background(Palette.persimmonSoft, in: .circle)
            Text("Your story starts here").font(.display(22)).foregroundStyle(Palette.ink)
            Text("Finish your first workout and your minutes, streak and milestones will show up here.")
                .font(.ui(15)).foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cardBackground()
    }

    // MARK: Streak

    private var streakCard: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let start = cal.date(byAdding: .day, value: -(28 + app.todayIndex), to: today)!
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(app.streak)").font(.numeral(56, weight: .heavy)).foregroundStyle(.white)
                            .contentTransition(.numericText())
                        Text(app.streak == 1 ? "day" : "days").font(.display(22)).foregroundStyle(.white)
                    }
                    Text(app.streak == 0 ? "Work out today to start a streak" : "Current streak · best \(app.bestStreak) \(plural(app.bestStreak, "day"))")
                        .font(.ui(14)).foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(app.streak > 0 ? Palette.sun : .white.opacity(0.25))
            }
            // Five-week activity grid
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(Weekday.all) { d in
                        Text(d.short).font(.ui(11, weight: .bold)).foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity)
                    }
                }
                ForEach(0..<5, id: \.self) { w in
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { d in
                            let date = cal.date(byAdding: .day, value: w * 7 + d, to: start)!
                            let done = app.didWorkout(on: date)
                            let future = date > today
                            let isToday = cal.isDate(date, inSameDayAs: today)
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(done ? Palette.persimmon : .white.opacity(future ? 0.04 : 0.1))
                                .frame(height: 30)
                                .overlay {
                                    if isToday {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white, lineWidth: 2)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(20)
        .cardBackground(Palette.plum)
    }

    // MARK: Minutes chart

    private var minutesChart: some View {
        let cal = Calendar.current
        let data: [(String, Int)] = (0..<6).reversed().map { back in
            let start = cal.date(byAdding: .weekOfYear, value: -back, to: cal.dateInterval(of: .weekOfYear, for: .now)!.start)!
            let end = cal.date(byAdding: .weekOfYear, value: 1, to: start)!
            let mins = app.history.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.minutes }
            return (back == 0 ? "This wk" : start.formatted(.dateTime.month(.abbreviated).day()), mins)
        }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Active minutes").font(.display(22)).foregroundStyle(Palette.ink)
                Spacer()
                Text("6 weeks").font(.ui(13, weight: .medium)).foregroundStyle(Palette.inkSoft)
            }
            Chart(data, id: \.0) { label, mins in
                BarMark(x: .value("Week", label), y: .value("Minutes", mins), width: .ratio(0.55))
                    .foregroundStyle(label == "This wk" ? Palette.persimmon : Palette.ink.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 8))
                    .annotation(position: .top) {
                        if mins > 0 { Text("\(mins)").font(.numeral(11, weight: .semibold)).foregroundStyle(Palette.inkSoft) }
                    }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().font(.ui(11)).foregroundStyle(Palette.inkSoft) }
            }
            .frame(height: 160)
        }
        .padding(18)
        .cardBackground()
    }

    // MARK: Weight

    private var weightCard: some View {
        let values = app.weights.map(\.kg)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow("Body weight")
                    if let last = values.last {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", last)).font(.numeral(30)).foregroundStyle(Palette.ink)
                            Text("kg").font(.ui(15, weight: .medium)).foregroundStyle(Palette.inkSoft)
                            if values.count > 1 {
                                Text(String(format: "%+.1f", last - values[0]))
                                    .font(.numeral(13, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                    .padding(.horizontal, 8).frame(height: 22)
                                    .background(Palette.mint.opacity(0.4), in: .capsule)
                                    .padding(.leading, 6)
                            }
                        }
                    } else {
                        Text("Not logged yet").font(.display(22)).foregroundStyle(Palette.ink)
                        Text("Helps us estimate calories more accurately.").font(.ui(13)).foregroundStyle(Palette.inkSoft)
                    }
                }
                Spacer()
                Button { logWeight = true } label: { Label("Log", systemImage: "plus") }
                    .buttonStyle(.soft)
            }
            if values.count > 1 {
                Chart(Array(values.enumerated()), id: \.offset) { i, kg in
                    LineMark(x: .value("Entry", i), y: .value("kg", kg))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Palette.persimmon)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    AreaMark(x: .value("Entry", i), yStart: .value("min", (values.min() ?? 0) - 0.5), yEnd: .value("kg", kg))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [Palette.persimmon.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                    if i == values.count - 1 {
                        PointMark(x: .value("Entry", i), y: .value("kg", kg)).foregroundStyle(Palette.persimmon).symbolSize(80)
                    }
                }
                .chartYScale(domain: ((values.min() ?? 0) - 0.5)...((values.max() ?? 1) + 0.5))
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 90)
            }
        }
        .padding(18)
        .cardBackground()
    }

    // MARK: Milestones

    private var milestones: some View {
        let programDone = app.activeProgram.map { app.programDay > $0.totalDays } ?? false
        let items: [(String, String, Color, Bool)] = [
            ("First sweat", "figure.walk", Palette.persimmon, app.history.count >= 1),
            ("3-day streak", "flame.fill", Palette.sun, app.bestStreak >= 3),
            ("10 workouts", "10.circle.fill", Palette.sky, app.history.count >= 10),
            ("100 minutes", "clock.fill", Palette.mint, app.totalMinutes >= 100),
            ("7-day streak", "bolt.fill", Palette.lilac, app.bestStreak >= 7),
            ("Program done", "trophy.fill", Palette.blush, programDone),
        ]
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Milestones").font(.display(22)).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(items.filter(\.3).count) of \(items.count)").font(.ui(13, weight: .medium)).foregroundStyle(Palette.inkSoft)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(items, id: \.0) { title, symbol, tint, earned in
                    VStack(spacing: 10) {
                        Image(systemName: earned ? symbol : "lock.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(earned ? Palette.ink : Palette.inkFaint)
                            .frame(width: 58, height: 58)
                            .background(earned ? tint : Palette.raised, in: .circle)
                            .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: earned ? 3 : 0).padding(4))
                        Text(title).font(.ui(12, weight: .semibold))
                            .foregroundStyle(earned ? Palette.ink : Palette.inkFaint)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .cardBackground(radius: 20)
                }
            }
        }
    }

    // MARK: History

    private var history: some View {
        let recent = Array(app.history.prefix(5))
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent sessions").font(.display(22)).foregroundStyle(Palette.ink)
                Spacer()
                if app.history.count > recent.count {
                    NavigationLink("See all", value: HistoryRoute())
                        .font(.ui(14, weight: .semibold))
                        .foregroundStyle(Palette.persimmon)
                }
            }
            VStack(spacing: 0) {
                ForEach(recent) { s in
                    SessionRow(session: s)
                    if s.id != recent.last?.id { Divider().overlay(Palette.hairline) }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .cardBackground()
        }
    }
}

struct HistoryRoute: Hashable {}

/// One logged session; opens the workout when it still exists.
struct SessionRow: View {
    let session: CompletedSession
    @Environment(AppState.self) private var app

    var body: some View {
        let row = HStack(spacing: 12) {
            if let cover = session.cover {
                MoveStage(exercise: cover, radius: 12).frame(width: 46, height: 46)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title).font(.ui(15, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                Text("\(session.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) · \(session.calories) kcal")
                    .font(.ui(12)).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            Text("\(session.minutes) min").font(.numeral(15, weight: .semibold)).foregroundStyle(Palette.ink)
            Image(systemName: ["tortoise.fill", "hand.thumbsup.fill", "flame.fill"][min(max(session.feeling, 0), 2)])
                .font(.system(size: 13))
                .foregroundStyle(Palette.inkSoft)
                .frame(width: 22)
        }
        .padding(.vertical, 10)

        if let workout = app.workout(id: session.workoutID) {
            NavigationLink(value: workout) { row }.buttonStyle(.plain)
        } else {
            row
        }
    }
}

// MARK: - Full history

struct HistoryView: View {
    @Environment(AppState.self) private var app

    private var months: [(String, [CompletedSession])] {
        let groups = Dictionary(grouping: app.history) { $0.date.formatted(.dateTime.month(.wide).year()) }
        return groups.map { ($0.key, $0.value.sorted { $0.date > $1.date }) }
            .sorted { ($0.1.first?.date ?? .distantPast) > ($1.1.first?.date ?? .distantPast) }
    }

    var body: some View {
        List {
            ForEach(months, id: \.0) { month, sessions in
                Section {
                    ForEach(sessions) { SessionRow(session: $0) }
                        .onDelete { offsets in
                            let ids = offsets.map { sessions[$0].id }
                            app.history.removeAll { ids.contains($0.id) }
                        }
                } header: {
                    Text("\(month) · \(sessions.count) sessions")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.canvas)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Log weight

struct LogWeightSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var kg = 70.0

    var body: some View {
        VStack(spacing: 22) {
            Text("Log today's weight").font(.display(24)).foregroundStyle(Palette.ink)
            HStack(spacing: 24) {
                Button { kg = max(25, kg - 0.1) } label: { RoundIcon(symbol: "minus", size: 52, fill: Palette.raised) }
                    .buttonRepeatBehavior(.enabled)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", kg)).font(.numeral(56, weight: .heavy)).foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                        .monospacedDigit()
                    Text("kg").font(.ui(18, weight: .medium)).foregroundStyle(Palette.inkSoft)
                }
                .frame(minWidth: 170)
                Button { kg = min(300, kg + 0.1) } label: { RoundIcon(symbol: "plus", size: 52, fill: Palette.raised) }
                    .buttonRepeatBehavior(.enabled)
            }
            .animation(.snappy, value: kg)
            Button("Save") { app.logWeight(kg); dismiss() }
                .buttonStyle(.accent)
        }
        .padding(Metric.gutter)
        .padding(.top, 10)
        .frame(maxHeight: .infinity)
        .background(Palette.canvas)
        .task {
            if let last = app.latestWeight {
                kg = last
            } else if app.healthOn, let fromHealth = await HealthService.shared.latestWeight() {
                kg = (fromHealth * 10).rounded() / 10
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showPaywall = false
    @State private var showPlan = false
    @State private var manageSubscription = false
    @State private var notificationsDenied = false
    @State private var confirmReset = false
    @State private var restoring = false

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Text(String(app.displayName.prefix(1)).uppercased())
                            .font(.display(24)).foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Palette.persimmon, in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            TextField("Your name", text: $app.name).font(.ui(18, weight: .semibold))
                            Text(app.goal.title).font(.ui(14)).foregroundStyle(Palette.inkSoft)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Mova Plus") {
                    if app.isPro {
                        Label("Plus is active", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Palette.ink)
                        Button("Manage subscription") { manageSubscription = true }
                    } else {
                        Button { showPaywall = true } label: {
                            HStack {
                                ProBadge()
                                Text("Unlock everything with Plus").font(.ui(15, weight: .semibold)).foregroundStyle(Palette.ink)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Palette.inkFaint)
                            }
                        }
                    }
                    Button(restoring ? "Restoring…" : "Restore purchases") {
                        restoring = true
                        Task { await store.restore(); restoring = false }
                    }
                    if let error = store.errorMessage, !app.isPro {
                        Text(error).font(.ui(13)).foregroundStyle(Palette.inkSoft)
                    }
                }

                Section("Workout") {
                    Picker("Goal", selection: $app.goal) { ForEach(Goal.allCases) { Text($0.title).tag($0) } }
                    Picker("Difficulty", selection: $app.level) { ForEach(Level.allCases) { Text($0.title).tag($0) } }
                    Toggle("Quiet mode (no jumping)", isOn: $app.quietMode)
                    Button("Workout days & session length") { showPlan = true }
                    LabeledContent("Adaptive intensity", value: intensityLabel)
                }

                Section {
                    Toggle("Voice coach", isOn: $app.voiceOn)
                    Toggle("Countdown beeps", isOn: $app.soundsOn)
                    Toggle("Workout reminders", isOn: $app.remindersOn)
                    if app.remindersOn {
                        DatePicker("Remind me at", selection: $app.reminder, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Coaching")
                } footer: {
                    if notificationsDenied && app.remindersOn {
                        Button("Notifications are off for Mova. Turn them on in Settings.") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                        .font(.ui(13))
                    }
                }

                Section {
                    Toggle("Save workouts to Apple Health", isOn: $app.healthOn)
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Finished workouts, calories and logged weight are saved to Health.")
                }

                Section {
                    Button("Replay onboarding") { dismiss(); app.hasOnboarded = false }
                    Link("Help & feedback", destination: Brand.supportURL)
                    Link("Privacy policy", destination: Brand.privacyURL)
                    Button("Erase all my data", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Mova \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                }

                #if DEBUG
                Section("Developer") {
                    Button("Load sample history") { app.loadDemoHistory() }
                }
                #endif
            }
            .tint(Palette.persimmon)
            .scrollContentBackground(.hidden)
            .background(Palette.canvas)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() } }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showPlan) { PlanPreferencesView().presentationDetents([.medium, .large]) }
            .manageSubscriptionsSheet(isPresented: $manageSubscription)
            .confirmationDialog("Erase all data?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Erase everything", role: .destructive) {
                    dismiss()
                    app.resetEverything()
                }
            } message: {
                Text("Your profile, plan, history and custom workouts will be deleted from this iPhone. Your subscription isn't affected.")
            }
            .onChange(of: app.remindersOn) { _, on in
                guard on else { return }
                Task { notificationsDenied = !(await Reminders.shared.requestAuthorization()) }
            }
            .onChange(of: app.healthOn) { _, on in
                guard on else { return }
                Task { if !(await HealthService.shared.requestAuthorization()) { app.healthOn = false } }
            }
            .task {
                if app.remindersOn { notificationsDenied = !(await Reminders.shared.isAuthorized) }
            }
        }
    }

    private var intensityLabel: String {
        switch app.intensity {
        case ..<(-1): "Much lighter"
        case -1: "A bit lighter"
        case 0: "Standard"
        case 1: "A bit harder"
        default: "Much harder"
        }
    }
}
