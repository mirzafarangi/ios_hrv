/**
 * MinimalSensorCard.swift
 * Minimal academic-style sensor status display
 * Compact presentation of BLE sensor connection and metrics
 */

import SwiftUI

struct MinimalSensorCard: View {
    @EnvironmentObject var coreEngine: CoreEngine
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact Header Bar
            HStack(spacing: 12) {
                // Status Indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                // Device Name (Full BLE name preserved)
                if let sensorInfo = coreEngine.coreState.sensorInfo {
                    Text(sensorInfo.displayName)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                } else {
                    Text("Polar H10")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Metrics Row
                HStack(spacing: 16) {
                    // Heart Rate
                    if coreEngine.coreState.currentHeartRate > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                            Text("\(coreEngine.coreState.currentHeartRate)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                    }
                    
                    // Battery
                    if let battery = coreEngine.coreState.sensorInfo?.batteryLevel {
                        HStack(spacing: 3) {
                            Image(systemName: batteryIcon(battery))
                                .font(.system(size: 11))
                                .foregroundColor(batteryColor(battery))
                            Text("\(battery)%")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Signal
                    if let rssi = coreEngine.coreState.sensorInfo?.rssi {
                        Image(systemName: signalIcon(rssi))
                            .font(.system(size: 11))
                            .foregroundColor(signalColor(rssi))
                    }
                }
                
                // Action Button
                Button(action: toggleConnection) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 14))
                        .foregroundColor(actionColor)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(actionColor.opacity(0.15))
                        )
                }
                .disabled(isTransitioning)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            // Status Line (only shown during transitions or errors)
            if showStatusLine {
                Divider()
                
                HStack {
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundColor(statusTextColor)
                    
                    Spacer()
                    
                    if isTransitioning {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(statusBackgroundColor)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 0.5)
        )
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        switch coreEngine.coreState.sensorConnectionState {
        case .connected: return .green
        case .scanning, .connecting: return .orange
        case .disconnected: return Color(.systemGray3)
        case .failed: return .red
        }
    }
    
    private var actionIcon: String {
        switch coreEngine.coreState.sensorConnectionState {
        case .connected: return "xmark.circle"
        case .scanning, .connecting: return "stop.circle"
        default: return "play.circle"
        }
    }
    
    private var actionColor: Color {
        switch coreEngine.coreState.sensorConnectionState {
        case .connected: return .red
        case .scanning, .connecting: return .orange
        default: return .blue
        }
    }
    
    private var isTransitioning: Bool {
        switch coreEngine.coreState.sensorConnectionState {
        case .scanning, .connecting: return true
        default: return false
        }
    }
    
    private var showStatusLine: Bool {
        switch coreEngine.coreState.sensorConnectionState {
        case .scanning, .connecting, .failed: return true
        default: return false
        }
    }
    
    private var statusText: String {
        switch coreEngine.coreState.sensorConnectionState {
        case .scanning: return "Scanning for devices..."
        case .connecting: return "Establishing connection..."
        case .failed: return "Connection failed"
        default: return ""
        }
    }
    
    private var statusTextColor: Color {
        switch coreEngine.coreState.sensorConnectionState {
        case .failed: return .red
        default: return .secondary
        }
    }
    
    private var statusBackgroundColor: Color {
        switch coreEngine.coreState.sensorConnectionState {
        case .failed: return Color.red.opacity(0.05)
        default: return Color(.tertiarySystemBackground)
        }
    }
    
    private var borderColor: Color {
        switch coreEngine.coreState.sensorConnectionState {
        case .connected: return Color.green.opacity(0.3)
        case .failed: return Color.red.opacity(0.3)
        default: return Color(.separator).opacity(0.5)
        }
    }
    
    // MARK: - Helper Functions
    
    private func toggleConnection() {
        if coreEngine.coreState.sensorConnectionState.isConnected {
            coreEngine.disconnectSensor()
        } else {
            coreEngine.connectSensor()
        }
    }
    
    private func batteryIcon(_ level: Int) -> String {
        switch level {
        case 75...100: return "battery.100"
        case 50..<75: return "battery.75"
        case 25..<50: return "battery.50"
        case 10..<25: return "battery.25"
        default: return "battery.0"
        }
    }
    
    private func batteryColor(_ level: Int) -> Color {
        switch level {
        case 20...100: return .green
        case 10..<20: return .orange
        default: return .red
        }
    }
    
    private func signalIcon(_ rssi: Int) -> String {
        switch rssi {
        case -50...0: return "wifi.circle.fill"
        case -70..<(-50): return "wifi.circle"
        case -85..<(-70): return "wifi.slash"
        default: return "wifi.exclamationmark"
        }
    }
    
    private func signalColor(_ rssi: Int) -> Color {
        switch rssi {
        case -50...0: return .green
        case -70..<(-50): return .blue
        case -85..<(-70): return .orange
        default: return .red
        }
    }
}

// MARK: - Alternative Ultra-Minimal Version

struct UltraMinimalSensorCard: View {
    @EnvironmentObject var coreEngine: CoreEngine
    
    var body: some View {
        HStack(spacing: 8) {
            // Status dot
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            
            // Device name or status
            Text(displayText)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(textColor)
                .lineLimit(1)
            
            Spacer()
            
            // Live metrics
            if coreEngine.coreState.sensorConnectionState.isConnected {
                if coreEngine.coreState.currentHeartRate > 0 {
                    Text("\(coreEngine.coreState.currentHeartRate) BPM")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.red)
                }
                
                if let battery = coreEngine.coreState.sensorInfo?.batteryLevel {
                    Text("\(battery)%")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            // Toggle button
            Button(action: {
                if coreEngine.coreState.sensorConnectionState.isConnected {
                    coreEngine.disconnectSensor()
                } else {
                    coreEngine.connectSensor()
                }
            }) {
                Image(systemName: buttonIcon)
                    .font(.system(size: 12))
                    .foregroundColor(buttonColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(6)
    }
    
    private var dotColor: Color {
        switch coreEngine.coreState.sensorConnectionState {
        case .connected: return .green
        case .scanning, .connecting: return .orange
        case .disconnected: return .gray
        case .failed: return .red
        }
    }
    
    private var displayText: String {
        if let sensorInfo = coreEngine.coreState.sensorInfo {
            return sensorInfo.displayName
        } else {
            switch coreEngine.coreState.sensorConnectionState {
            case .scanning: return "Scanning..."
            case .connecting: return "Connecting..."
            case .failed: return "Connection Failed"
            default: return "No Sensor"
            }
        }
    }
    
    private var textColor: Color {
        switch coreEngine.coreState.sensorConnectionState {
        case .connected: return .primary
        case .failed: return .red
        default: return .secondary
        }
    }
    
    private var buttonIcon: String {
        coreEngine.coreState.sensorConnectionState.isConnected ? "stop.fill" : "play.fill"
    }
    
    private var buttonColor: Color {
        coreEngine.coreState.sensorConnectionState.isConnected ? .red : .blue
    }
}

#Preview("Minimal Sensor Card") {
    VStack(spacing: 20) {
        Text("Minimal Academic Style")
            .font(.headline)
        
        MinimalSensorCard()
            .environmentObject(CoreEngine.shared)
        
        Text("Ultra-Minimal Style")
            .font(.headline)
            .padding(.top)
        
        UltraMinimalSensorCard()
            .environmentObject(CoreEngine.shared)
    }
    .padding()
    .background(Color(.systemBackground))
}
