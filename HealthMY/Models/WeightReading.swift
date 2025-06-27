//
//  WeightReading.swift
//  HealthMY
//
//  Created by Faiz Luqman on 23/06/2025.
//
import SwiftData
import Foundation

@Model
class WeightReading {
    var id: UUID
    var weight: Double
    var date: Date

    init(weight: Double, date: Date = .now) {
        self.id = UUID()
        self.weight = weight
        self.date = date
    }
}
