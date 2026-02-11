//
//  HealthMYTests.swift
//  HealthMYTests
//
//  Created by Faiz Luqman on 22/06/2025.
//

import XCTest
@testable import HealthMY

final class APIServiceTests: XCTestCase {
    func testBPEntryEncodingDecoding() throws {
        let entry = BPEntry(systolic: 120, diastolic: 80, date: "2024-06-27T12:00:00Z")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(BPEntry.self, from: data)
        XCTAssertEqual(decoded.systolic, 120)
        XCTAssertEqual(decoded.diastolic, 80)
        XCTAssertEqual(decoded.date, "2024-06-27T12:00:00Z")
    }
    
    func testWeightEntryEncodingDecoding() throws {
        let entry = WeightEntry(weight: 70.5, date: "2024-06-27T12:00:00Z")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(WeightEntry.self, from: data)
        XCTAssertEqual(decoded.weight, 70.5)
        XCTAssertEqual(decoded.date, "2024-06-27T12:00:00Z")
    }
    
    func testHeightEntryEncodingDecoding() throws {
        let entry = HeightEntry(height: 175.0, date: "2024-06-27T12:00:00Z")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(HeightEntry.self, from: data)
        XCTAssertEqual(decoded.height, 175.0)
        XCTAssertEqual(decoded.date, "2024-06-27T12:00:00Z")
    }
    
    func testHealthAdviceEncodingDecoding() throws {
        let advice = HealthAdvice(score: 85, status: "Good", recommendations: ["Keep exercising"], ai_summary: "You are healthy.")
        let data = try JSONEncoder().encode(advice)
        let decoded = try JSONDecoder().decode(HealthAdvice.self, from: data)
        XCTAssertEqual(decoded.score, 85)
        XCTAssertEqual(decoded.status, "Good")
        XCTAssertEqual(decoded.recommendations, ["Keep exercising"])
        XCTAssertEqual(decoded.ai_summary, "You are healthy.")
    }
    
    func testSendAllReadings_RealNetworkCall() {
        // This test will make a real network call to the backend. It will pass if the backend is up and returns a valid HealthAdvice response.
        let expectation = self.expectation(description: "APIService returns HealthAdvice")
        let bp = [BloodPressureReading(systolic: 120, diastolic: 80, date: Date())]
        let weight = [WeightReading(weight: 70.5, date: Date())]
        let height = [HeightReading(height: 175.0, date: Date())]
        
        APIService.shared.sendAllReadings(bp: bp, weight: weight, height: height) { result in
            switch result {
            case .success(let advice):
                XCTAssertGreaterThanOrEqual(advice.score, 0)
                XCTAssertFalse(advice.status.isEmpty)
                XCTAssertNotNil(advice.recommendations)
                XCTAssertNotNil(advice.ai_summary)
            case .failure(let error):
                XCTFail("APIService failed with error: \(error)")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10, handler: nil)
    }

    func testPulseEntryEncodingDecoding() throws {
        let entry = PulseEntry(pulse: 72, date: "2024-06-27T12:00:00Z")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(PulseEntry.self, from: data)
        XCTAssertEqual(decoded.pulse, 72)
        XCTAssertEqual(decoded.date, "2024-06-27T12:00:00Z")
    }

    func testSleepEntryEncodingDecoding() throws {
        let entry = SleepEntry(hours: 7.5, date: "2024-06-27T12:00:00Z")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(SleepEntry.self, from: data)
        XCTAssertEqual(decoded.hours, 7.5)
        XCTAssertEqual(decoded.date, "2024-06-27T12:00:00Z")
    }

    func testGlucoseEntryEncodingDecoding() throws {
        let entry = GlucoseEntry(glucose: 95.0, date: "2024-06-27T12:00:00Z")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(GlucoseEntry.self, from: data)
        XCTAssertEqual(decoded.glucose, 95.0)
        XCTAssertEqual(decoded.date, "2024-06-27T12:00:00Z")
    }

    func testMLAnalysisPayloadEncoding() throws {
        let payload = MLAnalysisPayload(
            score: 85,
            status: "Healthy",
            metric_risks: ["bp": "normal", "pulse": "elevated"],
            trends: ["bp": "improving"],
            correlation_alerts: ["BP and pulse are correlated"],
            projections: nil,
            projected_scores: nil
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(MLAnalysisPayload.self, from: data)
        XCTAssertEqual(decoded.score, 85)
        XCTAssertEqual(decoded.status, "Healthy")
        XCTAssertEqual(decoded.metric_risks["bp"], "normal")
        XCTAssertEqual(decoded.trends["bp"], "improving")
        XCTAssertEqual(decoded.correlation_alerts.count, 1)
    }

    func testHealthInputEncodesAllFields() throws {
        let input = HealthInput(
            bp: [BPEntry(systolic: 120, diastolic: 80, date: "2024-01-01T00:00:00Z")],
            weight: [WeightEntry(weight: 70, date: "2024-01-01T00:00:00Z")],
            height: [HeightEntry(height: 175, date: "2024-01-01T00:00:00Z")],
            pulse: [PulseEntry(pulse: 72, date: "2024-01-01T00:00:00Z")],
            sleep: [SleepEntry(hours: 7.5, date: "2024-01-01T00:00:00Z")],
            glucose: [GlucoseEntry(glucose: 95, date: "2024-01-01T00:00:00Z")],
            ml_analysis: nil
        )
        let data = try JSONEncoder().encode(input)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json?["bp"])
        XCTAssertNotNil(json?["pulse"])
        XCTAssertNotNil(json?["sleep"])
        XCTAssertNotNil(json?["glucose"])
    }
}

final class RuleBasedScoringTests: XCTestCase {
    func testHealthyInputsScoreHigh() throws {
        let result = RuleBasedScoring.shared.scoreReadings(
            bp: [(systolic: 118, diastolic: 75)],
            pulse: [70],
            glucose: [95],
            sleep: [7.5],
            weight: [70],
            height: [175]
        )
        XCTAssertGreaterThanOrEqual(result.score, 90)
        XCTAssertEqual(result.risks["bp"], .normal)
        XCTAssertEqual(result.risks["pulse"], .normal)
        XCTAssertEqual(result.risks["glucose"], .normal)
        XCTAssertEqual(result.risks["sleep"], .normal)
        XCTAssertEqual(result.risks["bmi"], .normal)
    }

    func testUnhealthyInputsScoreLow() throws {
        let result = RuleBasedScoring.shared.scoreReadings(
            bp: [(systolic: 160, diastolic: 100)],
            pulse: [120],
            glucose: [200],
            sleep: [3.0],
            weight: [130],
            height: [165]
        )
        XCTAssertLessThanOrEqual(result.score, 50)
        XCTAssertEqual(result.risks["bp"], .high)
        XCTAssertEqual(result.risks["pulse"], .high)
        XCTAssertEqual(result.risks["glucose"], .high)
        XCTAssertEqual(result.risks["sleep"], .high)
        XCTAssertEqual(result.risks["bmi"], .high)
    }

    func testMissingMetricsAdjustWeights() throws {
        let resultFull = RuleBasedScoring.shared.scoreReadings(
            bp: [(systolic: 118, diastolic: 75)],
            pulse: [70],
            glucose: [95],
            sleep: [7.5],
            weight: [70],
            height: [175]
        )
        let resultPartial = RuleBasedScoring.shared.scoreReadings(
            bp: [(systolic: 118, diastolic: 75)],
            pulse: [],
            glucose: [],
            sleep: [],
            weight: [],
            height: []
        )
        // Both should score high since BP is healthy
        XCTAssertGreaterThanOrEqual(resultFull.score, 90)
        XCTAssertGreaterThanOrEqual(resultPartial.score, 90)
    }

    func testEmptyInputsReturnDefault() throws {
        let result = RuleBasedScoring.shared.scoreReadings(
            bp: [],
            pulse: [],
            glucose: [],
            sleep: [],
            weight: [],
            height: []
        )
        XCTAssertEqual(result.score, 50)
    }
}
