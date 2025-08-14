import SwiftUI

struct AddReadingView: View {
    @State private var selectedVital: String = "Blood Pressure"
    @State private var favourites: [String] = UserDefaults.standard.stringArray(forKey: "favouriteVitals") ?? ["Blood Pressure", "Weight", "Height"]
    let allVitals = ["Blood Pressure", "Weight", "Height", "Pulse", "Sleep Hours", "Glucose", "Other"]

    private func toggleFavourite(_ vital: String) {
        if let idx = favourites.firstIndex(of: vital) {
            favourites.remove(at: idx)
        } else {
            favourites.append(vital)
        }
        UserDefaults.standard.set(favourites, forKey: "favouriteVitals")
    }

    private func vitalRow(for vital: String) -> some View {
        HStack {
            Text(vital)
            Spacer()
            Button(action: { toggleFavourite(vital) }) {
                Image(systemName: favourites.contains(vital) ? "star.fill" : "star")
                    .foregroundColor(.yellow)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .tag(vital)
    }

    @ViewBuilder
    private var selectedInputView: some View {
        switch selectedVital {
        case "Blood Pressure": BPInputView()
        case "Weight": WeightInputView()
        case "Height": HeightInputView()
        case "Pulse": PulseInputView()
        case "Sleep Hours": SleepInputView()
        case "Glucose": GlucoseInputView()
        case "Other": OtherVitalInputView()
        default: EmptyView()
        }
    }

    private var favouritesSection: some View {
        Group {
            if !favourites.isEmpty {
                Section(header: Text("Favourites")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(favourites, id: \.self) { vital in
                                Button(action: { selectedVital = vital }) {
                                    HStack {
                                        Text(vital)
                                        Image(systemName: selectedVital == vital ? "star.fill" : "star")
                                            .foregroundColor(.yellow)
                                    }
                                    .padding(8)
                                    .background(selectedVital == vital ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var pickerSection: some View {
        Section(header: Text("Add New Reading")) {
            Picker("Select Vital", selection: $selectedVital) {
                ForEach(allVitals, id: \.self) { vital in
                    vitalRow(for: vital)
                }
            }
            .pickerStyle(MenuPickerStyle())
            selectedInputView
        }
    }

    private var historySection: some View {
        Section(header: Text("Readings")) {
            CompactHistoryView()
        }
    }

    var body: some View {
        NavigationView {
            Form {
                favouritesSection
                pickerSection
                historySection
            }
            .navigationTitle("Add Reading")
        }
    }
}
