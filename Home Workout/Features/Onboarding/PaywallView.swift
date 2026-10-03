//
//  PaywallView.swift
//  Home Workout
//
//  One honest offer, always dismissible. No countdowns, no fake toasts.
//

import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var app
    @Environment(Store.self) private var store
    @State private var yearly = true
    @State private var restoring = false

    private var plan: Store.Plan { yearly ? .yearly : .monthly }
    /// Before products load we assume the configured 7-day trial so copy stays consistent.
    private var trial: Bool { yearly && (store.hasTrial(.yearly) || store.products.isEmpty) }

    private let perks: [(String, String, String)] = [
        ("sparkles", "Every workout & program", "All 14 sessions and 4 multi-week plans"),
        ("wand.and.stars", "Build your own", "Unlimited custom workouts from 180+ moves"),
        ("arrow.triangle.2.circlepath", "A plan that adapts", "Gets easier or harder based on how you felt"),
        ("chart.line.uptrend.xyaxis", "Deeper progress", "Monthly trends, body stats and milestones"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Spacer()
                    Button("Not now") { dismiss() }
                        .font(.ui(15, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                }

                // Hero: three clips fanned like cards
                HStack(spacing: -40) {
                    ForEach(Array(["Glute Bridge", "Push-up", "Side Plank"].compactMap(Catalog.move).enumerated()), id: \.offset) { i, ex in
                        MoveStage(exercise: ex, live: i == 1, radius: 24)
                            .frame(width: 130, height: 130)
                            .rotationEffect(.degrees(Double(i - 1) * 8))
                            .offset(y: i == 1 ? -8 : 6)
                            .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
                            .zIndex(i == 1 ? 1 : 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Wordmark(size: 22)
                        ProBadge()
                    }
                    Text("Unlock the whole studio.")
                        .font(.display(32))
                        .foregroundStyle(Palette.ink)
                }

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(perks, id: \.1) { symbol, title, detail in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Palette.persimmon)
                                .frame(width: 34, height: 34)
                                .background(Palette.persimmonSoft, in: .circle)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title).font(.ui(16, weight: .semibold)).foregroundStyle(Palette.ink)
                                Text(detail).font(.ui(14)).foregroundStyle(Palette.inkSoft)
                            }
                        }
                    }
                }

                VStack(spacing: 10) {
                    planOption(isYearly: true, title: "Yearly", price: store.priceLabel(.yearly),
                               note: yearlyNote, badge: "Best value")
                    planOption(isYearly: false, title: "Monthly", price: store.priceLabel(.monthly),
                               note: "Cancel anytime", badge: nil)
                }

                if let error = store.errorMessage {
                    Text(error)
                        .font(.ui(14))
                        .foregroundStyle(Color(hex: "D63B1F"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

            }
            .padding(.horizontal, Metric.gutter)
            .padding(.vertical, 16)
        }
        .background(Palette.canvas)
        .scrollIndicators(.hidden)
        .task { await store.loadProducts() }
        .onAppear { store.errorMessage = nil }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    Task {
                        if await store.purchase(plan) {
                            if trial { Reminders.shared.scheduleTrialEnding() }
                            dismiss()
                        }
                    }
                } label: {
                    if store.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(trial ? "Start 7-day free trial" : "Continue")
                    }
                }
                .buttonStyle(.accent)
                .disabled(store.isPurchasing)
                Text(trial ? "We'll remind you 2 days before your trial ends." : "Renews automatically. Cancel anytime in Settings.")
                    .font(.ui(13))
                    .foregroundStyle(Palette.inkSoft)
                HStack(spacing: 18) {
                    Button(restoring ? "Restoring…" : "Restore") {
                        restoring = true
                        Task {
                            await store.restore()
                            restoring = false
                            if app.isPro { dismiss() }
                        }
                    }
                    Link("Terms", destination: Brand.termsURL)
                    Link("Privacy", destination: Brand.privacyURL)
                }
                .font(.ui(13, weight: .medium))
                .foregroundStyle(Palette.inkFaint)
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 12)
            .background(Palette.canvas)
        }
    }

    private var yearlyNote: String {
        let perMonth = store.monthlyEquivalent(.yearly).map { "\($0)/mo" } ?? "$3.33/mo"
        return store.hasTrial(.yearly) || store.products.isEmpty ? "7 days free, then \(perMonth)" : "Just \(perMonth)"
    }

    private func planOption(isYearly: Bool, title: String, price: String, note: String, badge: String?) -> some View {
        let on = yearly == isYearly
        return Button { yearly = isYearly } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.ui(17, weight: .semibold))
                        if let badge {
                            Text(badge.uppercased())
                                .font(.ui(10, weight: .heavy)).tracking(0.6)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).frame(height: 20)
                                .background(Palette.persimmon, in: .capsule)
                        }
                    }
                    Text(note).font(.ui(13)).foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                Text(price).font(.numeral(16, weight: .semibold))
            }
            .foregroundStyle(Palette.ink)
            .padding(18)
            .background(Palette.surface, in: .rect(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(on ? Palette.ink : Palette.hairline, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: on)
    }
}
