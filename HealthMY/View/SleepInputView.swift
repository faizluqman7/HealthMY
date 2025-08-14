import SwiftUI

struct SleepInputView: View {
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isFocused: Bool
    @State private var hours = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Sleep Hours", text: $hours)
                .keyboardType(.decimalPad)
                .focused($isFocused)
                .textFieldStyle(.roundedBorder)
            Button(action: {
                saveSleep()
                isFocused = false
            }) {
                Text("Save Sleep Hours")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
    
    private func saveSleep() {
        guard let h = Double(hours) else { return }
        let reading = SleepReading(hours: h)
        modelContext.insert(reading)
        try? modelContext.save()
        hours = ""
    }
} 