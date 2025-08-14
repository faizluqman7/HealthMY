//
//  HomeView.swift
//  HealthMY
//
//  Created by Faiz Luqman on 23/06/2025.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \HealthGoal.type) var goals: [HealthGoal]
    @Query(sort: \BloodPressureReading.date, order: .reverse, animation: .default) var bpReadings: [BloodPressureReading]
    @Query(sort: \WeightReading.date, order: .reverse, animation: .default) var weightReadings: [WeightReading]
    @Query(sort: \HeightReading.date, order: .reverse, animation: .default) var heightReadings: [HeightReading]

    @State private var score: Int?
    @State private var status: String = ""
    @State private var recommendations: [String] = []
    @State private var aiSummary: String = ""
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var showGoalSheet = false
    @State private var editingGoal: HealthGoal? = nil

    // Computed property for active goals
    private var activeGoals: [HealthGoal] {
        goals.filter { $0.isActive }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text("User Health Summary")
                        .font(.largeTitle)
                        .padding(.top)

                    // Health Goals Section
                    HStack {
                        Text("My Health Goals")
                            .font(.title2)
                            .bold()
                        Spacer()
                        Button(action: { editingGoal = nil; showGoalSheet = true }) {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                        }
                    }
                    .padding(.top)
                    if activeGoals.isEmpty {
                        Text("No goals set. Tap + to add a goal.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(activeGoals) { goal in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(goal.type)
                                            .font(.headline)
                                        if let target = goal.targetValue {
                                            Text("Target: \(target)")
                                                .font(.subheadline)
                                        }
                                        Text(goal.details)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        editingGoal = goal
                                        showGoalSheet = true
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if loading {
                        ProgressView("Analyzing...")
                    } else if let score = score {
                        Text("Wellness Score: \(score)")
                            .font(.title2)
                            .foregroundColor(score >= 80 ? .green : (score >= 60 ? .orange : .red))
                        
                        Text("Status: \(status)")
                            .foregroundColor(.secondary)

                        if !recommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Advice:")
                                    .font(.headline)
                                ForEach(recommendations, id: \.self) { rec in
                                    Text("• \(rec)")
                                        .font(.subheadline)
                                }
                            }
                            .padding(.top)
                        }

                        if !aiSummary.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("AI Summary:")
                                    .font(.headline)
                                    .padding(.top)
                                Text(aiSummary)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }

                    if let error = errorMessage {
                        Text("⚠️ \(error)")
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: generateWellnessScore) {
                        Text("Generate Wellness Score")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.top, 24)
                }
                .padding()
            }
            .navigationTitle("Home")
            .sheet(isPresented: $showGoalSheet, onDismiss: { editingGoal = nil }) {
                GoalEditSheet(goal: Binding(get: { editingGoal }, set: { editingGoal = $0 }))
            }
        }
    }

    private func generateWellnessScore() {
        if bpReadings.isEmpty || weightReadings.isEmpty || heightReadings.isEmpty {
            errorMessage = "Missing one or more required health metrics."
            return
        }

        loading = true
        errorMessage = nil

        APIService.shared.sendAllReadings(
            bp: bpReadings,
            weight: weightReadings,
            height: heightReadings
        ) { result in
            DispatchQueue.main.async {
                loading = false
                switch result {
                case .success(let advice):
                    self.score = advice.score
                    self.status = advice.status
                    self.recommendations = advice.recommendations
                    self.aiSummary = advice.ai_summary
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct GoalEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var goal: HealthGoal?
    @State private var type: String = ""
    @State private var targetValue: String = ""
    @State private var details: String = ""
    @State private var isActive: Bool = true

    let goalTypes = ["Weight", "Blood Pressure", "Sleep", "Pulse", "Glucose", "Other"]

    var body: some View {
        NavigationView {
            Form {
                Picker("Goal Type", selection: $type) {
                    ForEach(goalTypes, id: \.self) { t in
                        Text(t).tag(t)
                    }
                }
                TextField("Target Value (optional)", text: $targetValue)
                    .keyboardType(.decimalPad)
                TextField("Details", text: $details)
                Toggle("Active", isOn: $isActive)
            }
            .navigationTitle(goal == nil ? "Add Goal" : "Edit Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let g = goal {
                            g.type = type
                            g.targetValue = Double(targetValue)
                            g.details = details
                            g.isActive = isActive
                        } else {
                            let newGoal = HealthGoal(type: type, targetValue: Double(targetValue), details: details, isActive: isActive)
                            modelContext.insert(newGoal)
                        }
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let g = goal {
                    type = g.type
                    targetValue = g.targetValue != nil ? String(g.targetValue!) : ""
                    details = g.details
                    isActive = g.isActive
                }
            }
        }
    }
}
