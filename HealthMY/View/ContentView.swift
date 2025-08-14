//
//  ContentView.swift
//  HealthMY
//
//  Created by Faiz Luqman on 22/06/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var refreshID = UUID()
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            AddReadingView()
                .id(refreshID)
                .tabItem {
                    Label("Add Reading", systemImage: "plus.circle")
                }
            
//            HistoryView()
//                .id(refreshID)
//                .tabItem {
//                    Label("History", systemImage: "list.bullet")
//                }
            GraphsView().tabItem {
                Label("Graphs", systemImage: "chart.line.uptrend.xyaxis")
            }
            
            SettingsView(refreshID: $refreshID)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
