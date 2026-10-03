//
//  ExploreView.swift
//  Home Workout
//

import SwiftUI

struct ExploreView: View {
    @Environment(AppState.self) private var app
    @State private var style: WorkoutStyle?
    @State private var path = NavigationPath()

    private var filtered: [Workout] {
        Catalog.workouts.filter { style == nil || $0.style == style }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Explore").font(.display(38)).foregroundStyle(Palette.ink)
                        Text("\(Catalog.workouts.count) workouts · \(Catalog.programs.count) programs · \(Catalog.exercises.count) moves")
                            .font(.ui(15)).foregroundStyle(Palette.inkSoft)
                    }
                    .padding(.horizontal, Metric.gutter)
                    .padding(.top, 8)

                    regions
                    programs
                    workouts
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Palette.canvas)
            .appDestinations()
        }
    }

    // MARK: Regions

    private var regions: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(BodyRegion.allCases) { region in
                NavigationLink(value: region) {
                    RegionTile(region: region)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Metric.gutter)
    }

    // MARK: Programs

    private var programs: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Programs")
            Text("Multi-week plans that build on themselves.")
                .font(.ui(14)).foregroundStyle(Palette.inkSoft)
                .padding(.horizontal, Metric.gutter)
                .padding(.top, -8)
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(Catalog.programs) { p in
                        NavigationLink(value: p) { ProgramCard(program: p) }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Metric.gutter)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Workouts

    private var workouts: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "All workouts")
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
                ForEach(filtered) { w in
                    NavigationLink(value: w) { WorkoutRow(workout: w) }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metric.gutter)
            .animation(.smooth, value: style)
        }
    }
}

// MARK: - Region tile

struct RegionTile: View {
    let region: BodyRegion

    private var sample: Exercise? {
        switch region {
        case .full: Catalog.move("Jumping Jack")
        case .core: Catalog.move("Side Plank")
        case .upper: Catalog.move("Pike Push-up")
        case .lower: Catalog.move("Cossack Squat")
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let sample {
                MoveStage(exercise: sample, radius: Metric.tileRadius)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .center, endPoint: .bottom)
                .clipShape(.rect(cornerRadius: Metric.tileRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(region.title).font(.display(19)).foregroundStyle(.white)
                Text("\(Catalog.workouts(in: region).count) workouts")
                    .font(.ui(12, weight: .medium)).foregroundStyle(.white.opacity(0.85))
            }
            .padding(14)
        }
    }
}

// MARK: - Program card

struct ProgramCard: View {
    let program: Program
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                program.tint
                MoveStage(exercise: program.cover, radius: 0)
                    .frame(width: 150, height: 150)
                    .clipShape(.circle)
                    .offset(x: 110, y: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(program.weeks)")
                        .font(.numeral(54, weight: .heavy))
                    Text("weeks").font(.ui(14, weight: .semibold))
                }
                .foregroundStyle(Palette.ink)
                .padding(18)
            }
            .frame(width: 260, height: 190)
            .clipped()
            .overlay(alignment: .topTrailing) {
                if program.isPro { ProBadge().padding(14) }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(program.title).font(.display(22)).foregroundStyle(Palette.ink)
                Text(program.pitch).font(.ui(14)).foregroundStyle(Palette.inkSoft).lineLimit(2)
                HStack(spacing: 12) {
                    Label("\(program.daysPerWeek)× / week", systemImage: "calendar")
                    HStack(spacing: 5) { LevelBars(level: program.level, tint: Palette.inkSoft); Text(program.level.title) }
                }
                .font(.ui(12, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .padding(.top, 4)
            }
            .padding(16)
            .frame(width: 260, alignment: .leading)
        }
        .cardBackground()
        .clipShape(.rect(cornerRadius: Metric.cardRadius, style: .continuous))
    }
}

// MARK: - Collection

struct CollectionView: View {
    let region: BodyRegion
    @Environment(\.dismiss) private var dismiss

    private var moves: [Exercise] {
        Catalog.exercises.filter { $0.muscle.region == region && $0.kind != .rehab }.prefix(12).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(region.title).font(.display(38)).foregroundStyle(Palette.ink)
                    Text("Workouts and moves that target your \(region.title.lowercased()).")
                        .font(.ui(15)).foregroundStyle(Palette.inkSoft)
                }
                .padding(.horizontal, Metric.gutter)

                VStack(spacing: 10) {
                    ForEach(Catalog.workouts(in: region)) { w in
                        NavigationLink(value: w) { WorkoutRow(workout: w) }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Metric.gutter)

                SectionHeader(title: "Moves to know")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                    ForEach(moves) { ex in
                        NavigationLink(value: ex) { MoveTile(exercise: ex) }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Metric.gutter)
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Palette.canvas)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Grid tile for a single move.
struct MoveTile: View {
    let exercise: Exercise
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MoveStage(exercise: exercise, radius: 20)
                .overlay(alignment: .topLeading) {
                    Circle().fill(exercise.kind.tint).frame(width: 9, height: 9).padding(12)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.displayName)
                    .font(.ui(15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text("\(exercise.muscle.title) · \(exercise.kind.title)")
                    .font(.ui(12)).foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, 4)
        }
    }
}
