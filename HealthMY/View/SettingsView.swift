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
    @State private var logMessages: [String] = []
    @State private var importing = false
    @State private var mlReset = false
    @AppStorage("user_age") private var userAge: Int = 0
    @AppStorage("user_sex") private var userSex: Int = 0
    @State private var ageText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            // Profile section
            VStack(alignment: .leading, spacing: 8) {
                Text("Profile")
                    .font(.headline)
                HStack {
                    Text("Age")
                        .frame(width: 40, alignment: .leading)
                    TextField("Enter age", text: $ageText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                            }
                        }
                        .onChange(of: ageText) { _, newValue in
                            if let val = Int(newValue) { userAge = val }
                        }
                }
                HStack {
                    Text("Sex")
                        .frame(width: 40, alignment: .leading)
                    Picker("Sex", selection: $userSex) {
                        Text("Female").tag(0)
                        Text("Male").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Button("Import from Health") {
                importHealthData()
            }
            .disabled(importing)

            if importing {
                ProgressView("Importing...")
            }

            Button("Reset ML Models") {
                HealthAnalysisService.shared.clearAllModels()
                mlReset = true
            }

            if mlReset {
                Text("ML models reset. Run \"Analyze Health Data\" to retrain.")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            if !logMessages.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(logMessages.enumerated()), id: \.offset) { _, msg in
                            Text(msg)
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Settings")
        .onAppear {
            if userAge > 0 { ageText = String(userAge) }
        }
    }

    private func log(_ msg: String) {
        print("[HealthMY Import] \(msg)")
        DispatchQueue.main.async {
            logMessages.append(msg)
        }
    }

    func importHealthData() {
        importing = true
        logMessages = []
        log("Requesting HealthKit authorization...")

        HealthKitManager.shared.requestAuthorization { success in
            guard success else {
                log("Health access denied")
                DispatchQueue.main.async { importing = false }
                return
            }
            log("Authorization granted")

            let now = Date()
            let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now
            let group = DispatchGroup()
            var totalNew = 0

            // Weight
            group.enter()
            log("Fetching weight samples...")
            HealthKitManager.shared.fetchAllWeightSamples { samples in
                let filtered: [(Double, Date)]
                if samples.count > 180 {
                    filtered = samples.filter { $0.1 >= ninetyDaysAgo }
                } else {
                    filtered = samples
                }
                DispatchQueue.main.async {
                    var newCount = 0
                    var dupCount = 0
                    for (w, date) in filtered {
                        let fetchDescriptor = FetchDescriptor<WeightReading>(predicate: #Predicate { $0.weight == w && $0.date == date })
                        let existing = try? modelContext.fetch(fetchDescriptor)
                        if existing?.isEmpty ?? true {
                            modelContext.insert(WeightReading(weight: w, date: date))
                            newCount += 1
                        } else {
                            dupCount += 1
                        }
                    }
                    totalNew += newCount
                    log("Found \(filtered.count) weight samples, \(newCount) new, \(dupCount) duplicates skipped")
                    group.leave()
                }
            }

            // Height
            group.enter()
            log("Fetching height samples...")
            HealthKitManager.shared.fetchAllHeightSamples { samples in
                let filtered: [(Double, Date)]
                if samples.count > 180 {
                    filtered = samples.filter { $0.1 >= ninetyDaysAgo }
                } else {
                    filtered = samples
                }
                DispatchQueue.main.async {
                    var newCount = 0
                    var dupCount = 0
                    for (h, date) in filtered {
                        let fetchDescriptor = FetchDescriptor<HeightReading>(predicate: #Predicate { $0.height == h * 100 && $0.date == date })
                        let existing = try? modelContext.fetch(fetchDescriptor)
                        if existing?.isEmpty ?? true {
                            modelContext.insert(HeightReading(height: h * 100, date: date))
                            newCount += 1
                        } else {
                            dupCount += 1
                        }
                    }
                    totalNew += newCount
                    log("Found \(filtered.count) height samples, \(newCount) new, \(dupCount) duplicates skipped")
                    group.leave()
                }
            }

            // Blood Pressure
            group.enter()
            log("Fetching blood pressure samples...")
            HealthKitManager.shared.fetchAllBloodPressureSamples { samples in
                let filtered: [(Int, Int, Date)]
                if samples.count > 180 {
                    filtered = samples.filter { $0.2 >= ninetyDaysAgo }
                } else {
                    filtered = samples
                }
                DispatchQueue.main.async {
                    var newCount = 0
                    var dupCount = 0
                    for (sys, dia, date) in filtered {
                        let fetchDescriptor = FetchDescriptor<BloodPressureReading>(predicate: #Predicate { $0.systolic == sys && $0.diastolic == dia && $0.date == date })
                        let existing = try? modelContext.fetch(fetchDescriptor)
                        if existing?.isEmpty ?? true {
                            modelContext.insert(BloodPressureReading(systolic: sys, diastolic: dia, date: date))
                            newCount += 1
                        } else {
                            dupCount += 1
                        }
                    }
                    totalNew += newCount
                    log("Found \(filtered.count) BP samples, \(newCount) new, \(dupCount) duplicates skipped")
                    group.leave()
                }
            }

            // Pulse
            group.enter()
            log("Fetching pulse (heart rate) samples...")
            HealthKitManager.shared.fetchAllPulseSamples { samples in
                let filtered: [(Int, Date)]
                if samples.count > 180 {
                    filtered = samples.filter { $0.1 >= ninetyDaysAgo }
                } else {
                    filtered = samples
                }
                DispatchQueue.main.async {
                    var newCount = 0
                    var dupCount = 0
                    for (p, date) in filtered {
                        let fetchDescriptor = FetchDescriptor<PulseReading>(predicate: #Predicate { $0.pulse == p && $0.date == date })
                        let existing = try? modelContext.fetch(fetchDescriptor)
                        if existing?.isEmpty ?? true {
                            modelContext.insert(PulseReading(pulse: p, date: date))
                            newCount += 1
                        } else {
                            dupCount += 1
                        }
                    }
                    totalNew += newCount
                    log("Found \(filtered.count) pulse samples, \(newCount) new, \(dupCount) duplicates skipped")
                    group.leave()
                }
            }

            // Glucose
            group.enter()
            log("Fetching glucose samples...")
            HealthKitManager.shared.fetchAllGlucoseSamples { samples in
                let filtered: [(Double, Date)]
                if samples.count > 180 {
                    filtered = samples.filter { $0.1 >= ninetyDaysAgo }
                } else {
                    filtered = samples
                }
                DispatchQueue.main.async {
                    var newCount = 0
                    var dupCount = 0
                    for (g, date) in filtered {
                        let fetchDescriptor = FetchDescriptor<GlucoseReading>(predicate: #Predicate { $0.glucose == g && $0.date == date })
                        let existing = try? modelContext.fetch(fetchDescriptor)
                        if existing?.isEmpty ?? true {
                            modelContext.insert(GlucoseReading(glucose: g, date: date))
                            newCount += 1
                        } else {
                            dupCount += 1
                        }
                    }
                    totalNew += newCount
                    log("Found \(filtered.count) glucose samples, \(newCount) new, \(dupCount) duplicates skipped")
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                do {
                    try modelContext.save()
                    refreshID = UUID()
                    log("Import complete. Saved \(totalNew) total new readings.")
                } catch {
                    log("Save failed: \(error.localizedDescription)")
                }
                importing = false
            }
        }
    }
}
