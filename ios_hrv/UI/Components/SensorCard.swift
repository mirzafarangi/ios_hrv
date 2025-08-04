/**
 * SensorCard.swift
 * Sensor connection UI component for HRV iOS App
 * Displays BLE status, sensor info, and connection controls
 */

import SwiftUI

struct SensorCard: View {
    @EnvironmentObject var coreEngine: CoreEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Header
            HStack {
                Image(systemName: "heart.circle.fill")
                    .foregroundColor(.red)
                    .font(.title2)
                
                Text("Polar H10 Sensor")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Connection Status Icon
                Image(systemName: coreEngine.coreState.sensorConnectionState.icon)
                    .foregroundColor(connectionStatusColor)
                    .font(.title3)
            }
            
            // Connection Status
            HStack {
                Text("Status:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(coreEngine.coreState.sensorConnectionState.displayText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(connectionStatusColor)
                
                Spacer()
            }
            
            // Sensor Information (when connected)
            if let sensorInfo = coreEngine.coreState.sensorInfo {
                VStack(alignment: .leading, spacing: 8) {
                    
                    // Device Name
                    HStack {
                        Text("Device:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(sensorInfo.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                    
                    // Device Details
                    HStack(spacing: 16) {
                        
                        // Battery Level
                        if let batteryLevel = sensorInfo.batteryLevel {
                            HStack(spacing: 4) {
                                Image(systemName: sensorInfo.batteryIcon)
                                    .foregroundColor(batteryColor(batteryLevel))
                                    .font(.caption)
                                
                                Text("\(batteryLevel)%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        // Signal Strength
                        if sensorInfo.rssi != nil {
                            HStack(spacing: 4) {
                                Image(systemName: sensorInfo.signalIcon)
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                
                                Text(sensorInfo.signalStrengthText)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(.top, 4)
            }
            
            // Heart Rate Display (when connected and receiving data)
            if coreEngine.coreState.sensorConnectionState.isConnected && coreEngine.coreState.currentHeartRate > 0 {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                    
                    Text("\(coreEngine.coreState.currentHeartRate)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("BPM")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.top, 8)
            }
            
            // Connection Button
            HStack {
                Spacer()
                
                Button(action: {
                    if coreEngine.coreState.sensorConnectionState.isConnected {
                        coreEngine.disconnectSensor()
                    } else {
                        coreEngine.connectSensor()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: buttonIcon)
                            .font(.subheadline)
                        
                        Text(buttonText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(buttonColor)
                    .cornerRadius(8)
                }
                .disabled(coreEngine.coreState.sensorConnectionState == .scanning)
                
                Spacer()
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Computed Properties
    private var connectionStatusColor: Color {
        switch coreEngine.coreState.sensorConnectionState {
        case .connected:
            return .green
        case .scanning, .connecting:
            return .orange
        case .disconnected:
            return .gray
        case .failed:
            return .red
        }
    }
    
    private var buttonText: String {
        switch coreEngine.coreState.sensorConnectionState {
        case .disconnected, .failed:
            return "Connect"
        case .scanning:
            return "Scanning..."
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Disconnect"
        }
    }
    
    private var buttonIcon: String {
        switch coreEngine.coreState.sensorConnectionState {
        case .disconnected, .failed:
            return "bluetooth"
        case .scanning, .connecting:
            return "bluetooth"
        case .connected:
            return "bluetooth.slash"
        }
    }
    
    private var buttonColor: Color {
        switch coreEngine.coreState.sensorConnectionState {
        case .disconnected, .failed:
            return .blue
        case .scanning, .connecting:
            return .orange
        case .connected:
            return .red
        }
    }
    
    private func batteryColor(_ level: Int) -> Color {
        if level > 50 {
            return .green
        } else if level > 25 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        // Disconnected state
        SensorCard()
            .environmentObject({
                let engine = CoreEngine.shared
                engine.coreState.sensorConnectionState = .disconnected
                return engine
            }())
        
        // Connected state with sensor info
        SensorCard()
            .environmentObject({
                let engine = CoreEngine.shared
                engine.coreState.sensorConnectionState = .connected
                engine.coreState.sensorInfo = SensorInfo.mockPolarH10
                engine.coreState.currentHeartRate = 72
                return engine
            }())
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
