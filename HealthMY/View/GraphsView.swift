//
//  GraphsView.swift
//  HealthMY
//
//  Created by Faiz Luqman on 28/06/2025.
//


import SwiftUI
import SwiftData
import Charts

struct GraphsView: View {
    @Query(sort: \BloodPressureReading.date) var bpReadings: [BloodPressureReading]
    @Query(sort: \WeightReading.date) var weightReadings: [WeightReading]
    @Query(sort: \HeightReading.date) var heightReadings: [HeightReading]
    @Query(sort: \PulseReading.date) var pulseReadings: [PulseReading]
    @Query(sort: \SleepReading.date) var sleepReadings: [SleepReading]
    @Query(sort: \GlucoseReading.date) var glucoseReadings: [GlucoseReading]
    @Query(sort: \OtherVitalReading.date) var otherReadings: [OtherVitalReading]

    let allVitals = ["Blood Pressure", "Weight", "Height", "Pulse", "Sleep Hours", "Glucose", "Other"]
    @State private var selectedVital: String = "Blood Pressure"

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    Text("General Health Graph")
                        .font(.headline)
                    Chart {
                        ForEach(bpReadings) { reading in
                            LineMark(
                                x: .value("Date", reading.date),
                                y: .value("Systolic", reading.systolic)
                            ).foregroundStyle(.red)
                        }
                        ForEach(weightReadings) { reading in
                            LineMark(
                                x: .value("Date", reading.date),
                                y: .value("Weight", reading.weight)
                            ).foregroundStyle(.green)
                        }
                        ForEach(heightReadings) { reading in
                            LineMark(
                                x: .value("Date", reading.date),
                                y: .value("Height", reading.height)
                            ).foregroundStyle(.orange)
                        }
                        ForEach(pulseReadings) { reading in
                            LineMark(
                                x: .value("Date", reading.date),
                                y: .value("Pulse", reading.pulse)
                            ).foregroundStyle(.purple)
                        }
                        ForEach(sleepReadings) { reading in
                            LineMark(
                                x: .value("Date", reading.date),
                                y: .value("Sleep Hours", reading.hours)
                            ).foregroundStyle(.blue)
                        }
                        ForEach(glucoseReadings) { reading in
                            LineMark(
                                x: .value("Date", reading.date),
                                y: .value("Glucose", reading.glucose)
                            ).foregroundStyle(.pink)
                        }
                        ForEach(otherReadings) { reading in
                            LineMark(
                                x: .value("Date", reading.date),
                                y: .value(reading.name, reading.value)
                            ).foregroundStyle(.gray)
                        }
                    }
                    .frame(height: 200)

                    Picker("Select Vital", selection: $selectedVital) {
                        ForEach(allVitals, id: \.self) { vital in
                            Text(vital).tag(vital)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    Text("\(selectedVital) Graph")
                        .font(.headline)

                    Group {
                        switch selectedVital {
                        case "Blood Pressure":
                            Chart {
                                RectangleMark(yStart: .value("", 0), yEnd: .value("", 90))
                                    .foregroundStyle(.green.opacity(0.08))
                                RectangleMark(yStart: .value("", 125), yEnd: .value("", 135))
                                    .foregroundStyle(.yellow.opacity(0.08))
                                RectangleMark(yStart: .value("", 135), yEnd: .value("", 200))
                                    .foregroundStyle(.red.opacity(0.08))
                                ForEach(bpReadings) { reading in
                                    LineMark(
                                        x: .value("Date", reading.date),
                                        y: .value("Systolic", reading.systolic)
                                    ).foregroundStyle(.red)
                                    LineMark(
                                        x: .value("Date", reading.date),
                                        y: .value("Diastolic", reading.diastolic)
                                    ).foregroundStyle(.blue)
                                }
                                trendLineMark(for: "bp", data: bpReadings.map { ($0.date, Double($0.systolic)) })
                            }.frame(height: 200)
                        case "Weight":
                            Chart {
                                ForEach(weightReadings) { reading in
                                    LineMark(
                                        x: .value("Date", reading.date),
                                        y: .value("Weight", reading.weight)
                                    )
                                }
                                trendLineMark(for: "weight", data: weightReadings.map { ($0.date, $0.weight) })
                            }.frame(height: 200)
                        case "Height":
                            Chart {
                                ForEach(heightReadings) { reading in
                                    LineMark(
                                        x: .value("Date", reading.date),
                                        y: .value("Height", reading.height)
                                    )
                                }
                            }.frame(height: 200)
                        case "Pulse":
                            Chart {
                                RectangleMark(yStart: .value("", 55), yEnd: .value("", 90))
                                    .foregroundStyle(.green.opacity(0.08))
                                RectangleMark(yStart: .value("", 90), yEnd: .value("", 100))
                                    .foregroundStyle(.yellow.opacity(0.08))
                                RectangleMark(yStart: .value("", 100), yEnd: .value("", 150))
                                    .foregroundStyle(.red.opacity(0.08))
                                ForEach(pulseReadings) { reading in
                                    LineMark(
                                        x: .value("Date", reading.date),
                                        y: .value("Pulse", reading.pulse)
                                    )
                                }
                                trendLineMark(for: "pulse", data: pulseReadings.map { ($0.date, Double($0.pulse)) })
                            }.frame(height: 200)
                        case "Sleep Hours":
                            Chart {
                                RectangleMark(yStart: .value("", 6.5), yEnd: .value("", 9.5))
                                    .foregroundStyle(.green.opacity(0.08))
                                RectangleMark(yStart: .value("", 5.5), yEnd: .value("", 6.5))
                                    .foregroundStyle(.yellow.opacity(0.08))
                                RectangleMark(yStart: .value("", 9.5), yEnd: .value("", 10.5))
                                    .foregroundStyle(.yellow.opacity(0.08))
                                ForEach(sleepReadings) { reading in
                                    LineMark(
                                        x: .value("Date", reading.date),
                                        y: .value("Sleep Hours", reading.hours)
                                    )
                                }
                                trendLineMark(for: "sleep", data: sleepReadings.map { ($0.date, $0.hours) })
                            }.frame(height: 200)
                        case "Glucose":
                            Chart {
                                RectangleMark(yStart: .value("", 65), yEnd: .value("", 110))
                                    .foregroundStyle(.green.opacity(0.08))
                                RectangleMark(yStart: .value("", 110), yEnd: .value("", 130))
                                    .foregroundStyle(.yellow.opacity(0.08))
                                RectangleMark(yStart: .value("", 130), yEnd: .value("", 250))
                                    .foregroundStyle(.red.opacity(0.08))
                                ForEach(glucoseReadings) { reading in
                                    LineMark(
                                        x: .value("Date", reading.date),
                                        y: .value("Glucose", reading.glucose)
                                    )
                                }
                                trendLineMark(for: "glucose", data: glucoseReadings.map { ($0.date, $0.glucose) })
                            }.frame(height: 200)
                        case "Other":
                            Chart {
                                ForEach(otherReadings) { reading in
                                    LineMark(
                                        x: .value("Date", reading.date),
                                        y: .value(reading.name, reading.value)
                                    )
                                }
                            }.frame(height: 200)
                        default:
                            EmptyView()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Health Graphs")
        }
    }

    @ChartContentBuilder
    private func trendLineMark(for metricKey: String, data: [(Date, Double)]) -> some ChartContent {
        let sorted = data.sorted { $0.0 < $1.0 }
        if sorted.count >= 2,
           let firstDate = sorted.first?.0,
           let lastDate = sorted.last?.0 {
            let cacheKey = "ml_trendCache_\(metricKey == "bp" ? "bp_systolic" : metricKey)"
            if let dict = UserDefaults.standard.dictionary(forKey: cacheKey),
               let slope = dict["slope"] as? Double {
                let meanY = sorted.map { $0.1 }.reduce(0, +) / Double(sorted.count)
                let totalDays = Double(Calendar.current.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1)
                let startY = meanY - slope * totalDays / 2
                let endY = meanY + slope * totalDays / 2
                // Historical trend line
                LineMark(x: .value("Date", firstDate), y: .value("Trend", startY))
                    .foregroundStyle(.purple.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                LineMark(x: .value("Date", lastDate), y: .value("Trend", endY))
                    .foregroundStyle(.purple.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                // Future projection: extend dashed line +30 days from last data point
                let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: lastDate) ?? lastDate
                let futureY = endY + slope * 30
                LineMark(x: .value("Date", lastDate), y: .value("Projection", endY))
                    .foregroundStyle(.purple.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 5]))
                LineMark(x: .value("Date", futureDate), y: .value("Projection", futureY))
                    .foregroundStyle(.purple.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 5]))
            }
        }
    }
}