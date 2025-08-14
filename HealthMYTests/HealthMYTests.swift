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
}
