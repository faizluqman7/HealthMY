import SwiftData
import Foundation

@Model
class OtherVitalReading {
    var id: UUID
    var name: String
    var value: Double
    var unit: String
    var date: Date

    init(name: String, value: Double, unit: String, date: Date = .now) {
        self.id = UUID()
        self.name = name
        self.value = value
        self.unit = unit
        self.date = date
    }
} 