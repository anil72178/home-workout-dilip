//
//  Reminders.swift
//  Home Workout
//
//  Weekly local notifications on the user's workout days.
//

import Foundation
import UserNotifications

@MainActor
final class Reminders {
    static let shared = Reminders()
    private let center = UNUserNotificationCenter.current()
    private let prefix = "mova.reminder."

    /// Asks for permission; returns whether notifications are allowed.
    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    var isAuthorized: Bool {
        get async {
            let status = await center.notificationSettings().authorizationStatus
            return status == .authorized || status == .provisional
        }
    }

    /// Heads-up two days before a 7-day free trial converts.
    func scheduleTrialEnding() {
        let content = UNMutableNotificationContent()
        content.title = "Your Mova Plus trial ends in 2 days"
        content.body = "Keep everything unlocked, or cancel anytime in Settings › Apple ID › Subscriptions."
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5 * 24 * 3600, repeats: false)
        Task {
            await requestAuthorization()
            try? await center.add(UNNotificationRequest(identifier: "mova.trial", content: content, trigger: trigger))
        }
    }

    /// Replaces all scheduled reminders to match the current plan.
    func schedule(for app: AppState) {
        let days = app.trainingDays
        let enabled = app.remindersOn && app.hasOnboarded
        let time = Calendar.current.dateComponents([.hour, .minute], from: app.reminder)
        let titles = app.week.mapValues(\.title)
        let name = app.displayName

        Task {
            let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: pending)
            guard enabled, await isAuthorized else { return }

            for day in days {
                let content = UNMutableNotificationContent()
                if let title = titles[day] {
                    content.title = "\(title) is waiting"
                    content.body = "Your session for today, \(name). Press play when you're ready."
                } else {
                    content.title = "Time to move"
                    content.body = "A few minutes is all it takes. Your living room is ready."
                }
                content.sound = .default
                var when = time
                when.weekday = Weekday(index: day).calendarWeekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
                try? await center.add(UNNotificationRequest(identifier: prefix + "\(day)", content: content, trigger: trigger))
            }
        }
    }
}
