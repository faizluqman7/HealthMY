//
//  CommpactHistoryView.swift
//  HealthMY
//
//  Created by Faiz Luqman on 28/06/2025.
//

import SwiftUI
import SwiftData



enum ReadingType: String, CaseIterable, Identifiable {
    case bloodPressure = "Blood Pressure"
    case weight = "Weight"
    case height = "Height"
    case pulse = "Pulse"
    case sleep = "Sleep Hours"
    case glucose = "Glucose"
    case other = "Other"

    var id: String { self.rawValue }
}

struct CompactHistoryView: View {
    @Query(sort: \BloodPressureReading.date, order: .reverse) var bpReadings: [BloodPressureReading]
    @Query(sort: \WeightReading.date, order: .reverse) var weightReadings: [WeightReading]
    @Query(sort: \HeightReading.date, order: .reverse) var heightReadings: [HeightReading]
    @Query(sort: \PulseReading.date, order: .reverse) var pulseReadings: [PulseReading]
    @Query(sort: \SleepReading.date, order: .reverse) var sleepReadings: [SleepReading]
    @Query(sort: \GlucoseReading.date, order: .reverse) var glucoseReadings: [GlucoseReading]
    @Query(sort: \OtherVitalReading.date, order: .reverse) var otherReadings: [OtherVitalReading]

    @State private var selectedType: ReadingType = .bloodPressure

    var body: some View {
        VStack(alignment: .leading) {
            Picker("Reading Type", selection: $selectedType) {
                ForEach(ReadingType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(.horizontal)

            switch selectedType {
            case .bloodPressure:
                ReadingSectionView(title: "Blood Pressure", readings: bpReadings.prefix(5)) {
                    NavigationLink("See All") {
                        FullBPHistoryView(bpReadings: bpReadings)
                    }
                }
            case .weight:
                ReadingSectionView(title: "Weight", readings: weightReadings.prefix(5)) {
                    NavigationLink("See All") {
                        FullWeightHistoryView(weightReadings: weightReadings)
                    }
                }
            case .height:
                ReadingSectionView(title: "Height", readings: heightReadings.prefix(5)) {
                    NavigationLink("See All") {
                        FullHeightHistoryView(heightReadings: heightReadings)
                    }
                }
            case .pulse:
                ReadingSectionView(title: "Pulse", readings: pulseReadings.prefix(5)) {
                        EmptyView()
                }
            case .sleep:
                ReadingSectionView(title: "Sleep Hours", readings: sleepReadings.prefix(5)) {
                        EmptyView()
                }
            case .glucose:
                ReadingSectionView(title: "Glucose", readings: glucoseReadings.prefix(5)) {
                        EmptyView()
                }
            case .other:
                ReadingSectionView(title: "Other", readings: otherReadings.prefix(5)) {
                        EmptyView()
                }
            }
        }
        .navigationTitle("Readings")
    }
}

struct ReadingSectionView<Reading: Identifiable, Content: View>: View {
    var title: String
    var readings: ArraySlice<Reading>
    var footer: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if readings.isEmpty {
                Text("No \(title.lowercased()) readings yet.")
                    .padding(.horizontal)
            } else {
                ForEach(readings) { reading in
                    if let bp = reading as? BloodPressureReading {
                        VStack(alignment: .leading) {
                            Text("Systolic: \(bp.systolic), Diastolic: \(bp.diastolic)")
                            Text(bp.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else if let w = reading as? WeightReading {
                        VStack(alignment: .leading) {
                            Text("Weight: \(String(format: "%.1f", w.weight)) kg")
                            Text(w.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else if let h = reading as? HeightReading {
                        VStack(alignment: .leading) {
                            Text("Height: \(String(format: "%.1f", h.height)) cm")
                            Text(h.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else if let p = reading as? PulseReading {
                        VStack(alignment: .leading) {
                            Text("Pulse: \(p.pulse) bpm")
                            Text(p.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else if let s = reading as? SleepReading {
                        VStack(alignment: .leading) {
                            Text("Sleep: \(String(format: "%.1f", s.hours)) hours")
                            Text(s.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else if let g = reading as? GlucoseReading {
                        VStack(alignment: .leading) {
                            Text("Glucose: \(String(format: "%.1f", g.glucose)) mg/dL")
                            Text(g.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else if let o = reading as? OtherVitalReading {
                        VStack(alignment: .leading) {
                            Text("\(o.name): \(String(format: "%.1f", o.value)) \(o.unit)")
                            Text(o.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    Divider()
                }
                .padding(.horizontal)
            }

            HStack {
                Spacer()
                footer()
                    .font(.caption)
                    .padding(.trailing)
            }
        }
    }
}


//FULL HISGTORY VIEWS

struct FullBPHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    var bpReadings: [BloodPressureReading]
    var body: some View {
        List {
            ForEach(bpReadings) { reading in
                VStack(alignment: .leading) {
                    Text("Systolic: \(reading.systolic), Diastolic: \(reading.diastolic)")
                    Text(reading.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }.onDelete { indexSet in
                for index in indexSet {
                    modelContext.delete(bpReadings[index])
                }
            }
        }
        .navigationTitle("All Blood Pressure Readings")
    }
}

struct FullWeightHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    var weightReadings: [WeightReading]
    var body: some View {
        List {
            ForEach(weightReadings) { reading in
                VStack(alignment: .leading) {
                    Text("Weight: \(reading.weight)")
                    Text(reading.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }.onDelete { indexSet in
                for index in indexSet {
                    modelContext.delete(weightReadings[index])
                }
            }
        }
        .navigationTitle("All Weight Readings")
    }
}

struct FullHeightHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    var heightReadings: [HeightReading]
    var body: some View {
        List {
            ForEach(heightReadings) { reading in
                VStack(alignment: .leading) {
                    Text("height: \(reading.height)")
                    Text(reading.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }.onDelete { indexSet in
                for index in indexSet {
                    modelContext.delete(heightReadings[index])
                }
            }
        }
        .navigationTitle("All Height Readings")
    }
}
