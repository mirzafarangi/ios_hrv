/**
 * SensorInfo.swift
 * BLE device information model for HRV iOS App
 * Used in UI and CoreState for sensor display
 */

import Foundation

struct SensorInfo: Codable, Equatable {
    
    // MARK: - Properties
    let deviceName: String
    let deviceId: String
    let firmwareVersion: String?
    let batteryLevel: Int? // 0-100
    let rssi: Int? // Signal strength
    
    // MARK: - Computed Properties
    var displayName: String {
        return deviceName.isEmpty ? "Unknown Device" : deviceName
    }
    
    var batteryDisplayText: String {
        guard let battery = batteryLevel else { return "Unknown" }
        return "\(battery)%"
    }
    
    var signalStrengthText: String {
        guard let rssi = rssi else { return "Unknown" }
        
        if rssi >= -50 {
            return "Excellent"
        } else if rssi >= -60 {
            return "Good"
        } else if rssi >= -70 {
            return "Fair"
        } else {
            return "Poor"
        }
    }
    
    var batteryIcon: String {
        guard let battery = batteryLevel else { return "battery.0" }
        
        if battery >= 75 {
            return "battery.100"
        } else if battery >= 50 {
            return "battery.75"
        } else if battery >= 25 {
            return "battery.25"
        } else {
            return "battery.0"
        }
    }
    
    var signalIcon: String {
        guard let rssi = rssi else { return "wifi.slash" }
        
        if rssi >= -50 {
            return "wifi"
        } else if rssi >= -60 {
            return "wifi"
        } else if rssi >= -70 {
            return "wifi"
        } else {
            return "wifi.slash"
        }
    }
    
    // MARK: - Initialization
    init(
        deviceName: String,
        deviceId: String,
        firmwareVersion: String? = nil,
        batteryLevel: Int? = nil,
        rssi: Int? = nil
    ) {
        self.deviceName = deviceName
        self.deviceId = deviceId
        self.firmwareVersion = firmwareVersion
        self.batteryLevel = batteryLevel
        self.rssi = rssi
    }
    
    // MARK: - Display Helpers
    var statusSummary: String {
        var components: [String] = []
        
        if let battery = batteryLevel {
            components.append("Battery: \(battery)%")
        }
        
        if let firmware = firmwareVersion {
            components.append("FW: \(firmware)")
        }
        
        if rssi != nil {
            components.append("Signal: \(signalStrengthText)")
        }
        
        return components.isEmpty ? "No details available" : components.joined(separator: " • ")
    }
    
    // MARK: - Mock Data (for testing)
    static let mockPolarH10 = SensorInfo(
        deviceName: "Polar H10 ABC123",
        deviceId: "ABC123",
        firmwareVersion: "3.0.35",
        batteryLevel: 85,
        rssi: -45
    )
    
    static let mockLowBattery = SensorInfo(
        deviceName: "Polar H10 DEF456",
        deviceId: "DEF456",
        firmwareVersion: "3.0.35",
        batteryLevel: 15,
        rssi: -65
    )
}
