import SwiftData
import Foundation

@Model
class HealthGoal {
    var id: UUID
    var type: String // e.g., "Weight", "BP", "Sleep", etc.
    var targetValue: Double?
    var details: String // renamed from description
    var isActive: Bool

    init(type: String, targetValue: Double? = nil, details: String, isActive: Bool = true) {
        self.id = UUID()
        self.type = type
        self.targetValue = targetValue
        self.details = details
        self.isActive = isActive
    }
}
