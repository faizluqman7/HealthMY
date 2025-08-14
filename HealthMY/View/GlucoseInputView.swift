import SwiftUI

struct GlucoseInputView: View {
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isFocused: Bool
    @State private var glucose = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Glucose (mg/dL)", text: $glucose)
                .keyboardType(.decimalPad)
                .focused($isFocused)
                .textFieldStyle(.roundedBorder)
            Button(action: {
                saveGlucose()
                isFocused = false
            }) {
                Text("Save Glucose")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.teal)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
    
    private func saveGlucose() {
        guard let g = Double(glucose) else { return }
        let reading = GlucoseReading(glucose: g)
        modelContext.insert(reading)
        try? modelContext.save()
        glucose = ""
    }
} 