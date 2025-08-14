import SwiftUI

struct PulseInputView: View {
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isFocused: Bool
    @State private var pulse = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Pulse (bpm)", text: $pulse)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .textFieldStyle(.roundedBorder)
            Button(action: {
                savePulse()
                isFocused = false
            }) {
                Text("Save Pulse")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
    
    private func savePulse() {
        guard let p = Int(pulse) else { return }
        let reading = PulseReading(pulse: p)
        modelContext.insert(reading)
        try? modelContext.save()
        pulse = ""
    }
} 