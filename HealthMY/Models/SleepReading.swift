import SwiftData
import Foundation

@Model
class SleepReading {
    var id: UUID
    var hours: Double
    var date: Date

    init(hours: Double, date: Date = .now) {
        self.id = UUID()
        self.hours = hours
        self.date = date
    }
} 