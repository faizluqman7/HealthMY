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

struct HealthInput: Codable {
    let bp: [BPEntry]
    let weight: [WeightEntry]
    let height: [HeightEntry]
}

struct HealthAdvice: Codable {
    let score: Int
    let status: String
    let recommendations: [String]
    let ai_summary: String
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

        let payload = HealthInput(bp: bpArray, weight: weightArray, height: heightArray)

        guard let url = URL(string: "\(baseURL)/summary"),
              let data = try? JSONEncoder().encode(payload) else {
            completion(.failure(NSError(domain: "Encoding error", code: 400)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
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
