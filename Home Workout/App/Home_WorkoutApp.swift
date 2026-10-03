//
//  Home_WorkoutApp.swift
//  Home Workout
//
//  Created by Dilip Hirpara  on 01/10/26.
//

import SwiftUI
import UserNotifications

@main
struct Home_WorkoutApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var app: AppState = {
        #if DEBUG
        if DebugRoute.tab != nil {
            // Screenshot routes run against a throwaway, pre-filled state.
            let state = AppState(persistence: nil)
            state.name = "Alex"
            state.hasOnboarded = true
            state.trainingDays = [0, 1, 3, 5]
            state.generateWeek()
            state.startProgram(Catalog.programs[0])
            state.programDay = 4
            state.loadDemoHistory()
            return state
        }
        #endif
        return AppState()
    }()
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(store)
                .tint(Palette.persimmon)
                .task { store.attach(app) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Reminders.shared.schedule(for: app) }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Show reminders even while the app is open.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
