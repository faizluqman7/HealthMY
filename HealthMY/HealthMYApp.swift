//
//  HealthMYApp.swift
//  HealthMY
//
//  Created by Faiz Luqman on 22/06/2025.
//

import SwiftUI
import SwiftData

@main
struct HealthMYApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [BloodPressureReading.self, WeightReading.self, HeightReading.self])
    }
}
