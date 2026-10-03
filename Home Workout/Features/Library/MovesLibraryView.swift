//
//  MovesLibraryView.swift
//  Home Workout
//

import SwiftUI

struct MovesLibraryView: View {
    @State private var query = ""
    @State private var region: BodyRegion?
    @State private var kind: MoveKind?
    @State private var quietOnly = false

    private let kinds: [MoveKind] = [.strength, .cardio, .stretching, .mobility, .plyometrics]

    private var results: [Exercise] {
        Catalog.exercises.filter {
            (region == nil || $0.muscle.region == region) &&
            (kind == nil || $0.kind == kind) &&
            (!quietOnly || !SessionPlan.isLoud($0)) &&
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.muscle.title.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    filters
                    Text("\(results.count) moves")
                        .font(.ui(13, weight: .medium))
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.horizontal, Metric.gutter)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 20) {
                        ForEach(results) { ex in
                            NavigationLink(value: ex) { MoveTile(exercise: ex) }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Metric.gutter)
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Palette.canvas)
            .navigationTitle("Moves")
            .searchable(text: $query, prompt: "Push-up, glutes, stretch…")
            .appDestinations()
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Button { region = nil } label: { Chip(title: "All body", selected: region == nil) }
                    ForEach(BodyRegion.allCases.filter { $0 != .full }) { r in
                        Button { region = region == r ? nil : r } label: { Chip(title: r.title, symbol: r.symbol, selected: region == r) }
                    }
                }
                .padding(.horizontal, Metric.gutter)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Button { quietOnly.toggle() } label: { Chip(title: "Quiet", symbol: "speaker.slash.fill", selected: quietOnly) }
                    ForEach(kinds) { k in
                        Button { kind = kind == k ? nil : k } label: {
                            HStack(spacing: 6) {
                                Circle().fill(k.tint).frame(width: 8, height: 8)
                                Text(k.title).font(.ui(14, weight: .semibold))
                            }
                            .padding(.horizontal, 14).frame(height: 36)
                            .foregroundStyle(kind == k ? Palette.canvas : Palette.ink)
                            .background(kind == k ? Palette.ink : Palette.surface, in: .capsule)
                            .overlay(Capsule().strokeBorder(kind == k ? .clear : Palette.hairline))
                        }
                    }
                }
                .padding(.horizontal, Metric.gutter)
            }
        }
        .buttonStyle(.plain)
        .scrollIndicators(.hidden)
        .animation(.snappy(duration: 0.2), value: kind)
    }
}

// MARK: - Exercise detail

struct ExerciseDetailView: View {
    let exercise: Exercise
    var inSheet = false
    @Environment(\.dismiss) private var dismiss
    @State private var practicing: Workout?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .top) {
                    exercise.stageColor
                    MoveStage(exercise: exercise, live: true, radius: 0)
                        .padding(.top, inSheet ? 20 : 60)
                    HStack {
                        Button { dismiss() } label: {
                            RoundIcon(symbol: inSheet ? "xmark" : "chevron.left", fill: .white, floating: true)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Metric.gutter)
                    .padding(.top, inSheet ? 16 : 60)
                }

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(exercise.displayName).font(.display(32)).foregroundStyle(Palette.ink)
                        HStack(spacing: 8) {
                            Tag(title: exercise.kind.title, tint: exercise.kind.tint)
                            Tag(title: exercise.level.title, tint: Palette.ink.opacity(0.4))
                            if !SessionPlan.isLoud(exercise) { Tag(title: "Quiet", tint: Palette.mint) }
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("How to do it").font(.display(22)).foregroundStyle(Palette.ink)
                        ForEach(Array(exercise.steps.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 14) {
                                Text("\(i + 1)")
                                    .font(.numeral(14))
                                    .foregroundStyle(Palette.ink)
                                    .frame(width: 28, height: 28)
                                    .background(Palette.persimmonSoft, in: .circle)
                                Text(step).font(.ui(15)).foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Muscles worked").font(.display(22)).foregroundStyle(Palette.ink)
                        FlowChips(primary: exercise.muscle, secondary: exercise.secondary)
                    }

                    if !exercise.about.isEmpty {
                        Text(exercise.about)
                            .font(.ui(15))
                            .foregroundStyle(Palette.inkSoft)
                            .padding(16)
                            .cardBackground(radius: 20)
                    }
                }
                .padding(Metric.gutter)
                .padding(.bottom, 100)
            }
        }
        .scrollIndicators(.hidden)
        .background(Palette.canvas)
        .ignoresSafeArea(edges: inSheet ? [] : .top)
        .navigationBarBackButtonHidden()
        .toolbar(inSheet ? .hidden : .automatic, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            if !inSheet {
                Button {
                    practicing = Workout(id: "practice-\(exercise.id)", title: exercise.displayName, subtitle: "Practice",
                                         style: .quick, region: exercise.muscle.region, level: exercise.level,
                                         blocks: [Block(exercise: exercise, seconds: 30)], restSeconds: 0)
                } label: { Label("Practice for 30 seconds", systemImage: "play.fill") }
                .buttonStyle(.primary)
                .padding(.horizontal, Metric.gutter)
                .padding(.top, 10)
            }
        }
        .fullScreenCover(item: $practicing) { PlayerView(workout: $0, options: SessionOptions(warmUp: false, coolDown: false)) }
    }
}

struct FlowChips: View {
    let primary: Muscle
    let secondary: [Muscle]
    var body: some View {
        HStack(spacing: 8) {
            Text(primary.title)
                .font(.ui(14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).frame(height: 34)
                .background(Palette.persimmon, in: .capsule)
            ForEach(secondary.prefix(3), id: \.self) { m in
                Text(m.title)
                    .font(.ui(14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(Palette.surface, in: .capsule)
            }
        }
    }
}
