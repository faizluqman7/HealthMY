//
//  AddReadingView.swift
//  HealthMY
//
//  Created by Faiz Luqman on 23/06/2025.
//


import SwiftUI

struct AddReadingView: View {
    @State private var selectedMetric = "Blood Pressure"
    let metricOptions = ["Blood Pressure", "Weight", "Height"]

    var body: some View {
        NavigationView {
            Form {
                Picker("Select Metric", selection: $selectedMetric) {
                    ForEach(metricOptions, id: \.self) { metric in
                        Text(metric)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())

                if selectedMetric == "Blood Pressure" {
                    BPInputView()
                } else if selectedMetric == "Weight" {
                    WeightInputView()
                } else if selectedMetric == "Height" {
                    HeightInputView()
                }
            }
            .navigationTitle("Add Reading")
        }
    }
}