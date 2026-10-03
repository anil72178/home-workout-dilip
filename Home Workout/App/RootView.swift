//
//  RootView.swift
//  Home Workout
//

import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ZStack {
            if app.hasOnboarded {
                MainTabs()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.5), value: app.hasOnboarded)
    }
}

enum AppTab: Hashable { case today, explore, plan, progress, search }

struct MainTabs: View {
    @State private var tab: AppTab = {
        #if DEBUG
        return DebugRoute.tab ?? .today
        #else
        return .today
        #endif
    }()

    var body: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "sun.horizon.fill", value: .today) {
                TodayView(selectTab: { tab = $0 })
            }
            Tab("Explore", systemImage: "square.grid.2x2.fill", value: .explore) {
                ExploreView()
            }
            Tab("Plan", systemImage: "calendar", value: .plan) {
                PlanView()
            }
            Tab("Progress", systemImage: "chart.bar.fill", value: .progress) {
                ProgressHubView()
            }
            Tab("Moves", systemImage: "magnifyingglass", value: .search, role: .search) {
                MovesLibraryView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

/// Shared navigation destinations for every tab's stack.
struct AppDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
            .navigationDestination(for: Program.self) { ProgramDetailView(program: $0) }
            .navigationDestination(for: BodyRegion.self) { CollectionView(region: $0) }
    }
}

extension View {
    func appDestinations() -> some View { modifier(AppDestinations()) }
}
