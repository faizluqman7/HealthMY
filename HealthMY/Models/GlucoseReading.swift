import SwiftData
import Foundation

@Model
class GlucoseReading {
    var id: UUID
    var glucose: Double
    var date: Date

    init(glucose: Double, date: Date = .now) {
        self.id = UUID()
        self.glucose = glucose
        self.date = date
    }
} 