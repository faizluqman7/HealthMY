import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \BloodPressureReading.date, order: .reverse) var bpReadings: [BloodPressureReading]
    @Query(sort: \WeightReading.date, order: .reverse) var weightReadings: [WeightReading]
    @Query(sort: \HeightReading.date, order: .reverse) var heightReadings: [HeightReading]
    
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationView {
            List {
                Section("Blood Pressure Readings") {
                    if bpReadings.isEmpty {
                        Text("No readings yet.")
                    } else {
                        ForEach(bpReadings) { reading in
                            NavigationLink(destination: EditBPReadingView(reading: reading)) {
                                VStack(alignment: .leading) {
                                    Text("Systolic: \(reading.systolic), Diastolic: \(reading.diastolic)")
                                    Text(reading.date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                modelContext.delete(bpReadings[index])
                            }
                        }
                    }
                }

                Section("Weight Readings") {
                    if weightReadings.isEmpty {
                        Text("No readings yet.")
                    } else {
                        ForEach(weightReadings) { reading in
                            NavigationLink(destination: EditWeightReadingView(reading: reading)) {
                                VStack(alignment: .leading) {
                                    Text("Weight: \(String(format: "%.1f", reading.weight)) kg")
                                    Text(reading.date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                modelContext.delete(weightReadings[index])
                            }
                        }
                    }
                }

                Section("Height Readings") {
                    if heightReadings.isEmpty {
                        Text("No readings yet.")
                    } else {
                        ForEach(heightReadings) { reading in
                            NavigationLink(destination: EditHeightReadingView(reading: reading)) {
                                VStack(alignment: .leading) {
                                    Text("Height: \(String(format: "%.1f", reading.height)) cm")
                                    Text(reading.date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                modelContext.delete(heightReadings[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                EditButton()
            }
        }
    }
}
