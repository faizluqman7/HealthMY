//
//  EditHeightReadingView.swift
//  HealthMY
//
//  Created by Faiz Luqman on 27/06/2025.
//


import SwiftUI
import SwiftData

struct EditHeightReadingView: View {
    @Bindable var reading: HeightReading
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Edit Height") {
                TextField("Height (cm)", value: $reading.height, format: .number)
                    .keyboardType(.decimalPad)
                DatePicker("Date", selection: $reading.date, displayedComponents: [.date, .hourAndMinute])
            }

            Button("Save") {
                dismiss()
            }
        }
        .navigationTitle("Edit Height")
    }
}