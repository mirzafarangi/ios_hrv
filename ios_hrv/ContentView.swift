/**
 * ContentView.swift
 * Main content view for HRV iOS App
 * Clean tab-based navigation with minimal, functional design
 */

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var coreEngine: CoreEngine
    
    var body: some View {
        TabView {
            
            // Record Tab - Main workflow
            RecordTabView()
                .tabItem {
                    Image(systemName: "heart.circle.fill")
                    Text("Record")
                }
            
            // Sessions Tab - Future feature
            Text("Sessions")
                .tabItem {
                    Image(systemName: "list.bullet.circle")
                    Text("Sessions")
                }
            
            // Analysis Tab - Future feature
            Text("Analysis")
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle")
                    Text("Analysis")
                }
            
            // Profile Tab - Future feature
            Text("Profile")
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
        }
        .accentColor(.blue)
    }
}

#Preview {
    ContentView()
        .environmentObject(CoreEngine.shared)
}
