//
//  PlanView.swift
//  Home Workout
//
//  The weekly planner: assign workouts to days, manage your own workouts.
//

import SwiftUI

struct PlanView: View {
    @Environment(AppState.self) private var app
    @State private var path = NavigationPath()
    @State private var pickingDay: Int?
    @State private var building = false
    @State private var showPaywall = false
    @State private var weekOffset = 0
    @State private var showPrefs = false

    private var plannedMinutes: Int { app.week.values.reduce(0) { $0 + $1.minutes } }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    summary
                    days
                    myWorkouts
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Palette.canvas)
            .appDestinations()
        }
        .sheet(item: Binding(get: { pickingDay.map(DayRef.init) }, set: { pickingDay = $0?.id })) { ref in
            WorkoutPicker(day: ref.id) { w in
                app.week[ref.id] = w
                app.trainingDays.insert(ref.id)
                pickingDay = nil
            }
        }
        .sheet(isPresented: $building) { WorkoutBuilderView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        #if DEBUG
        .onAppear { if DebugRoute.screen == "builder" { building = true } }
        #endif
        .sheet(isPresented: $showPrefs) { PlanPreferencesView().presentationDetents([.medium, .large]) }
    }

    private struct DayRef: Identifiable { let id: Int }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(weekLabel)
                Text("Your week").font(.display(38)).foregroundStyle(Palette.ink)
            }
            Spacer()
            HStack(spacing: 8) {
                Button { withAnimation(.smooth) { weekOffset -= 1 } } label: { RoundIcon(symbol: "chevron.left", size: 38) }
                Button { withAnimation(.smooth) { weekOffset += 1 } } label: { RoundIcon(symbol: "chevron.right", size: 38) }
                Button { showPrefs = true } label: { RoundIcon(symbol: "slider.horizontal.3", size: 38) }
            }
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.top, 8)
    }

    private var weekStart: Date {
        let cal = Calendar.current
        let thisMonday = cal.date(byAdding: .day, value: -app.todayIndex, to: cal.startOfDay(for: .now))!
        return cal.date(byAdding: .weekOfYear, value: weekOffset, to: thisMonday)!
    }

    private var weekLabel: String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: weekStart)!
        let prefix = weekOffset == 0 ? "This week · " : weekOffset == 1 ? "Next week · " : weekOffset == -1 ? "Last week · " : ""
        return prefix + "\(weekStart.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.day()))"
    }

    // MARK: Summary

    private var summary: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(app.week.count)", label: "sessions", symbol: "calendar", tint: Palette.persimmon)
            StatTile(value: "\(plannedMinutes)", label: "minutes", symbol: "clock.fill", tint: Palette.sky)
            StatTile(value: "\(7 - app.week.count)", label: "rest days", symbol: "moon.fill", tint: Palette.lilac)
        }
        .padding(.horizontal, Metric.gutter)
    }

    // MARK: Days

    private var days: some View {
        let cal = Calendar.current
        return VStack(spacing: 10) {
            ForEach(0..<7, id: \.self) { i in
                let date = cal.date(byAdding: .day, value: i, to: weekStart)!
                let isToday = cal.isDateInToday(date)
                let done = app.didWorkout(on: date)
                HStack(alignment: .center, spacing: 14) {
                    VStack(spacing: 2) {
                        Text(Weekday.all[i].name.uppercased())
                            .font(.ui(11, weight: .bold)).tracking(0.8)
                            .foregroundStyle(isToday ? Palette.persimmon : Palette.inkSoft)
                        Text("\(cal.component(.day, from: date))")
                            .font(.numeral(22))
                            .foregroundStyle(Palette.ink)
                    }
                    .frame(width: 46)

                    if let w = app.week[i] {
                        Button { path.append(w) } label: {
                            HStack(spacing: 12) {
                                MoveStage(exercise: w.cover, radius: 14).frame(width: 56, height: 56)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(w.title).font(.ui(16, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                                    HStack(spacing: 6) {
                                        Circle().fill(w.style.tint).frame(width: 7, height: 7)
                                        Text("\(w.minutes) min · \(w.style.title)").font(.ui(13)).foregroundStyle(Palette.inkSoft)
                                    }
                                }
                                Spacer(minLength: 0)
                                if done {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22)).foregroundStyle(Palette.mint)
                                } else {
                                    Menu {
                                        Button("Swap workout", systemImage: "arrow.left.arrow.right") { pickingDay = i }
                                        Button("Make it a rest day", systemImage: "moon", role: .destructive) {
                                            withAnimation(.smooth) {
                                                app.week[i] = nil
                                                app.trainingDays.remove(i)
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Palette.inkSoft)
                                            .frame(width: 36, height: 36)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Palette.surface, in: .rect(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(isToday ? Palette.persimmon : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { pickingDay = i } label: {
                            HStack {
                                Text(done ? "Bonus session done" : "Rest day")
                                    .font(.ui(15, weight: .medium))
                                    .foregroundStyle(Palette.inkFaint)
                                Spacer()
                                Label("Add", systemImage: "plus")
                                    .font(.ui(14, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                    .padding(.horizontal, 12).frame(height: 32)
                                    .background(Palette.surface, in: .capsule)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 72)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Palette.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, Metric.gutter)
        .animation(.smooth, value: app.week.count)
    }

    // MARK: My workouts

    private var myWorkouts: some View {
        let favorites = Catalog.workouts.filter { app.favorites.contains($0.id) }
        let canBuild = app.isPro || app.customWorkouts.isEmpty
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "My workouts")
            Button { if canBuild { building = true } else { showPaywall = true } } label: {
                HStack(spacing: 14) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Palette.persimmon, in: .rect(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Build your own").font(.display(19)).foregroundStyle(Palette.ink)
                        Text(canBuild ? "Pick moves, set the timing, save it." : "Unlimited custom workouts with Plus")
                            .font(.ui(13)).foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                }
                .padding(10)
                .cardBackground(Palette.persimmonSoft, radius: Metric.tileRadius)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Metric.gutter)

            VStack(spacing: 10) {
                ForEach(app.customWorkouts + favorites) { w in
                    NavigationLink(value: w) { WorkoutRow(workout: w) }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metric.gutter)
        }
    }
}

// MARK: - Picker

struct WorkoutPicker: View {
    let day: Int
    var onPick: (Workout) -> Void
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var style: WorkoutStyle?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            Button { style = nil } label: { Chip(title: "All", selected: style == nil) }
                            ForEach(WorkoutStyle.allCases, id: \.self) { s in
                                Button { style = s } label: { Chip(title: s.title, selected: style == s) }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Metric.gutter)
                    }
                    .scrollIndicators(.hidden)
                    VStack(spacing: 10) {
                        ForEach((app.customWorkouts + Catalog.workouts).filter { style == nil || $0.style == style }) { w in
                            Button { onPick(w) } label: { WorkoutRow(workout: w) }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Metric.gutter)
                }
                .padding(.vertical, 8)
            }
            .background(Palette.canvas)
            .navigationTitle("Plan \(Weekday.all[day].name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
            }
        }
    }
}

// MARK: - Preferences

struct PlanPreferencesView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            Form {
                Section("Workout days") {
                    HStack(spacing: 6) {
                        ForEach(Weekday.all) { d in
                            let on = app.trainingDays.contains(d.index)
                            Button {
                                if on { app.trainingDays.remove(d.index) } else { app.trainingDays.insert(d.index) }
                                app.syncWeekToTrainingDays()
                            } label: {
                                Text(d.short).font(.ui(15, weight: .bold))
                                    .foregroundStyle(on ? .white : Palette.ink)
                                    .frame(maxWidth: .infinity).frame(height: 40)
                                    .background(on ? Palette.persimmon : Palette.raised, in: .rect(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section("Sessions") {
                    Picker("Length", selection: $app.sessionMinutes) {
                        ForEach([5, 10, 15, 20, 30], id: \.self) { Text("\($0) min") }
                    }
                    Picker("Difficulty", selection: $app.level) {
                        ForEach(Level.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Quiet mode (no jumping)", isOn: $app.quietMode)
                }
                Section("Reminders") {
                    Toggle("Workout reminders", isOn: $app.remindersOn)
                    if app.remindersOn {
                        DatePicker("Remind me at", selection: $app.reminder, displayedComponents: .hourAndMinute)
                    }
                }
                Section {
                    Button("Rebuild my week") { app.generateWeek() }
                } footer: {
                    Text("Fills your workout days with fresh picks based on your goal, focus and session length.")
                }
            }
            .tint(Palette.persimmon)
            .scrollContentBackground(.hidden)
            .background(Palette.canvas)
            .navigationTitle("Plan settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() } }
            }
        }
    }
}
