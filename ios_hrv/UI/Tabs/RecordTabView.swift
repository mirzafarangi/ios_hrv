/**
 * RecordTabView.swift
 * Main recording workflow UI for HRV iOS App
 * Hosts sensor, config, recording, and queue cards
 */

import SwiftUI

struct RecordTabView: View {
    @EnvironmentObject var coreEngine: CoreEngine
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Sensor Connection Card
                    SensorCard()
                    
                    // Configuration Card
                    ConfigCard()
                    
                    // Recording Card
                    RecordingCard()
                    
                    // Queue Card
                    QueueCard()
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("HRV Recording")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    RecordTabView()
        .environmentObject(CoreEngine.shared)
}
