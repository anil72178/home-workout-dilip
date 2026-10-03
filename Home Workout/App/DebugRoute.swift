//
//  DebugRoute.swift
//  Home Workout
//
//  DEBUG-only: `-screen <name>` launch argument jumps straight to a screen
//  so the design can be reviewed and screenshotted quickly.
//

import SwiftUI

#if DEBUG
enum DebugRoute {
    static var screen: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screen"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static var onboardingStep: OnboardingStep? {
        switch screen {
        case "name": .name
        case "goal": .goal
        case "focus": .focus
        case "level": .level
        case "rhythm": .rhythm
        case "home": .home
        case "building": .building
        case "reveal": .reveal
        default: nil
        }
    }

    static var tab: AppTab? {
        switch screen {
        case "today", "detail", "player", "rest", "done", "program", "exercise", "paywall": .today
        case "explore": .explore
        case "plan", "builder": .plan
        case "progress", "settings": .progress
        case "moves": .search
        default: nil
        }
    }
}
#endif
