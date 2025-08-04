/**
 * Logger.swift
 * Centralized logging utility for HRV iOS App
 * Thread-safe, time-stamped, categorized logging system
 */

import Foundation
import os.log

class Logger {
    
    // MARK: - Singleton
    static let shared = Logger()
    
    // MARK: - Log Categories
    enum Category: String, CaseIterable {
        case bluetooth = "Bluetooth"
        case recording = "Recording"
        case queue = "Queue"
        case api = "API"
        case ui = "UI"
        case core = "Core"
        
        var osLog: OSLog {
            return OSLog(subsystem: "com.hrv.app", category: self.rawValue)
        }
    }
    
    // MARK: - Log Levels
    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        
        var osLogType: OSLogType {
            switch self {
            case .debug:
                return .debug
            case .info:
                return .info
            case .warning:
                return .error
            case .error:
                return .fault
            }
        }
    }
    
    // MARK: - Private Properties
    private let dateFormatter: DateFormatter
    private let queue = DispatchQueue(label: "logger.queue", qos: .utility)
    
    // MARK: - Initialization
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
    }
    
    // MARK: - Public Interface
    func log(_ message: String, category: Category = .core, level: Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let timestamp = self.dateFormatter.string(from: Date())
            let fileName = (file as NSString).lastPathComponent
            let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(category.rawValue)] \(message) (\(fileName):\(line))"
            
            // Log to console
            print(logMessage)
            
            // Log to system log
            os_log("%{public}@", log: category.osLog, type: level.osLogType, logMessage)
            
            // Add to debug messages in CoreEngine (if available)
            DispatchQueue.main.async {
                CoreEngine.shared.coreState.addDebugMessage("[\(category.rawValue)] \(message)")
            }
        }
    }
    
    // MARK: - Convenience Methods
    func debug(_ message: String, category: Category = .core, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .debug, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: Category = .core, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .info, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: Category = .core, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .warning, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: Category = .core, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .error, file: file, function: function, line: line)
    }
}

// MARK: - Global Convenience Functions
func logDebug(_ message: String, category: Logger.Category = .core, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, category: category, file: file, function: function, line: line)
}

func logInfo(_ message: String, category: Logger.Category = .core, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, category: category, file: file, function: function, line: line)
}

func logWarning(_ message: String, category: Logger.Category = .core, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, category: category, file: file, function: function, line: line)
}

func logError(_ message: String, category: Logger.Category = .core, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, category: category, file: file, function: function, line: line)
}
