/**
 * CoreLogger.swift
 * Professional logging system for HRV iOS App
 * Scientific and software engineering oriented logging
 */

import Foundation
import os.log

// MARK: - Log Categories
enum LogCategory: String, CaseIterable {
    case authentication = "AUTH"
    case bluetooth = "BLE"
    case recording = "REC"
    case queue = "QUEUE"
    case api = "API"
    case core = "CORE"
    case ui = "UI"
    case error = "ERROR"
    case performance = "PERF"
    case data = "DATA"
}

// MARK: - Log Levels
enum LogLevel: String, CaseIterable, Comparable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        let order: [LogLevel] = [.debug, .info, .warning, .error, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

// MARK: - Core Logger
@MainActor
class CoreLogger: ObservableObject {
    
    // MARK: - Singleton
    static let shared = CoreLogger()
    
    // MARK: - Configuration
    private let minimumLogLevel: LogLevel = .debug
    private let maxLogEntries: Int = 1000
    
    // MARK: - Published State
    @Published var logEntries: [LogEntry] = []
    @Published var errorCount: Int = 0
    @Published var warningCount: Int = 0
    
    // MARK: - Private Properties
    private let osLog = OSLog(subsystem: "com.hrv.ios", category: "CoreEngine")
    private let dateFormatter: DateFormatter
    
    // MARK: - Initialization
    private init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "HH:mm:ss.SSS"
    }
    
    // MARK: - Public Interface
    func log(
        _ message: String,
        category: LogCategory,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level >= minimumLogLevel else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        
        let entry = LogEntry(
            timestamp: timestamp,
            level: level,
            category: category,
            message: message,
            source: "\(fileName):\(line)",
            function: function
        )
        
        // Add to published log entries
        logEntries.append(entry)
        
        // Maintain log size limit
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }
        
        // Update counters
        updateCounters(for: level)
        
        // Output to Xcode console
        outputToConsole(entry)
        
        // Output to system log
        outputToSystemLog(entry)
    }
    
    // MARK: - Convenience Methods
    func debug(_ message: String, category: LogCategory = .core) {
        log(message, category: category, level: .debug)
    }
    
    func info(_ message: String, category: LogCategory = .core) {
        log(message, category: category, level: .info)
    }
    
    func warning(_ message: String, category: LogCategory = .core) {
        log(message, category: category, level: .warning)
    }
    
    func error(_ message: String, category: LogCategory = .error) {
        log(message, category: category, level: .error)
    }
    
    func critical(_ message: String, category: LogCategory = .error) {
        log(message, category: category, level: .critical)
    }
    
    // MARK: - Flow Tracking
    func flowStart(_ operation: String, category: LogCategory = .core) {
        info("FLOW_START: \(operation)", category: category)
    }
    
    func flowStep(_ operation: String, step: String, category: LogCategory = .core) {
        info("FLOW_STEP: \(operation) -> \(step)", category: category)
    }
    
    func flowComplete(_ operation: String, duration: TimeInterval? = nil, category: LogCategory = .core) {
        let durationText = duration.map { String(format: " (%.3fs)", $0) } ?? ""
        info("FLOW_COMPLETE: \(operation)\(durationText)", category: category)
    }
    
    func flowError(_ operation: String, error: String, category: LogCategory = .error) {
        self.error("FLOW_ERROR: \(operation) -> \(error)", category: category)
    }
    
    // MARK: - Log Management
    func clearLogs() {
        logEntries.removeAll()
        errorCount = 0
        warningCount = 0
    }
    
    func exportLogs() -> String {
        return logEntries.map { $0.formatted }.joined(separator: "\n")
    }
    
    // MARK: - Private Methods
    private func updateCounters(for level: LogLevel) {
        switch level {
        case .error, .critical:
            errorCount += 1
        case .warning:
            warningCount += 1
        default:
            break
        }
    }
    
    private func outputToConsole(_ entry: LogEntry) {
        print("[\(entry.timestamp)] [\(entry.level.rawValue)] [\(entry.category.rawValue)] \(entry.message)")
    }
    
    private func outputToSystemLog(_ entry: LogEntry) {
        let osLogType: OSLogType = {
            switch entry.level {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }()
        
        os_log("%{public}@", log: osLog, type: osLogType, entry.formatted)
    }
}

// MARK: - Log Entry Model
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: String
    let level: LogLevel
    let category: LogCategory
    let message: String
    let source: String
    let function: String
    
    var formatted: String {
        "[\(timestamp)] [\(level.rawValue)] [\(category.rawValue)] \(message) (\(source))"
    }
    
    var shortFormatted: String {
        "[\(level.rawValue)] [\(category.rawValue)] \(message)"
    }
}

// MARK: - Global Logging Functions
func logDebug(_ message: String, category: LogCategory = .core) {
    Task { @MainActor in
        CoreLogger.shared.debug(message, category: category)
    }
}

func logInfo(_ message: String, category: LogCategory = .core) {
    Task { @MainActor in
        CoreLogger.shared.info(message, category: category)
    }
}

func logWarning(_ message: String, category: LogCategory = .core) {
    Task { @MainActor in
        CoreLogger.shared.warning(message, category: category)
    }
}

func logError(_ message: String, category: LogCategory = .error) {
    Task { @MainActor in
        CoreLogger.shared.error(message, category: category)
    }
}

func logCritical(_ message: String, category: LogCategory = .error) {
    Task { @MainActor in
        CoreLogger.shared.critical(message, category: category)
    }
}

// MARK: - Flow Tracking Functions
func logFlowStart(_ operation: String, category: LogCategory = .core) {
    Task { @MainActor in
        CoreLogger.shared.flowStart(operation, category: category)
    }
}

func logFlowStep(_ operation: String, step: String, category: LogCategory = .core) {
    Task { @MainActor in
        CoreLogger.shared.flowStep(operation, step: step, category: category)
    }
}

func logFlowComplete(_ operation: String, duration: TimeInterval? = nil, category: LogCategory = .core) {
    Task { @MainActor in
        CoreLogger.shared.flowComplete(operation, duration: duration, category: category)
    }
}

func logFlowError(_ operation: String, error: String, category: LogCategory = .error) {
    Task { @MainActor in
        CoreLogger.shared.flowError(operation, error: error, category: category)
    }
}
