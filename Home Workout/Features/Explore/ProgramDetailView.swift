//
//  ProgramDetailView.swift
//  Home Workout
//

import SwiftUI

struct ProgramDetailView: View {
    let program: Program
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var playing: Workout?
    @State private var expandedWeek: Int?
    @State private var showPaywall = false
    @State private var confirmSwitch = false
    @State private var confirmLeave = false

    private var isActive: Bool { app.activeProgramID == program.id }
    private var doneDays: Int { isActive ? min(app.programDay - 1, total) : 0 }
    private var total: Int { program.totalDays }
    private var isFinished: Bool { isActive && app.programDay > total }
    private var locked: Bool { program.isPro && !app.isPro }
    /// 0-based day index → workout.
    private func workout(forDay day: Int) -> Workout { program.workout(forDay: day + 1) }

    private var ctaTitle: String {
        if locked { return "Unlock with Plus" }
        if isFinished { return "Start again" }
        return isActive ? "Continue · Day \(app.programDay)" : "Start program"
    }

    private func primaryAction() {
        if locked { showPaywall = true; return }
        if isFinished { app.startProgram(program) }
        if !isActive {
            if app.activeProgramID != nil { confirmSwitch = true; return }
            app.startProgram(program)
        }
        playing = program.workout(forDay: app.programDay)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(program.title).font(.display(36)).foregroundStyle(Palette.ink)
                        Text(program.pitch).font(.ui(16)).foregroundStyle(Palette.inkSoft)
                    }
                    if isActive { progressCard }
                    phases
                    weeks
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.top, 24)
                .padding(.bottom, 120)
            }
        }
        .scrollIndicators(.hidden)
        .background(Palette.canvas)
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            Button(action: primaryAction) {
                HStack(spacing: 8) {
                    if locked { Image(systemName: "lock.fill") }
                    Text(ctaTitle)
                }
            }
            .buttonStyle(locked ? PrimaryButtonStyle(tint: Palette.plum, foreground: .white) : .accent)
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 10)
            .background(LinearGradient(colors: [Palette.canvas.opacity(0), Palette.canvas], startPoint: .top, endPoint: .center).ignoresSafeArea())
        }
        .fullScreenCover(item: $playing) { PlayerView(workout: $0, programDay: app.programDay) }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .confirmationDialog("Switch programs?", isPresented: $confirmSwitch, titleVisibility: .visible) {
            Button("Start \(program.title)") {
                app.startProgram(program)
                playing = program.workout(forDay: 1)
            }
        } message: {
            Text("Your progress in \(app.activeProgram?.title ?? "your current program") will be reset.")
        }
        .confirmationDialog("Leave \(program.title)?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Leave program", role: .destructive) { app.leaveProgram() }
        } message: {
            Text("Your finished sessions stay in your history.")
        }
        .onAppear { expandedWeek = min(doneDays / program.daysPerWeek, program.weeks - 1) }
    }

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            program.tint
            MoveStage(exercise: program.cover, live: true, radius: 0)
                .frame(width: 300, height: 300)
                .clipShape(.circle)
                .offset(x: 140, y: 120)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { dismiss() } label: { RoundIcon(symbol: "chevron.left", fill: .white, floating: true) }
                    Spacer()
                    if program.isPro { ProBadge() }
                }
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(program.weeks)").font(.numeral(84, weight: .heavy))
                    Text("weeks").font(.display(22))
                }
                .foregroundStyle(Palette.ink)
                HStack(spacing: 12) {
                    Label("\(program.daysPerWeek) days / week", systemImage: "calendar")
                    Label(program.level.title, systemImage: "chart.bar.fill")
                }
                .font(.ui(13, weight: .semibold))
                .foregroundStyle(Palette.ink.opacity(0.75))
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 60)
            .padding(.bottom, 24)
        }
        .frame(height: 380)
        .clipped()
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow("Your progress")
                Spacer()
                Text("\(Int(Double(doneDays) / Double(total) * 100))%")
                    .font(.numeral(16)).foregroundStyle(Palette.ink)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.hairline)
                    Capsule().fill(program.tint).frame(width: geo.size.width * Double(doneDays) / Double(total))
                }
            }
            .frame(height: 10)
            HStack {
                Text(isFinished ? "Program complete. Brilliant work!" : "\(doneDays) of \(total) sessions done. Keep showing up.")
                    .font(.ui(14)).foregroundStyle(Palette.inkSoft)
                Spacer()
                Button("Leave") { confirmLeave = true }
                    .font(.ui(14, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(18)
        .cardBackground(radius: Metric.tileRadius)
    }

    private var phases: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How it works").font(.display(22)).foregroundStyle(Palette.ink)
            HStack(spacing: 10) {
                phase("1", "Find your base", "Learn the moves at an easy pace")
                phase("2", "Build", "More rounds, shorter rests")
                phase("3", "Peak", "A final challenge week")
            }
        }
    }

    private func phase(_ n: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(n).font(.numeral(16)).foregroundStyle(Palette.ink)
                .frame(width: 30, height: 30)
                .background(program.tint.opacity(0.5), in: .circle)
            Text(title).font(.ui(14, weight: .bold)).foregroundStyle(Palette.ink)
            Text(detail).font(.ui(12)).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .padding(12)
        .cardBackground(radius: 18)
    }

    private var weeks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Week by week").font(.display(22)).foregroundStyle(Palette.ink)
            ForEach(0..<program.weeks, id: \.self) { w in
                let open = expandedWeek == w
                VStack(alignment: .leading, spacing: 12) {
                    Button { withAnimation(.smooth) { expandedWeek = open ? nil : w } } label: {
                        HStack {
                            Text("Week \(w + 1)").font(.ui(17, weight: .semibold)).foregroundStyle(Palette.ink)
                            Spacer()
                            HStack(spacing: 5) {
                                ForEach(0..<program.daysPerWeek, id: \.self) { d in
                                    let day = w * program.daysPerWeek + d
                                    Circle()
                                        .fill(day < doneDays ? program.tint : (day == doneDays && isActive ? Palette.ink : Palette.hairline))
                                        .frame(width: 9, height: 9)
                                }
                            }
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Palette.inkFaint)
                                .rotationEffect(.degrees(open ? 180 : 0))
                                .padding(.leading, 6)
                        }
                    }
                    .buttonStyle(.plain)

                    if open {
                        VStack(spacing: 8) {
                            ForEach(0..<program.daysPerWeek, id: \.self) { d in
                                let day = w * program.daysPerWeek + d
                                let wk = workout(forDay: day)
                                NavigationLink(value: wk) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            if day < doneDays {
                                                Image(systemName: "checkmark").font(.system(size: 13, weight: .black)).foregroundStyle(Palette.ink)
                                            } else {
                                                Text("\(day + 1)").font(.numeral(14)).foregroundStyle(day == doneDays && isActive ? .white : Palette.ink)
                                            }
                                        }
                                        .frame(width: 34, height: 34)
                                        .background(day < doneDays ? program.tint : (day == doneDays && isActive ? Palette.ink : Palette.raised), in: .circle)
                                        MoveStage(exercise: wk.cover, radius: 10).frame(width: 44, height: 44)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(wk.title).font(.ui(15, weight: .semibold)).foregroundStyle(Palette.ink)
                                            Text("\(wk.minutes) min · \(wk.style.title)").font(.ui(12)).foregroundStyle(Palette.inkSoft)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(16)
                .cardBackground(radius: Metric.tileRadius)
            }
        }
    }
}
