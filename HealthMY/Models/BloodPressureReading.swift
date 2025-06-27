//
//  BloodPressureReading.swift
//  HealthMY
//
//  Created by Faiz Luqman on 23/06/2025.
//


import SwiftData
import Foundation

@Model
class BloodPressureReading {
    var id: UUID
    var systolic: Int
    var diastolic: Int
    var date: Date

    init(systolic: Int, diastolic: Int, date: Date = .now) {
        self.id = UUID()
        self.systolic = systolic
        self.diastolic = diastolic
        self.date = date
    }
}
