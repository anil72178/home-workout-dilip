//
//  WorkoutBuilderView.swift
//  Home Workout
//

import SwiftUI

struct WorkoutBuilderView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var blocks: [Block] = []
    @State private var seconds = 40
    @State private var rest = 15
    @State private var rounds = 1
    @State private var picking = false

    private var draft: Workout {
        let name = title.trimmingCharacters(in: .whitespaces)
        return Workout.custom(title: name.isEmpty ? "My Workout" : name,
                              blocks: blocks.map { Block(exercise: $0.exercise, seconds: seconds) },
                              rounds: rounds, restSeconds: rest)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TextField("Name your workout", text: $title)
                        .font(.display(30))
                        .foregroundStyle(Palette.ink)

                    HStack(spacing: 10) {
                        stepper("Work", value: $seconds, step: 5, range: 10...120, unit: "s")
                        stepper("Rest", value: $rest, step: 5, range: 0...90, unit: "s")
                        stepper("Rounds", value: $rounds, step: 1, range: 1...5, unit: "×")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Moves").font(.display(22)).foregroundStyle(Palette.ink)
                            Spacer()
                            if !blocks.isEmpty {
                                Text("~\(draft.minutes) min").font(.numeral(16)).foregroundStyle(Palette.inkSoft)
                            }
                        }
                        if blocks.isEmpty {
                            VStack(spacing: 12) {
                                HStack(spacing: -16) {
                                    ForEach(["Push-up", "Air Squat", "Forearm Plank"].compactMap(Catalog.move)) { ex in
                                        MoveStage(exercise: ex, radius: 16).frame(width: 64, height: 64)
                                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.canvas, lineWidth: 3))
                                    }
                                }
                                Text("Start with a few moves you enjoy.")
                                    .font(.ui(15)).foregroundStyle(Palette.inkSoft)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .background(RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Palette.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [6, 6])))
                        } else {
                            ForEach(Array(blocks.enumerated()), id: \.element.id) { i, b in
                                HStack(spacing: 10) {
                                    Text("\(i + 1)").font(.numeral(15)).foregroundStyle(Palette.inkFaint).frame(width: 20)
                                    MoveRow(block: Block(exercise: b.exercise, seconds: seconds))
                                    Button { withAnimation { _ = blocks.remove(at: i) } } label: {
                                        Image(systemName: "minus.circle.fill").font(.system(size: 22)).foregroundStyle(Palette.inkFaint)
                                    }
                                }
                            }
                        }
                        Button { picking = true } label: { Label("Add moves", systemImage: "plus") }
                            .buttonStyle(.soft)
                            .padding(.top, 4)
                    }
                }
                .padding(Metric.gutter)
            }
            .background(Palette.canvas)
            .navigationTitle("New workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        app.customWorkouts.insert(draft, at: 0)
                        dismiss()
                    }
                    .disabled(blocks.isEmpty)
                }
            }
            .sheet(isPresented: $picking) {
                MovePicker { picked in
                    blocks += picked.map { Block(exercise: $0, seconds: seconds) }
                }
            }
        }
    }

    private func stepper(_ label: String, value: Binding<Int>, step: Int, range: ClosedRange<Int>, unit: String) -> some View {
        VStack(spacing: 8) {
            Eyebrow(label)
            Text("\(value.wrappedValue)\(unit)").font(.numeral(24)).foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
            HStack(spacing: 0) {
                Button { value.wrappedValue = max(range.lowerBound, value.wrappedValue - step) } label: {
                    Image(systemName: "minus").frame(maxWidth: .infinity, minHeight: 34)
                }
                Divider().frame(height: 18)
                Button { value.wrappedValue = min(range.upperBound, value.wrappedValue + step) } label: {
                    Image(systemName: "plus").frame(maxWidth: .infinity, minHeight: 34)
                }
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Palette.ink)
            .background(Palette.raised, in: .capsule)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .cardBackground(radius: 20)
        .animation(.snappy, value: value.wrappedValue)
    }
}

// MARK: - Multi-select move picker

struct MovePicker: View {
    var onDone: ([Exercise]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var region: BodyRegion?
    @State private var selected: [Exercise] = []

    private var results: [Exercise] {
        Catalog.exercises.filter {
            (region == nil || $0.muscle.region == region) &&
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            Button { region = nil } label: { Chip(title: "All", selected: region == nil) }
                            ForEach(BodyRegion.allCases) { r in
                                Button { region = r } label: { Chip(title: r.title, selected: region == r) }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Metric.gutter)
                    }
                    .scrollIndicators(.hidden)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                        ForEach(results) { ex in
                            let on = selected.contains(ex)
                            Button {
                                if let i = selected.firstIndex(of: ex) { selected.remove(at: i) } else { selected.append(ex) }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    MoveStage(exercise: ex, radius: 16)
                                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(on ? Palette.persimmon : .clear, lineWidth: 3))
                                        .overlay(alignment: .topTrailing) {
                                            if let n = selected.firstIndex(of: ex) {
                                                Text("\(n + 1)").font(.numeral(13)).foregroundStyle(.white)
                                                    .frame(width: 24, height: 24)
                                                    .background(Palette.persimmon, in: .circle)
                                                    .padding(6)
                                            }
                                        }
                                    Text(ex.displayName).font(.ui(12, weight: .semibold))
                                        .foregroundStyle(Palette.ink).lineLimit(2)
                                        .frame(height: 30, alignment: .top)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Metric.gutter)
                }
            }
            .background(Palette.canvas)
            .searchable(text: $query, prompt: "Search 180+ moves")
            .navigationTitle("Add moves")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                if !selected.isEmpty {
                    Button("Add \(selected.count) move\(selected.count == 1 ? "" : "s")") {
                        onDone(selected); dismiss()
                    }
                    .buttonStyle(.accent)
                    .padding(.horizontal, Metric.gutter)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.smooth, value: selected.isEmpty)
        }
    }
}
