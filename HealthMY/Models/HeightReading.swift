//
//  HeightReading.swift
//  HealthMY
//
//  Created by Faiz Luqman on 23/06/2025.
//

import SwiftData
import Foundation

@Model
class HeightReading {
    var id: UUID
    var height: Double
    var date: Date

    init(height: Double, date: Date = .now) {
        self.id = UUID()
        self.height = height
        self.date = date
    }
}
