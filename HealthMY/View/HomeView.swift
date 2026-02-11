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
    @Query(sort: \PulseReading.date, order: .reverse, animation: .default) var pulseReadings: [PulseReading]
    @Query(sort: \SleepReading.date, order: .reverse, animation: .default) var sleepReadings: [SleepReading]
    @Query(sort: \GlucoseReading.date, order: .reverse, animation: .default) var glucoseReadings: [GlucoseReading]

    @State private var analysisResult: HealthAnalysisResult?
    @State private var recommendations: [String] = []
    @State private var aiSummary: String = ""
    @State private var heartDiseaseRisk: Double? = nil
    @State private var analyzing = false
    @State private var loadingAI = false
    @State private var errorMessage: String?
    @State private var showGoalSheet = false
    @State private var editingGoal: HealthGoal? = nil
    @State private var dismissedAlerts: Set<String> = []
    @State private var selectedTimeframe: Int = 0

    private var activeGoals: [HealthGoal] {
        goals.filter { $0.isActive }
    }

    private var visibleAlerts: [CorrelationAlert] {
        guard let result = analysisResult else { return [] }
        return result.correlationAlerts.filter { !dismissedAlerts.contains($0.description) }
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

                    // Analysis Results
                    if analyzing {
                        ProgressView("Analyzing health data...")
                    } else if let result = analysisResult {
                        // Score display
                        Text("Wellness Score: \(result.score)")
                            .font(.title2)
                            .foregroundColor(result.score >= 80 ? .green : (result.score >= 60 ? .orange : .red))

                        Text("Status: \(result.status)")
                            .foregroundColor(.secondary)

                        // Data insufficiency message
                        if let msg = result.dataInsufficiencyMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal)
                        }

                        // Per-metric risk badges + trend arrows
                        if !result.metricAnalyses.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Metric Overview")
                                    .font(.headline)
                                ForEach(Array(result.metricAnalyses.keys.sorted()), id: \.self) { key in
                                    if let analysis = result.metricAnalyses[key] {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(colorForRisk(analysis.risk))
                                                .frame(width: 10, height: 10)
                                            Text(displayName(for: key))
                                                .font(.subheadline)
                                                .bold()
                                            if let trend = analysis.trend {
                                                Image(systemName: trendIcon(trend))
                                                    .foregroundColor(trendColor(trend))
                                                    .font(.caption)
                                            }
                                            Spacer()
                                            if let avg = analysis.recentAvg {
                                                Text(String(format: "%.1f", avg))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Text(analysis.message)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }

                        // Health Projections
                        if !result.projections.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Health Projections")
                                    .font(.headline)
                                Picker("Timeframe", selection: $selectedTimeframe) {
                                    Text("1 Week").tag(0)
                                    Text("1 Month").tag(1)
                                    Text("3 Months").tag(2)
                                }
                                .pickerStyle(.segmented)

                                ForEach(Array(result.projections.keys.sorted()), id: \.self) { key in
                                    if let proj = result.projections[key] {
                                        let futureVal = selectedTimeframe == 0 ? proj.oneWeek : (selectedTimeframe == 1 ? proj.oneMonth : proj.threeMonths)
                                        let improving = key == "sleep" ? futureVal >= proj.currentAvg : futureVal <= proj.currentAvg
                                        let stable = abs(futureVal - proj.currentAvg) < 1
                                        HStack {
                                            Text(displayName(for: key))
                                                .font(.subheadline)
                                                .bold()
                                            Spacer()
                                            Text("\(String(format: "%.0f", proj.currentAvg)) → \(String(format: "%.0f", futureVal))")
                                                .font(.subheadline)
                                            Image(systemName: stable ? "arrow.right" : (improving ? "arrow.down.right" : "arrow.up.right"))
                                                .foregroundColor(stable ? .gray : (improving ? .green : .red))
                                                .font(.caption)
                                        }
                                    }
                                }

                                if let ps = result.projectedScores {
                                    let projScore = selectedTimeframe == 0 ? ps.oneWeek : (selectedTimeframe == 1 ? ps.oneMonth : ps.threeMonths)
                                    let projStatus = projScore >= 80 ? "Healthy" : (projScore >= 60 ? "Needs Attention" : "At Risk")
                                    Divider()
                                    HStack {
                                        Text("Projected Score:")
                                            .font(.subheadline).bold()
                                        Spacer()
                                        Text("\(projScore) (\(projStatus))")
                                            .font(.subheadline)
                                            .foregroundColor(projScore >= 80 ? .green : (projScore >= 60 ? .orange : .red))
                                    }
                                    if projScore < result.score {
                                        Text("Your wellness score may decline if current trends continue.")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }

                        // Correlation alerts
                        if !visibleAlerts.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Insights")
                                    .font(.headline)
                                ForEach(visibleAlerts, id: \.description) { alert in
                                    HStack {
                                        Circle()
                                            .fill(colorForRisk(alert.severity))
                                            .frame(width: 8, height: 8)
                                        Text(alert.description)
                                            .font(.caption)
                                        Spacer()
                                        Button(action: { dismissedAlerts.insert(alert.description) }) {
                                            Image(systemName: "xmark")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }

                        // Analysis log
                        if !result.logEntries.isEmpty {
                            DisclosureGroup("Analysis Details") {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(Array(result.logEntries.enumerated()), id: \.offset) { _, entry in
                                        Text(entry)
                                            .font(.caption)
                                            .fontDesign(.monospaced)
                                            .foregroundColor(logColor(for: entry))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }

                        // AI Recommendations section
                        if loadingAI {
                            ProgressView("Getting AI recommendations...")
                        } else if !aiSummary.isEmpty {
                            // Heart Disease Risk Card
                            if let risk = heartDiseaseRisk {
                                let pct = Int(risk * 100)
                                let riskColor: Color = risk < 0.2 ? .green : (risk < 0.5 ? .orange : .red)
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(riskColor)
                                    Text("Heart Disease Risk: \(pct)%")
                                        .font(.headline)
                                        .foregroundColor(riskColor)
                                    Spacer()
                                }
                                .padding()
                                .background(riskColor.opacity(0.1))
                                .cornerRadius(12)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("AI Summary:")
                                    .font(.headline)
                                Text(aiSummary)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }

                            if !recommendations.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Advice:")
                                        .font(.headline)
                                    ForEach(recommendations, id: \.self) { rec in
                                        Text("- \(rec)")
                                            .font(.subheadline)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }

                        // Get AI Recommendations button (Phase 2)
                        Button(action: fetchAIRecommendations) {
                            Text("Get AI Recommendations")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(loadingAI)
                        .padding(.top, 8)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }

                    // Analyze button (Phase 1)
                    Button(action: runLocalAnalysis) {
                        Text("Analyze Health Data")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(analyzing)
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

    // Phase 1: Local ML analysis
    private func runLocalAnalysis() {
        let totalReadings = bpReadings.count + weightReadings.count + pulseReadings.count + sleepReadings.count + glucoseReadings.count
        if totalReadings == 0 {
            errorMessage = "Add at least one health reading first."
            return
        }

        analyzing = true
        errorMessage = nil
        aiSummary = ""
        recommendations = []

        HealthAnalysisService.shared.analyze(
            bp: bpReadings,
            weight: weightReadings,
            height: heightReadings,
            pulse: pulseReadings,
            sleep: sleepReadings,
            glucose: glucoseReadings
        ) { result in
            self.analysisResult = result
            self.analyzing = false
        }
    }

    // Phase 2: Send ML results + readings to backend for AI text
    private func fetchAIRecommendations() {
        guard let result = analysisResult else { return }

        loadingAI = true
        errorMessage = nil

        APIService.shared.sendAllReadings(
            bp: bpReadings,
            weight: weightReadings,
            height: heightReadings,
            pulse: pulseReadings,
            sleep: sleepReadings,
            glucose: glucoseReadings,
            analysisResult: result
        ) { apiResult in
            DispatchQueue.main.async {
                loadingAI = false
                switch apiResult {
                case .success(let advice):
                    self.recommendations = advice.recommendations
                    self.aiSummary = advice.ai_summary
                    self.heartDiseaseRisk = advice.heart_disease_risk
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func colorForRisk(_ risk: MetricRisk) -> Color {
        switch risk {
        case .low: return .green
        case .normal: return .green
        case .elevated: return .orange
        case .high: return .red
        }
    }

    private func trendIcon(_ trend: TrendDirection) -> String {
        switch trend {
        case .improving: return "arrow.down.right"
        case .stable: return "arrow.right"
        case .worsening: return "arrow.up.right"
        }
    }

    private func trendColor(_ trend: TrendDirection) -> Color {
        switch trend {
        case .improving: return .green
        case .stable: return .gray
        case .worsening: return .red
        }
    }

    private func displayName(for key: String) -> String {
        switch key {
        case "bp": return "Blood Pressure"
        case "pulse": return "Pulse"
        case "glucose": return "Glucose"
        case "sleep": return "Sleep"
        case "bmi": return "BMI"
        default: return key.capitalized
        }
    }

    private func logColor(for entry: String) -> Color {
        let lower = entry.lowercased()
        if lower.contains("high") || lower.contains("alert") {
            return .red
        } else if lower.contains("elevated") || lower.contains("worsening") {
            return .orange
        }
        return .secondary
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
