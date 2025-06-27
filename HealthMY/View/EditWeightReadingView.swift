//
//  EditWeightReadingView.swift
//  HealthMY
//
//  Created by Faiz Luqman on 27/06/2025.
//


import SwiftUI
import SwiftData

struct EditWeightReadingView: View {
    @Bindable var reading: WeightReading
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Edit Weight") {
                TextField("Weight (kg)", value: $reading.weight, format: .number)
                    .keyboardType(.decimalPad)
                DatePicker("Date", selection: $reading.date, displayedComponents: [.date, .hourAndMinute])
            }

            Button("Save") {
                dismiss()
            }
        }
        .navigationTitle("Edit Weight")
    }
}