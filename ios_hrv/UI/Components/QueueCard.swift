/**
 * QueueCard.swift
 * Queue management card for HRV iOS App
 * Displays upload queue status and comprehensive session reports
 */

import SwiftUI

struct QueueCard: View {
    @EnvironmentObject var coreEngine: CoreEngine
    @State private var showingDebugLog = false
    @State private var copiedToClipboard = false
    @State private var selectedQueueItem: QueueItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Upload Queue", systemImage: "arrow.up.circle.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Spacer()
                
                if coreEngine.coreState.isUploading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Queue Status
            HStack {
                Circle()
                    .fill(queueStatusColor)
                    .frame(width: 8, height: 8)
                
                Text(queueStatusText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(queueStatusColor)
                
                Spacer()
            }
            
            // Queue Items
            if coreEngine.coreState.hasQueuedItems {
                ForEach(coreEngine.coreState.queueItems) { item in
                    queueItemRow(item)
                        .onTapGesture {
                            selectedQueueItem = item
                            showingDebugLog = true
                        }
                }
            } else {
                emptyQueueView
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: {
                    coreEngine.retryFailedUploads()
                }) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .disabled(!coreEngine.coreState.hasFailedItems)
                
                Button(action: {
                    coreEngine.clearCompletedFromQueue()
                }) {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .disabled(!coreEngine.coreState.hasCompletedItems)
                
                Spacer()
                
                Button(action: {
                    showingDebugLog.toggle()
                }) {
                    Label("Logs", systemImage: "doc.text.magnifyingglass")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
            
            // Debug Log Panel or Session Report
            if showingDebugLog {
                if let item = selectedQueueItem {
                    sessionReportView(for: item)
                } else {
                    debugLogView
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Session Report View
    private func sessionReportView(for item: QueueItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with close button
            HStack {
                Text("Session Report")
                    .font(.headline)
                Spacer()
                Button(action: {
                    selectedQueueItem = nil
                    showingDebugLog = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 8)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Section 1: API Validation Results
                    VStack(alignment: .leading, spacing: 8) {
                        Label("API Validation", systemImage: "checkmark.shield")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        if let validationReport = item.validationReport {
                            VStack(alignment: .leading, spacing: 4) {
                                // Validation status
                                if let validationResult = validationReport["validation_result"] as? [String: Any] {
                                    HStack {
                                        Text("Status:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(validationResult["is_valid"] as? Bool == true ? "✅ Valid" : "❌ Invalid")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    
                                    // Duration details
                                    if let details = validationResult["details"] as? [String: Any] {
                                        if let durationIOS = details["duration_ios_minutes"] {
                                            HStack {
                                                Text("iOS Duration:")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text("\(durationIOS) min")
                                                    .font(.caption.monospaced())
                                            }
                                        }
                                        if let durationCritical = details["duration_critical_minutes"] {
                                            HStack {
                                                Text("RR Duration:")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text("\(durationCritical) min")
                                                    .font(.caption.monospaced())
                                            }
                                        }
                                        if let diff = details["duration_difference_seconds"] {
                                            HStack {
                                                Text("Difference:")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text("\(diff)s")
                                                    .font(.caption.monospaced())
                                            }
                                        }
                                    }
                                    
                                    // Errors if any
                                    if let errors = validationResult["errors"] as? [String], !errors.isEmpty {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Errors:")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                            ForEach(errors, id: \.self) { error in
                                                Text("• \(error)")
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            Text("No validation report available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                    
                    // Section 2: Database Status
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Database Status", systemImage: "cylinder")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Session ID:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(item.session.id)
                                    .font(.caption.monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            
                            HStack {
                                Text("DB Status:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(item.dbStatus ?? "pending")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(item.dbStatus == "saved" ? .green : .orange)
                            }
                            
                            HStack {
                                Text("Tag/Subtag:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(item.session.tag)/\(item.session.subtag)")
                                    .font(.caption.monospaced())
                            }
                            
                            HStack {
                                Text("Event ID:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(item.session.eventId)")
                                    .font(.caption.monospaced())
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                    
                    // Section 3: iOS Recording Logs
                    VStack(alignment: .leading, spacing: 8) {
                        Label("iOS Logs", systemImage: "doc.text")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recorded: \(formatDate(item.session.recordedAt))")
                                .font(.caption)
                            Text("Duration: \(item.session.duration) min")
                                .font(.caption)
                            Text("RR Count: \(item.session.rrIntervals.count)")
                                .font(.caption)
                            Text("Status: \(item.status.rawValue)")
                                .font(.caption)
                                .foregroundColor(statusColor(for: item.status))
                            if let error = item.errorMessage {
                                Text("Error: \(error)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                    
                    // Section 4: Endpoint Info
                    VStack(alignment: .leading, spacing: 8) {
                        Label("API Endpoint", systemImage: "network")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("URL: \(APIClient.shared.baseURL)/api/v1/sessions/upload")
                                .font(.caption.monospaced())
                            Text("Method: POST")
                                .font(.caption)
                            Text("Content-Type: application/json")
                                .font(.caption)
                        }
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                }
            }
            
            // Copy button
            Button(action: copySessionReport) {
                HStack {
                    Image(systemName: copiedToClipboard ? "checkmark.circle.fill" : "doc.on.doc")
                    Text(copiedToClipboard ? "Copied!" : "Copy Report")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(copiedToClipboard ? Color.green : Color.blue)
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Queue Item Row
    private func queueItemRow(_ item: QueueItem) -> some View {
        HStack {
            Image(systemName: statusIcon(for: item.status))
                .foregroundColor(statusColor(for: item.status))
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                Text("\(item.session.tag)/\(item.session.subtag)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.statusDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if let dbStatus = item.dbStatus {
                    Text(dbStatus)
                        .font(.caption2)
                        .foregroundColor(dbStatus == "saved" ? .green : .orange)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(6)
    }
    
    // MARK: - Empty Queue View
    private var emptyQueueView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundColor(.green.opacity(0.6))
            
            Text("Queue Empty")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("All sessions uploaded")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Debug Log View
    private var debugLogView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("System Logs")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    showingDebugLog = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(coreEngine.coreState.debugLogs.suffix(20), id: \.self) { log in
                        Text(log)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxHeight: 200)
            .padding(8)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(6)
            
            Button(action: copyDebugLogs) {
                HStack {
                    Image(systemName: copiedToClipboard ? "checkmark.circle.fill" : "doc.on.doc")
                    Text(copiedToClipboard ? "Copied!" : "Copy Logs")
                        .fontWeight(.medium)
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(copiedToClipboard ? Color.green : Color.blue)
                .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    private func copySessionReport() {
        guard let item = selectedQueueItem else { return }
        
        var report = "=== HRV SESSION REPORT ===\n\n"
        report += "Session ID: \(item.session.id)\n"
        report += "Tag: \(item.session.tag)/\(item.session.subtag)\n"
        report += "Event ID: \(item.session.eventId)\n"
        report += "Duration: \(item.session.duration) min\n"
        report += "RR Count: \(item.session.rrIntervals.count)\n"
        report += "Status: \(item.status.rawValue)\n"
        
        if let validationReport = item.validationReport,
           let validationResult = validationReport["validation_result"] as? [String: Any] {
            report += "\n--- API VALIDATION ---\n"
            report += "Valid: \(validationResult["is_valid"] as? Bool == true ? "Yes" : "No")\n"
            if let details = validationResult["details"] as? [String: Any] {
                report += "iOS Duration: \(details["duration_ios_minutes"] ?? "N/A") min\n"
                report += "RR Duration: \(details["duration_critical_minutes"] ?? "N/A") min\n"
                report += "Difference: \(details["duration_difference_seconds"] ?? "N/A")s\n"
            }
            if let errors = validationResult["errors"] as? [String], !errors.isEmpty {
                report += "Errors:\n"
                for error in errors {
                    report += "  • \(error)\n"
                }
            }
        }
        
        report += "\n--- DATABASE ---\n"
        report += "DB Status: \(item.dbStatus ?? "pending")\n"
        
        report += "\n--- ENDPOINT ---\n"
        report += "API: \(APIClient.shared.baseURL)/api/v1/sessions/upload\n"
        report += "Method: POST\n"
        
        UIPasteboard.general.string = report
        
        withAnimation {
            copiedToClipboard = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedToClipboard = false
            }
        }
    }
    
    private func copyDebugLogs() {
        let logs = coreEngine.coreState.debugLogs.suffix(50).joined(separator: "\n")
        UIPasteboard.general.string = logs
        
        withAnimation {
            copiedToClipboard = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedToClipboard = false
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func statusIcon(for status: QueueItemStatus) -> String {
        switch status {
        case .pending:
            return "clock"
        case .uploading:
            return "arrow.up.circle"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
    
    private func statusColor(for status: QueueItemStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .uploading:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    // MARK: - Computed Properties
    private var queueStatusColor: Color {
        if coreEngine.coreState.hasFailedItems {
            return .red
        } else if coreEngine.coreState.isUploading {
            return .blue
        } else if coreEngine.coreState.hasQueuedItems {
            return .orange
        } else {
            return .green
        }
    }
    
    private var queueStatusText: String {
        let count = coreEngine.coreState.queueItems.count
        let failed = coreEngine.coreState.queueItems.filter { $0.status == .failed }.count
        
        if failed > 0 {
            return "\(failed) failed, \(count - failed) pending"
        } else if coreEngine.coreState.isUploading {
            return "Uploading..."
        } else if count > 0 {
            return "\(count) items pending"
        } else {
            return "All uploaded"
        }
    }
}
