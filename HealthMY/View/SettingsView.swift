//
//  SettingsView.swift
//  HealthMY
//
//  Created by Faiz Luqman on 23/06/2025.
//

import SwiftUI

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

            // Proceed with fetching and saving only after authorization succeeds
            HealthKitManager.shared.fetchLatestWeight { weight, date in
                if let w = weight, let date = date {
                    DispatchQueue.main.async {
                        modelContext.insert(WeightReading(weight: w, date: date))
                    }
                }
            }

            HealthKitManager.shared.fetchLatestHeight { height, date in
                if let h = height, let date = date {
                    DispatchQueue.main.async {
                        modelContext.insert(HeightReading(height: h * 100, date: date)) // m to cm
                    }
                }
            }

            HealthKitManager.shared.fetchLatestBloodPressure { sys, dia, date in
                if let sys = sys, let dia = dia, let date = date {
                    DispatchQueue.main.async {
                        modelContext.insert(BloodPressureReading(systolic: sys, diastolic: dia, date: date))
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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
