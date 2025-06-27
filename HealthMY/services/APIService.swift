//
//  APIService.swift
//  HealthMY
//
//  Created by Faiz Luqman on 27/06/2025.
//


import Foundation

class APIService {
    static let shared = APIService()
    private let baseURL = "http://192.168.8.139:8000/health" // Replace with actual backend URL

    func postBloodPressure(systolic: Int, diastolic: Int, date: Date) {
        let url = URL(string: "\(baseURL)/bp")!
        let body: [String: Any] = [
            "systolic": systolic,
            "diastolic": diastolic,
            "date": ISO8601DateFormatter().string(from: date)
        ]
        post(to: url, body: body)
    }

    func postWeight(weight: Double, date: Date) {
        let url = URL(string: "\(baseURL)/weight")!
        let body: [String: Any] = [
            "weight": weight,
            "date": ISO8601DateFormatter().string(from: date)
        ]
        post(to: url, body: body)
    }

    func postHeight(height: Double, date: Date) {
        let url = URL(string: "\(baseURL)/height")!
        let body: [String: Any] = [
            "height": height,
            "date": ISO8601DateFormatter().string(from: date)
        ]
        post(to: url, body: body)
    }

    private func post(to url: URL, body: [String: Any]) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request).resume()
    }
}
