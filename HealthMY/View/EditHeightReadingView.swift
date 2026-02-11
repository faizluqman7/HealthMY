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
    @State private var viewModel: EditHeightReadingViewModel
    
    init(reading: HeightReading) {
        self.reading = reading
        self._viewModel = State(initialValue: EditHeightReadingViewModel(reading: reading))
    }

    var body: some View {
        Form {
            Section("Edit Height") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Height (cm)", text: $viewModel.heightText)
                        .keyboardType(.decimalPad)
                        .onChange(of: viewModel.heightText) { _ in
                            viewModel.validateHeight()
                        }
                    
                    if !viewModel.heightInFeet.isEmpty {
                        Text("≈ \(viewModel.heightInFeet)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let error = viewModel.validationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                DatePicker("Date", selection: $viewModel.selectedDate, displayedComponents: [.date, .hourAndMinute])
            }

            Button(action: {
                Task {
                    await viewModel.save()
                    dismiss()
                }
            }) {
                HStack {
                    if viewModel.isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text("Save")
                }
            }
            .disabled(!viewModel.canSave)
        }
        .navigationTitle(viewModel.displayTitle)
    }
}