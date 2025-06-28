//
//  HeightInputView.swift
//  HealthMY
//
//  Created by Faiz Luqman on 23/06/2025.
//

import SwiftUI

struct HeightInputView: View {
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isFocused: Bool
    
    @State private var height = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Height (cm)", text: $height)
                .keyboardType(.decimalPad)
                .focused($isFocused)
                .textFieldStyle(.roundedBorder)
            
            Button(action: {
                saveHeight()
                isFocused = false
            }) {
                Text("Save Height")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
    
    private func saveHeight() {
        guard let h = Double(height) else { return }
        let reading = HeightReading(height: h)
        modelContext.insert(reading)
        try? modelContext.save()
        height = ""
    }
}
