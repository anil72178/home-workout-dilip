//
//  HealthService.swift
//  Home Workout
//
//  Writes finished workouts (with energy burned) and logged body weight
//  to Apple Health, and reads the latest weight back.
//

import Foundation
import HealthKit

@MainActor
final class HealthService {
    static let shared = HealthService()
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned), HKQuantityType(.bodyMass)]
    }
    private var readTypes: Set<HKObjectType> { [HKQuantityType(.bodyMass)] }

    /// Shows the Health permission sheet. Returns false if Health isn't available.
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            return true
        } catch {
            return false
        }
    }

    func saveWorkout(_ workout: Workout, start: Date, end: Date, calories: Int) async {
        guard isAvailable, store.authorizationStatus(for: .workoutType()) == .sharingAuthorized else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = activityType(for: workout)
        config.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: start)
            let energy = HKQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                          quantity: HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories)),
                                          start: start, end: end)
            try await builder.addSamples([energy])
            try await builder.addMetadata([HKMetadataKeyWorkoutBrandName: "Mova", "MovaWorkout": workout.title])
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            // Health is best-effort; the session is already in the app's own log.
        }
    }

    func saveWeight(_ kg: Double) async {
        let type = HKQuantityType(.bodyMass)
        guard isAvailable, store.authorizationStatus(for: type) == .sharingAuthorized else { return }
        let sample = HKQuantitySample(type: type, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                                      start: .now, end: .now)
        try? await store.save(sample)
    }

    func latestWeight() async -> Double? {
        guard isAvailable else { return nil }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.bodyMass))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
        let samples = try? await descriptor.result(for: store)
        return samples?.first?.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }

    private func activityType(for workout: Workout) -> HKWorkoutActivityType {
        switch workout.style {
        case .sweat, .quick: .highIntensityIntervalTraining
        case .flow: .flexibility
        case .core: .coreTraining
        case .sculpt: .functionalStrengthTraining
        }
    }
}
