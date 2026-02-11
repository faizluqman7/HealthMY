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
        HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .bloodGlucose)!
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
    
    // Fetch all weight samples (optionally within a date range)
    func fetchAllWeightSamples(from startDate: Date? = nil, to endDate: Date? = nil, completion: @escaping ([(Double, Date)]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion([])
            return
        }
        let unit = HKUnit.gramUnit(with: .kilo)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let query = HKSampleQuery(sampleType: type, predicate: startDate == nil && endDate == nil ? nil : predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, results, _ in
            let samples = (results as? [HKQuantitySample])?.map { ($0.quantity.doubleValue(for: unit), $0.endDate) } ?? []
            completion(samples)
        }
        healthStore.execute(query)
    }

    // Fetch all height samples (optionally within a date range)
    func fetchAllHeightSamples(from startDate: Date? = nil, to endDate: Date? = nil, completion: @escaping ([(Double, Date)]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .height) else {
            completion([])
            return
        }
        let unit = HKUnit.meter()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let query = HKSampleQuery(sampleType: type, predicate: startDate == nil && endDate == nil ? nil : predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, results, _ in
            let samples = (results as? [HKQuantitySample])?.map { ($0.quantity.doubleValue(for: unit), $0.endDate) } ?? []
            completion(samples)
        }
        healthStore.execute(query)
    }

    // Fetch all blood pressure samples (optionally within a date range)
    func fetchAllBloodPressureSamples(from startDate: Date? = nil, to endDate: Date? = nil, completion: @escaping ([(Int, Int, Date)]) -> Void) {
        guard let bpType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure) else {
            completion([])
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let query = HKSampleQuery(sampleType: bpType, predicate: startDate == nil && endDate == nil ? nil : predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, results, _ in
            let samples: [(Int, Int, Date)] = (results as? [HKCorrelation])?.compactMap { correlation in
                let systolic = correlation.objects(for: HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!)
                    .compactMap { ($0 as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit.millimeterOfMercury()) }
                    .first
                let diastolic = correlation.objects(for: HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!)
                    .compactMap { ($0 as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit.millimeterOfMercury()) }
                    .first
                let date = correlation.endDate
                if let sys = systolic, let dia = diastolic {
                    return (Int(sys), Int(dia), date)
                } else {
                    return nil
                }
            } ?? []
            completion(samples)
        }
        healthStore.execute(query)
    }
    
    // Fetch all pulse (heart rate) samples
    func fetchAllPulseSamples(from startDate: Date? = nil, to endDate: Date? = nil, completion: @escaping ([(Int, Date)]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion([])
            return
        }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let query = HKSampleQuery(sampleType: type, predicate: startDate == nil && endDate == nil ? nil : predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, results, _ in
            let samples = (results as? [HKQuantitySample])?.map { (Int($0.quantity.doubleValue(for: unit)), $0.endDate) } ?? []
            completion(samples)
        }
        healthStore.execute(query)
    }

    // Fetch all glucose samples
    func fetchAllGlucoseSamples(from startDate: Date? = nil, to endDate: Date? = nil, completion: @escaping ([(Double, Date)]) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else {
            completion([])
            return
        }
        let unit = HKUnit(from: "mg/dL")
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let query = HKSampleQuery(sampleType: type, predicate: startDate == nil && endDate == nil ? nil : predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, results, _ in
            let samples = (results as? [HKQuantitySample])?.map { ($0.quantity.doubleValue(for: unit), $0.endDate) } ?? []
            completion(samples)
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
