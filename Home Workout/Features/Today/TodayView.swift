//
//  TodayView.swift
//  Home Workout
//

import SwiftUI

struct TodayView: View {
    var selectTab: (AppTab) -> Void = { _ in }
    @Environment(AppState.self) private var app
    @State private var path = NavigationPath()
    @State private var playing: Workout?
    @State private var debugPaywall = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    WeekStrip()
                    todayHero
                    if let program = app.activeProgram { programCard(program) }
                    quickHits
                    picks
                    weeklyGoal
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Palette.canvas)
            .appDestinations()
        }
        .fullScreenCover(item: $playing) { PlayerView(workout: $0, options: SessionOptions(quiet: app.quietMode)) }
        .sheet(isPresented: $debugPaywall) { PaywallView() }
        #if DEBUG
        .onAppear {
            switch DebugRoute.screen {
            case "detail": path.append(Catalog.livingRoomSweat)
            case "program": path.append(Catalog.programs[0])
            case "exercise": if let e = Catalog.move("Glute Bridge") { path.append(e) }
            case "player", "rest", "done": playing = Catalog.livingRoomSweat
            case "paywall": debugPaywall = true
            default: break
            }
        }
        #endif
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                Text("\(greeting),\n\(app.displayName).")
                    .font(.display(34))
                    .foregroundStyle(Palette.ink)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").foregroundStyle(Palette.persimmon)
                Text("\(app.streak)").font(.numeral(17)).foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Palette.surface, in: .capsule)
            .onTapGesture { selectTab(.progress) }
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.top, 8)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    // MARK: Today

    @ViewBuilder private var todayHero: some View {
        let doneToday = app.didWorkout(on: .now)
        if let workout = app.todaysWorkout {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    MoveCover(exercise: workout.cover, live: true)
                        .frame(height: 300)
                    HStack {
                        Tag(title: doneToday ? "Done today" : "Today's session", tint: doneToday ? Palette.mint : Palette.persimmon)
                        Spacer()
                        Tag(title: workout.style.title, tint: workout.style.tint)
                    }
                    .padding(16)
                }
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(workout.title).font(.display(28)).foregroundStyle(Palette.ink)
                        Text(workout.subtitle).font(.ui(15)).foregroundStyle(Palette.inkSoft)
                        MetaLine(workout: workout).padding(.top, 4)
                    }
                    Spacer(minLength: 12)
                    Button {
                        if workout.isPro && !app.isPro { path.append(workout) } else { playing = workout }
                    } label: {
                        Image(systemName: doneToday ? "arrow.counterclockwise" : "play.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 68, height: 68)
                            .background(Palette.persimmon, in: .circle)
                            .shadow(color: Palette.persimmon.opacity(0.4), radius: 14, y: 6)
                    }
                    .offset(y: -4)
                }
                .padding(20)
            }
            .cardBackground()
            .clipShape(.rect(cornerRadius: Metric.cardRadius, style: .continuous))
            .contentShape(.rect)
            .onTapGesture { path.append(workout) }
            .padding(.horizontal, Metric.gutter)
        } else if app.week.isEmpty {
            emptyPlanCard
        } else {
            restDayCard
        }
    }

    private var emptyPlanCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Palette.persimmon)
                .frame(width: 52, height: 52)
                .background(Palette.persimmonSoft, in: .circle)
            Text("Your week is wide open").font(.display(26)).foregroundStyle(Palette.ink)
            Text("Pick your workout days and we'll fill them with sessions that suit you.")
                .font(.ui(15)).foregroundStyle(Palette.inkSoft)
            Button("Plan my week") {
                if app.trainingDays.isEmpty { app.trainingDays = [0, 2, 4] }
                app.generateWeek()
            }
            .buttonStyle(.accent)
        }
        .padding(20)
        .cardBackground()
        .padding(.horizontal, Metric.gutter)
    }

    private var restDayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Palette.plum)
                    .frame(width: 48, height: 48)
                    .background(Palette.lilac.opacity(0.45), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest day").font(.display(26)).foregroundStyle(Palette.ink)
                    Text("Muscles grow while you recover.").font(.ui(15)).foregroundStyle(Palette.inkSoft)
                }
            }
            Text("Feeling restless? Try something gentle:")
                .font(.ui(14, weight: .medium)).foregroundStyle(Palette.inkSoft)
            ForEach([Catalog.deskReset, Catalog.bedtime]) { w in
                Button { path.append(w) } label: { WorkoutRow(workout: w) }.buttonStyle(.plain)
            }
        }
        .padding(18)
        .cardBackground(Palette.raised)
        .padding(.horizontal, Metric.gutter)
    }

    // MARK: Program

    private func programCard(_ program: Program) -> some View {
        let total = program.totalDays
        let done = min(app.programDay - 1, total)
        let finished = app.programDay > total
        return Button { path.append(program) } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Palette.hairline, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: Double(done) / Double(total))
                        .stroke(program.tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    if finished {
                        Image(systemName: "trophy.fill").foregroundStyle(Palette.ink)
                    } else {
                        Text("\(app.programDay)").font(.numeral(18)).foregroundStyle(Palette.ink)
                    }
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Your program")
                    Text(program.title).font(.display(20)).foregroundStyle(Palette.ink)
                    Text(finished ? "Complete! Pick your next challenge"
                         : "Next: Day \(app.programDay) of \(total) · Week \((app.programDay - 1) / program.daysPerWeek + 1)")
                        .font(.ui(13)).foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.inkFaint)
            }
            .padding(16)
            .cardBackground(radius: Metric.tileRadius)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Metric.gutter)
    }

    // MARK: Quick hits

    private var quickHits: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Got a few minutes?")
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach([Catalog.tabata, Catalog.deskReset, Catalog.classic7, Catalog.plankParty]) { w in
                        Button { path.append(w) } label: {
                            HStack(spacing: 12) {
                                MoveStage(exercise: w.cover, radius: 14).frame(width: 52, height: 52)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(w.minutes) min").font(.numeral(20)).foregroundStyle(Palette.ink)
                                    Text(w.title).font(.ui(13, weight: .medium)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                                }
                            }
                            .padding(8)
                            .padding(.trailing, 10)
                            .frame(width: 200, alignment: .leading)
                            .cardBackground(radius: 20)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Metric.gutter)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Picks

    /// Recommendations, skipping today's session; Plus workouts appear once unlocked.
    private var picksForYou: [Workout] {
        var list = app.recommendedWorkouts().filter { $0 != app.todaysWorkout }
        if !app.isPro { list += Catalog.workouts.filter { $0.isPro && app.focus.contains($0.region) } }
        return Array(list.prefix(6))
    }

    private var picks: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Picked for you", action: "Explore") { selectTab(.explore) }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(picksForYou) { w in
                        Button { path.append(w) } label: { WorkoutPoster(workout: w) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Metric.gutter)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Weekly goal

    private var weeklyGoal: some View {
        let goal = max(1, app.trainingDays.count)
        let done = min(app.thisWeekCount, goal)
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("This week")
                Text(done >= goal ? "Weekly goal smashed." : "\(goal - done) more to hit your goal")
                    .font(.display(20)).foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    ForEach(0..<goal, id: \.self) { i in
                        Capsule().fill(i < done ? Palette.persimmon : Palette.hairline).frame(height: 8)
                    }
                }
                .padding(.top, 6)
            }
            Text("\(done)/\(goal)")
                .font(.numeral(34))
                .foregroundStyle(Palette.ink)
        }
        .padding(18)
        .cardBackground()
        .padding(.horizontal, Metric.gutter)
    }
}

// MARK: - Week strip

struct WeekStrip: View {
    @Environment(AppState.self) private var app

    var body: some View {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -app.todayIndex, to: cal.startOfDay(for: .now))!
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let date = cal.date(byAdding: .day, value: i, to: start)!
                let isToday = i == app.todayIndex
                let done = app.didWorkout(on: date)
                let planned = app.week[i] != nil
                VStack(spacing: 6) {
                    Text(Weekday.all[i].short)
                        .font(.ui(12, weight: .semibold))
                        .foregroundStyle(isToday ? Palette.canvas.opacity(0.7) : Palette.inkSoft)
                    Text("\(cal.component(.day, from: date))")
                        .font(.numeral(18))
                        .foregroundStyle(isToday ? Palette.canvas : Palette.ink)
                    ZStack {
                        if done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(Palette.persimmon, in: .circle)
                        } else {
                            Circle()
                                .fill(planned ? (isToday ? Palette.persimmon : Palette.ink.opacity(0.35)) : .clear)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(height: 16)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isToday ? Palette.ink : Palette.surface, in: .rect(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(.horizontal, Metric.gutter)
    }
}
