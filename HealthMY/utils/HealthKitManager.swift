//
//  HealthKitManager.swift
//  HealthMY
//
//  Created by Faiz Luqman on 27/06/2025.
//


import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    
    // HealthKit types you want to read
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .height)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
        HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!
    ]
    
    // Request access
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            if let error = error {
                print("HealthKit auth error: \(error)")
            }
            completion(success)
        }
    }
    
    // Fetch latest weight
    func fetchLatestWeight(completion: @escaping (Double?, Date?) -> Void) {
        fetchLatestQuantitySample(for: .bodyMass, unit: .gramUnit(with: .kilo), completion: completion)
    }

    // Fetch latest height
    func fetchLatestHeight(completion: @escaping (Double?, Date?) -> Void) {
        fetchLatestQuantitySample(for: .height, unit: .meter(), completion: completion)
    }

    // Fetch latest BP (systolic + diastolic)
    func fetchLatestBloodPressure(completion: @escaping (Int?, Int?, Date?) -> Void) {
        guard let bpType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure) else {
            completion(nil, nil, nil)
            return
        }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: bpType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, results, _ in
            guard let correlation = results?.first as? HKCorrelation else {
                completion(nil, nil, nil)
                return
            }

            let systolic = correlation.objects(for: HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!)
                .compactMap { ($0 as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit.millimeterOfMercury()) }
                .first
            let diastolic = correlation.objects(for: HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!)
                .compactMap { ($0 as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit.millimeterOfMercury()) }
                .first
            
            let date = correlation.endDate
            completion(Int(systolic ?? 0), Int(diastolic ?? 0), date)
        }
        
        healthStore.execute(query)
    }
    
    // Generic method
    private func fetchLatestQuantitySample(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double?, Date?) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(nil, nil)
            return
        }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, results, _ in
            guard let sample = results?.first as? HKQuantitySample else {
                completion(nil, nil)
                return
            }
            completion(sample.quantity.doubleValue(for: unit), sample.endDate)
        }

        healthStore.execute(query)
    }
}
