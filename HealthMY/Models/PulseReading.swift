import SwiftData
import Foundation

@Model
class PulseReading {
    var id: UUID
    var pulse: Int
    var date: Date

    init(pulse: Int, date: Date = .now) {
        self.id = UUID()
        self.pulse = pulse
        self.date = date
    }
} 