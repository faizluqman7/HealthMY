//
//  BPInputView.swift
//  HealthMY
//
//  Created by Faiz Luqman on 23/06/2025.
//

import SwiftUI

struct BPInputView: View {
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isFocused: Bool
    
    @State private var systolic = ""
    @State private var diastolic = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Systolic (mmHg)", text: $systolic)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .textFieldStyle(.roundedBorder)
            
            TextField("Diastolic (mmHg)", text: $diastolic)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .textFieldStyle(.roundedBorder)
            
            Button(action: {
                saveReading()
                isFocused = false
            }) {
                Text("Save BP Reading")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
    
    private func saveReading() {
        guard let sys = Int(systolic), let dia = Int(diastolic) else { return }
        let reading = BloodPressureReading(systolic: sys, diastolic: dia)
        modelContext.insert(reading)
        try? modelContext.save()
        systolic = ""
        diastolic = ""
    }
}
