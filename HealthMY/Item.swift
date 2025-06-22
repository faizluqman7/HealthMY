//
//  Item.swift
//  HealthMY
//
//  Created by Faiz Luqman on 22/06/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
