//
//  HomeView.swift
//  HealthMY
//
//  Created by Faiz Luqman on 23/06/2025.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("User Health Summary")
                    .font(.largeTitle)
                    .padding()
                
                // Add your metrics summary here
                Text("Wellness Score: 85")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Spacer()
            }
            .navigationTitle("Home")
        }
    }
}
