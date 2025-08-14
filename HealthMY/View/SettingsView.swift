//
//  SettingsView.swift
//  HealthMY
//
//  Created by Faiz Luqman on 23/06/2025.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var refreshID: UUID
    @State private var status: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Button("Import from Health") {
                importHealthData()
            }

            Text(status)
                .font(.caption)
                .foregroundColor(.gray)

            Spacer()
        }
        .padding()
        .navigationTitle("Settings")
    }

    func importHealthData() {
        HealthKitManager.shared.requestAuthorization { success in
            guard success else {
                DispatchQueue.main.async {
                    status = "Health access denied ❌"
                }
                return
            }

            let now = Date()
            let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now

            // Weight
            HealthKitManager.shared.fetchAllWeightSamples { samples in
                let filtered: [(Double, Date)]
                if samples.count > 180 {
                    filtered = samples.filter { $0.1 >= ninetyDaysAgo }
                } else {
                    filtered = samples
                }
                DispatchQueue.main.async {
                    for (w, date) in filtered {
                        let fetchDescriptor = FetchDescriptor<WeightReading>(predicate: #Predicate { $0.weight == w && $0.date == date })
                        let existing = try? modelContext.fetch(fetchDescriptor)
                        if existing?.isEmpty ?? true {
                            modelContext.insert(WeightReading(weight: w, date: date))
                        }
                    }
                }
            }

            // Height
            HealthKitManager.shared.fetchAllHeightSamples { samples in
                let filtered: [(Double, Date)]
                if samples.count > 180 {
                    filtered = samples.filter { $0.1 >= ninetyDaysAgo }
                } else {
                    filtered = samples
                }
                DispatchQueue.main.async {
                    for (h, date) in filtered {
                        let fetchDescriptor = FetchDescriptor<HeightReading>(predicate: #Predicate { $0.height == h * 100 && $0.date == date })
                        let existing = try? modelContext.fetch(fetchDescriptor)
                        if existing?.isEmpty ?? true {
                            modelContext.insert(HeightReading(height: h * 100, date: date)) // m to cm
                        }
                    }
                }
            }

            // Blood Pressure
            HealthKitManager.shared.fetchAllBloodPressureSamples { samples in
                let filtered: [(Int, Int, Date)]
                if samples.count > 180 {
                    filtered = samples.filter { $0.2 >= ninetyDaysAgo }
                } else {
                    filtered = samples
                }
                DispatchQueue.main.async {
                    for (sys, dia, date) in filtered {
                        let fetchDescriptor = FetchDescriptor<BloodPressureReading>(predicate: #Predicate { $0.systolic == sys && $0.diastolic == dia && $0.date == date })
                        let existing = try? modelContext.fetch(fetchDescriptor)
                        if existing?.isEmpty ?? true {
                            modelContext.insert(BloodPressureReading(systolic: sys, diastolic: dia, date: date))
                        }
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                do {
                    try modelContext.save()
                    refreshID = UUID() // trigger re-render
                    status = "Health data imported ✅"
                } catch {
                    status = "Save failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
