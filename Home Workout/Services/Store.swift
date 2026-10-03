//
//  Store.swift
//  Home Workout
//
//  Mova Plus subscriptions with StoreKit 2. Product IDs must match
//  App Store Connect (and Mova.storekit for local testing).
//

import Foundation
import StoreKit
import Observation

@MainActor
@Observable
final class Store {
    enum Plan: String, CaseIterable {
        case yearly = "com.habbithub.mova.plus.yearly"
        case monthly = "com.habbithub.mova.plus.monthly"
    }

    private(set) var products: [Plan: Product] = [:]
    private(set) var isPurchasing = false
    var errorMessage: String?

    @ObservationIgnored private weak var app: AppState?
    @ObservationIgnored private var updates: Task<Void, Never>?

    func attach(_ app: AppState) {
        self.app = app
        updates?.cancel()
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        let loaded = (try? await Product.products(for: Plan.allCases.map(\.rawValue))) ?? []
        for product in loaded {
            if let plan = Plan(rawValue: product.id) { products[plan] = product }
        }
    }

    /// Price line for the paywall, e.g. "$39.99 / year".
    func priceLabel(_ plan: Plan) -> String {
        guard let p = products[plan] else { return plan == .yearly ? "$39.99 / year" : "$7.99 / month" }
        return "\(p.displayPrice) / \(plan == .yearly ? "year" : "month")"
    }

    func monthlyEquivalent(_ plan: Plan) -> String? {
        guard plan == .yearly, let p = products[plan] else { return nil }
        return (p.price / 12).formatted(p.priceFormatStyle)
    }

    func hasTrial(_ plan: Plan) -> Bool {
        products[plan]?.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    /// Returns true when the purchase unlocked Plus.
    @discardableResult
    func purchase(_ plan: Plan) async -> Bool {
        errorMessage = nil
        guard let product = products[plan] else {
            errorMessage = "The store isn't available right now. Please try again in a moment."
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await refreshEntitlements()
                    return app?.isPro ?? false
                }
                errorMessage = "We couldn't verify that purchase."
            case .pending:
                errorMessage = "Your purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        return false
    }

    func restore() async {
        errorMessage = nil
        try? await AppStore.sync()
        await refreshEntitlements()
        if app?.isPro == false { errorMessage = "No active Mova Plus subscription was found for this Apple ID." }
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, Plan(rawValue: t.productID) != nil, t.revocationDate == nil {
                active = true
            }
        }
        app?.isPro = active
    }
}
