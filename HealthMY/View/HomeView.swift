//
//  HomeView.swift
//  HealthMY
//
//  Created by Faiz Luqman on 23/06/2025.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \BloodPressureReading.date, order: .reverse, animation: .default) var bpReadings: [BloodPressureReading]
    @Query(sort: \WeightReading.date, order: .reverse, animation: .default) var weightReadings: [WeightReading]
    @Query(sort: \HeightReading.date, order: .reverse, animation: .default) var heightReadings: [HeightReading]

    @State private var score: Int?
    @State private var status: String = ""
    @State private var recommendations: [String] = []
    @State private var aiSummary: String = ""
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text("User Health Summary")
                        .font(.largeTitle)
                        .padding(.top)

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
