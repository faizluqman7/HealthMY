//
//  EditHeightReadingViewModel.swift
//  HealthMY
//
//  Created by Faiz Luqman on 26/11/2025.
//

import SwiftUI
import SwiftData

@Observable
class EditHeightReadingViewModel {
    private let reading: HeightReading
    
    // View-friendly properties
    var heightText: String {
        didSet {
            // Validate and update model
            if let height = Double(heightText), height > 0 {
                reading.height = height
                validationError = nil
            } else {
                validationError = "Please enter a valid height"
            }
        }
    }
    
    var selectedDate: Date {
        didSet {
            reading.date = selectedDate
        }
    }
    
    var validationError: String?
    var isSaving = false
    
    // Computed properties for view
    var canSave: Bool {
        !heightText.isEmpty && validationError == nil && !isSaving
    }
    
    var displayTitle: String {
        "Edit Height - \(formattedDate)"
    }
    
    private var formattedDate: String {
        selectedDate.formatted(date: .abbreviated, time: .omitted)
    }
    
    init(reading: HeightReading) {
        self.reading = reading
        self.heightText = String(reading.height)
        self.selectedDate = reading.date
    }
    
    // Business logic methods
    func save() async {
        guard canSave else { return }
        
        isSaving = true
        
        // Add any additional business logic here
        // For example: data validation, API calls, etc.
        
        // Since we're using SwiftData, the changes are automatically persisted
        // due to the @Bindable nature of the model
        
        try? await Task.sleep(nanoseconds: 500_000_000) // Simulate network delay
        
        isSaving = false
    }
    
    func validateHeight() {
        guard let height = Double(heightText) else {
            validationError = "Please enter a valid number"
            return
        }
        
        if height <= 0 {
            validationError = "Height must be greater than 0"
        } else if height > 300 {
            validationError = "Height seems unusually high"
        } else {
            validationError = nil
        }
    }
    
    // Computed property for height in different units
    var heightInFeet: String {
        guard let height = Double(heightText) else { return "" }
        let totalInches = height / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\""
    }
}