import SwiftUI

struct OtherVitalInputView: View {
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isFocused: Bool
    @State private var name = ""
    @State private var value = ""
    @State private var unit = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Vital Name", text: $name)
                .textFieldStyle(.roundedBorder)
            TextField("Value", text: $value)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
            TextField("Unit", text: $unit)
                .textFieldStyle(.roundedBorder)
            Button(action: {
                saveOtherVital()
                isFocused = false
            }) {
                Text("Save Vital")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
    
    private func saveOtherVital() {
        guard !name.isEmpty, let v = Double(value), !unit.isEmpty else { return }
        let reading = OtherVitalReading(name: name, value: v, unit: unit)
        modelContext.insert(reading)
        try? modelContext.save()
        name = ""
        value = ""
        unit = ""
    }
} 