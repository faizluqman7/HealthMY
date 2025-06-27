//
//  EditBPReadingView.swift
//  HealthMY
//
//  Created by Faiz Luqman on 27/06/2025.
//


import SwiftUI
import SwiftData

struct EditBPReadingView: View {
    @Bindable var reading: BloodPressureReading
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Edit BP") {
                TextField("Systolic", value: $reading.systolic, format: .number)
                    .keyboardType(.numberPad)
                TextField("Diastolic", value: $reading.diastolic, format: .number)
                    .keyboardType(.numberPad)
                DatePicker("Date", selection: $reading.date, displayedComponents: [.date, .hourAndMinute])
            }

            Button("Save") {
                dismiss()
            }
        }
        .navigationTitle("Edit BP")
    }
}
