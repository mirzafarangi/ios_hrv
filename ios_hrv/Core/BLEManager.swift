/**
 * BLEManager.swift
 * Bluetooth LE manager for HRV iOS App
 * Handles Polar H10 connection, data streaming, and device info
 */

import Foundation
import CoreBluetooth
import Combine

class BLEManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var sensorInfo: SensorInfo?
    @Published var connectionState: SensorConnectionState = .disconnected
    @Published var currentHeartRate: Int = 0
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var heartRateCharacteristic: CBCharacteristic?
    private var batteryCharacteristic: CBCharacteristic?
    
    // MARK: - Publishers
    private let heartRateSubject = PassthroughSubject<Int, Never>()
    var heartRatePublisher: AnyPublisher<Int, Never> {
        heartRateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Constants
    private struct UUIDs {
        static let heartRateService = CBUUID(string: "180D")
        static let heartRateMeasurement = CBUUID(string: "2A37")
        static let batteryService = CBUUID(string: "180F")
        static let batteryLevel = CBUUID(string: "2A19")
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: DispatchQueue.main,
            options: [CBCentralManagerOptionShowPowerAlertKey: true]
        )
        print("🔧 BLEManager initialized")
    }
    
    // MARK: - Public Interface
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("❌ Bluetooth not ready for scanning")
            return
        }
        
        guard connectionState != .scanning else {
            print("⚠️ Already scanning")
            return
        }
        
        connectionState = .scanning
        centralManager.scanForPeripherals(
            withServices: [UUIDs.heartRateService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        print("🔍 Started scanning for Polar H10...")
        
        // Stop scanning after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.stopScanning()
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        if connectionState == .scanning {
            connectionState = .disconnected
        }
        print("⏹️ Stopped scanning")
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        resetConnection()
    }
    
    // MARK: - Private Methods
    private func resetConnection() {
        connectedPeripheral = nil
        heartRateCharacteristic = nil
        batteryCharacteristic = nil
        sensorInfo = nil
        currentHeartRate = 0
        connectionState = .disconnected
    }
    
    private func connectToPeripheral(_ peripheral: CBPeripheral) {
        stopScanning()
        connectionState = .connecting
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
        
        print("🔗 Connecting to \(peripheral.name ?? "Unknown Device")...")
    }
    
    private func parseHeartRate(from data: Data) -> Int? {
        guard data.count >= 2 else { return nil }
        
        let bytes = [UInt8](data)
        let flags = bytes[0]
        
        // Check if heart rate is 16-bit
        if (flags & 0x01) == 0 {
            // 8-bit heart rate
            return Int(bytes[1])
        } else {
            // 16-bit heart rate
            guard data.count >= 3 else { return nil }
            return Int(bytes[1]) | (Int(bytes[2]) << 8)
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("📡 Bluetooth state: \(central.state.rawValue)")
        
        switch central.state {
        case .poweredOn:
            print("✅ Bluetooth powered on - ready for scanning")
            
        case .poweredOff:
            connectionState = .failed("Bluetooth is turned off")
            
        case .unauthorized:
            connectionState = .failed("Bluetooth access denied")
            
        case .unsupported:
            connectionState = .failed("Bluetooth not supported")
            
        case .resetting:
            print("🔄 Bluetooth is resetting...")
            
        case .unknown:
            print("❓ Bluetooth state unknown")
            
        @unknown default:
            connectionState = .failed("Unknown Bluetooth state")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        guard let name = peripheral.name,
              name.lowercased().contains("polar") && name.lowercased().contains("h10") else {
            return
        }
        
        print("✅ Found Polar H10: \(name) (RSSI: \(RSSI))")
        connectToPeripheral(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to \(peripheral.name ?? "Unknown Device")")
        
        connectionState = .connected
        peripheral.discoverServices([UUIDs.heartRateService, UUIDs.batteryService])
        
        // Create sensor info
        sensorInfo = SensorInfo(
            deviceName: peripheral.name ?? "Unknown Device",
            deviceId: peripheral.identifier.uuidString,
            rssi: nil // Will be updated later
        )
        
        CoreEvents.shared.emit(.sensorConnected(deviceName: peripheral.name ?? "Unknown Device"))
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "Unknown error"
        print("❌ Failed to connect: \(errorMessage)")
        
        connectionState = .failed(errorMessage)
        resetConnection()
        
        CoreEvents.shared.emit(.sensorConnectionFailed(error: errorMessage))
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("🔌 Disconnected from \(peripheral.name ?? "Unknown Device")")
        
        if let error = error {
            print("❌ Disconnection error: \(error.localizedDescription)")
        }
        
        resetConnection()
        CoreEvents.shared.emit(.sensorDisconnected)
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("❌ Service discovery error: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            print("🔍 Discovered service: \(service.uuid)")
            
            if service.uuid == UUIDs.heartRateService {
                peripheral.discoverCharacteristics([UUIDs.heartRateMeasurement], for: service)
            } else if service.uuid == UUIDs.batteryService {
                peripheral.discoverCharacteristics([UUIDs.batteryLevel], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("❌ Characteristic discovery error: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print("🔍 Discovered characteristic: \(characteristic.uuid)")
            
            if characteristic.uuid == UUIDs.heartRateMeasurement {
                heartRateCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                print("✅ Subscribed to heart rate notifications")
                
            } else if characteristic.uuid == UUIDs.batteryLevel {
                batteryCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                print("🔋 Reading battery level")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Characteristic update error: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        if characteristic.uuid == UUIDs.heartRateMeasurement {
            if let heartRate = parseHeartRate(from: data) {
                DispatchQueue.main.async { [weak self] in
                    self?.currentHeartRate = heartRate
                    self?.heartRateSubject.send(heartRate)
                }
            }
            
        } else if characteristic.uuid == UUIDs.batteryLevel {
            let batteryLevel = Int(data[0])
            print("🔋 Battery level: \(batteryLevel)%")
            
            // Update sensor info with battery level
            if let info = sensorInfo {
                sensorInfo = SensorInfo(
                    deviceName: info.deviceName,
                    deviceId: info.deviceId,
                    firmwareVersion: info.firmwareVersion,
                    batteryLevel: batteryLevel,
                    rssi: info.rssi
                )
            }
        }
    }
}
