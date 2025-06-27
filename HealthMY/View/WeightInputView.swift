//
//  WeightInputView.swift
//  HealthMY
//
//  Created by Faiz Luqman on 23/06/2025.
//

import SwiftUI

struct WeightInputView: View {
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isFocused: Bool
    
    @State private var weight = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Weight (kg)", text: $weight)
                .keyboardType(.decimalPad)
                .focused($isFocused)
                .textFieldStyle(.roundedBorder)
            
            Button(action: {
                saveWeight()
                isFocused = false
            }) {
                Text("Save Weight")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
    
    private func saveWeight() {
        guard let w = Double(weight) else { return }
        let reading = WeightReading(weight: w)
        modelContext.insert(reading)
        try? modelContext.save()
        weight = ""
    }
}
