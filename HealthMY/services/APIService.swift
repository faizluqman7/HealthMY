//
//  APIService.swift
//  HealthMY
//
//  Created by Faiz Luqman on 27/06/2025.
//


import Foundation
import SwiftData

struct BPEntry: Codable {
    let systolic: Int
    let diastolic: Int
    let date: String
}

struct WeightEntry: Codable {
    let weight: Double
    let date: String
}

struct HeightEntry: Codable {
    let height: Double
    let date: String
}

struct PulseEntry: Codable {
    let pulse: Int
    let date: String
}

struct SleepEntry: Codable {
    let hours: Double
    let date: String
}

struct GlucoseEntry: Codable {
    let glucose: Double
    let date: String
}

struct ProjectionEntry: Codable {
    let current_avg: Double
    let one_week: Double
    let one_month: Double
    let three_months: Double
}

struct ProjectedScoresEntry: Codable {
    let one_week: Int
    let one_month: Int
    let three_months: Int
}

struct MLAnalysisPayload: Codable {
    let score: Int
    let status: String
    let metric_risks: [String: String]
    let trends: [String: String]
    let correlation_alerts: [String]
    let projections: [String: ProjectionEntry]?
    let projected_scores: ProjectedScoresEntry?
}

struct HealthInput: Codable {
    let bp: [BPEntry]
    let weight: [WeightEntry]
    let height: [HeightEntry]
    let pulse: [PulseEntry]
    let sleep: [SleepEntry]
    let glucose: [GlucoseEntry]
    let ml_analysis: MLAnalysisPayload?
    let age: Int?
    let sex: Int?
}

struct HealthAdvice: Codable {
    let score: Int
    let status: String
    let recommendations: [String]
    let ai_summary: String
    let heart_disease_risk: Double?
}

class APIService {
    static let shared = APIService()
    private let baseURL = "https://healthmy-backend.vercel.app/health"

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func sendAllReadings(
        bp: [BloodPressureReading],
        weight: [WeightReading],
        height: [HeightReading],
        pulse: [PulseReading] = [],
        sleep: [SleepReading] = [],
        glucose: [GlucoseReading] = [],
        analysisResult: HealthAnalysisResult? = nil,
        completion: @escaping (Result<HealthAdvice, Error>) -> Void
    ) {
        let bpArray = bp.map {
            BPEntry(systolic: $0.systolic, diastolic: $0.diastolic, date: dateFormatter.string(from: $0.date))
        }

        let weightArray = weight.map {
            WeightEntry(weight: $0.weight, date: dateFormatter.string(from: $0.date))
        }

        let heightArray = height.map {
            HeightEntry(height: $0.height, date: dateFormatter.string(from: $0.date))
        }

        let pulseArray = pulse.map {
            PulseEntry(pulse: $0.pulse, date: dateFormatter.string(from: $0.date))
        }

        let sleepArray = sleep.map {
            SleepEntry(hours: $0.hours, date: dateFormatter.string(from: $0.date))
        }

        let glucoseArray = glucose.map {
            GlucoseEntry(glucose: $0.glucose, date: dateFormatter.string(from: $0.date))
        }

        var mlPayload: MLAnalysisPayload? = nil
        if let result = analysisResult {
            let metricRisks = result.metricAnalyses.mapValues { $0.risk.rawValue }
            let trends = result.metricAnalyses.compactMapValues { $0.trend?.rawValue }
            let alerts = result.correlationAlerts.map { $0.description }

            var projEntries: [String: ProjectionEntry]? = nil
            if !result.projections.isEmpty {
                projEntries = result.projections.mapValues {
                    ProjectionEntry(current_avg: $0.currentAvg, one_week: $0.oneWeek, one_month: $0.oneMonth, three_months: $0.threeMonths)
                }
            }

            var projScoresEntry: ProjectedScoresEntry? = nil
            if let ps = result.projectedScores {
                projScoresEntry = ProjectedScoresEntry(one_week: ps.oneWeek, one_month: ps.oneMonth, three_months: ps.threeMonths)
            }

            mlPayload = MLAnalysisPayload(
                score: result.score,
                status: result.status,
                metric_risks: metricRisks,
                trends: trends,
                correlation_alerts: alerts,
                projections: projEntries,
                projected_scores: projScoresEntry
            )
        }

        let storedAge = UserDefaults.standard.integer(forKey: "user_age")
        let storedSex = UserDefaults.standard.integer(forKey: "user_sex")

        let payload = HealthInput(
            bp: bpArray,
            weight: weightArray,
            height: heightArray,
            pulse: pulseArray,
            sleep: sleepArray,
            glucose: glucoseArray,
            ml_analysis: mlPayload,
            age: storedAge > 0 ? storedAge : nil,
            sex: storedAge > 0 ? storedSex : nil
        )

        guard let url = URL(string: "\(baseURL)/summary"),
              let data = try? JSONEncoder().encode(payload) else {
            completion(.failure(NSError(domain: "Encoding error", code: 400)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        performRequest(request, attempt: 0, maxRetries: 3, completion: completion)
    }

    private func performRequest(
        _ request: URLRequest,
        attempt: Int,
        maxRetries: Int,
        completion: @escaping (Result<HealthAdvice, Error>) -> Void
    ) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt + 1)) // 2s, 4s, 8s
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.performRequest(request, attempt: attempt + 1, maxRetries: maxRetries, completion: completion)
                    }
                    return
                }
                completion(.failure(NSError(domain: "HealthMY", code: 429, userInfo: [
                    NSLocalizedDescriptionKey: "Too many requests. Please wait a moment and try again."
                ])))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "Empty response", code: 500)))
                return
            }

            do {
                let result = try JSONDecoder().decode(HealthAdvice.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
