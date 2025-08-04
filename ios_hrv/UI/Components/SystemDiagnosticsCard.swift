/**
 * SystemDiagnosticsCard.swift
 * Professional system diagnostics and logging interface
 * Scientific and software engineering oriented UI
 */

import SwiftUI

struct SystemDiagnosticsCard: View {
    @StateObject private var logger = CoreLogger.shared
    @State private var selectedCategory: LogCategory = .core
    @State private var selectedLevel: LogLevel = .info
    @State private var isExpanded = false
    
    var filteredLogs: [LogEntry] {
        logger.logEntries.filter { entry in
            (selectedCategory == .core || entry.category == selectedCategory) &&
            entry.level >= selectedLevel
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Diagnostics")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 16) {
                        StatusIndicator(
                            label: "Errors",
                            count: logger.errorCount,
                            color: logger.errorCount > 0 ? .red : .gray
                        )
                        
                        StatusIndicator(
                            label: "Warnings",
                            count: logger.warningCount,
                            color: logger.warningCount > 0 ? .orange : .gray
                        )
                        
                        StatusIndicator(
                            label: "Log Entries",
                            count: logger.logEntries.count,
                            color: .blue
                        )
                    }
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            
            if isExpanded {
                Divider()
                
                // Filters
                VStack(alignment: .leading, spacing: 8) {
                    Text("Filters")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 12) {
                        // Category Filter
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Category")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Category", selection: $selectedCategory) {
                                Text("All").tag(LogCategory.core)
                                ForEach(LogCategory.allCases, id: \.self) { category in
                                    if category != .core {
                                        Text(category.rawValue).tag(category)
                                    }
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        // Level Filter
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Level")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Level", selection: $selectedLevel) {
                                ForEach(LogLevel.allCases, id: \.self) { level in
                                    Text(level.rawValue).tag(level)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        Spacer()
                        
                        // Actions
                        HStack(spacing: 8) {
                            Button("Clear") {
                                logger.clearLogs()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                            
                            Button("Export") {
                                // TODO: Implement export functionality
                                let logs = logger.exportLogs()
                                print("EXPORTED LOGS:\n\(logs)")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                Divider()
                
                // Log Entries
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredLogs.suffix(50)) { entry in
                            LogEntryRow(entry: entry)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatusIndicator: View {
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(count)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct LogEntryRow: View {
    let entry: LogEntry
    
    var levelColor: Color {
        switch entry.level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Level Indicator
            Circle()
                .fill(levelColor)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.timestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(entry.level.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(levelColor)
                    
                    Text(entry.category.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                    
                    Spacer()
                }
                
                Text(entry.message)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SystemDiagnosticsCard()
        .padding()
}
