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
                            }.frame(height: 200)
                        case "Weight":
                            Chart {
                                ForEach(weightReadings) { reading in
                                    LineMark(
                                        x: .value("Date", reading.date),
                                        y: .value("Weight", reading.weight)
                                    )
                                }
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
                                ForEach(pulseReadings) { reading in
                                    LineMark(
                                        x: .value("Date", reading.date),
                                        y: .value("Pulse", reading.pulse)
                                    )
                                }
                            }.frame(height: 200)
                        case "Sleep Hours":
                            Chart {
                                ForEach(sleepReadings) { reading in
                                    LineMark(
                                        x: .value("Date", reading.date),
                                        y: .value("Sleep Hours", reading.hours)
                                    )
                                }
                            }.frame(height: 200)
                        case "Glucose":
                            Chart {
                                ForEach(glucoseReadings) { reading in
                                    LineMark(
                                        x: .value("Date", reading.date),
                                        y: .value("Glucose", reading.glucose)
                                    )
                                }
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
}