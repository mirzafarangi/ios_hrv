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
    // Store only the selected item's ID to avoid stale copies of the struct
    @State private var selectedQueueItemId: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("Upload Queue", systemImage: "arrow.up.circle.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Spacer()
                
                if coreEngine.coreState.queueStatus == .uploading {
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
                            selectedQueueItemId = item.id
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
                
                Button(action: {
                    coreEngine.clearAllFromQueue()
                }) {
                    Label("Clear All", systemImage: "trash.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .disabled(coreEngine.coreState.queueItems.isEmpty)
                
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
                if let liveItem = coreEngine.coreState.queueItems.first(where: { $0.id == selectedQueueItemId }) {
                    // Always show session report for selected items
                    sessionReportView(for: liveItem)
                } else {
                    // Show system logs only when no item is selected
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
                    selectedQueueItemId = nil
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
                                HStack {
                                    Text("Status:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(validationReport.validationResult.isValid ? "✅ Valid" : "❌ Invalid")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                
                                // Show validation errors if present
                                if !validationReport.validationResult.errors.isEmpty {
                                    ForEach(validationReport.validationResult.errors, id: \.self) { error in
                                        Text("❌ \(error)")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                                
                                // Show validation warnings if present
                                if !validationReport.validationResult.warnings.isEmpty {
                                    ForEach(validationReport.validationResult.warnings, id: \.self) { warning in
                                        Text("⚠️ \(warning)")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                                
                                // Session summary info (if available)
                                if let summary = validationReport.sessionSummary {
                                    if let duration = summary["duration_minutes"] as? Int {
                                        HStack {
                                            Text("Duration:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("\(duration) min")
                                                .font(.caption.monospaced())
                                        }
                                    }
                                    if let rrCount = summary["rr_interval_count"] as? Int {
                                        HStack {
                                            Text("RR Count:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("\(rrCount)")
                                                .font(.caption.monospaced())
                                        }
                                    }
                                }
                                
                                // Errors if any
                                if !validationReport.validationResult.errors.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Errors:")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                        ForEach(validationReport.validationResult.errors, id: \.self) { error in
                                            Text("• \(error)")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                
                                // Warnings if any
                                if !validationReport.validationResult.warnings.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Warnings:")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        ForEach(validationReport.validationResult.warnings, id: \.self) { warning in
                                            Text("• \(warning)")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                        } else if item.status == .completed {
                            Text("✅ Successfully uploaded (no validation report)")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else if item.status == .pending {
                            Text("⏳ Pending upload")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else if item.status == .uploading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Uploading...")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        } else {
                            Text("No validation report available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
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
                            
                            if let dbStatus = item.dbStatus {
                                HStack {
                                    Text("Status:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(dbStatus)
                                        .font(.caption.monospaced())
                                        .fontWeight(.medium)
                                        .foregroundColor(dbStatus.lowercased().contains("success") || dbStatus.lowercased().contains("stored") ? .green : .orange)
                                }
                            } else if item.status == .completed {
                                HStack {
                                    Text("Status:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("✅ Stored in database")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                }
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
                            Text("URL: \(APIClient().baseURLString)/api/v1/sessions/upload")
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
        guard let item = coreEngine.coreState.queueItems.first(where: { $0.id == selectedQueueItemId }) else { return }
        
        var report = "=== HRV SESSION REPORT ===\n\n"
        report += "Session ID: \(item.session.id)\n"
        report += "Tag: \(item.session.tag)/\(item.session.subtag)\n"
        report += "Event ID: \(item.session.eventId)\n"
        report += "Duration: \(item.session.duration) min\n"
        report += "RR Count: \(item.session.rrIntervals.count)\n"
        report += "Status: \(item.status.rawValue)\n"
        
        if let validationReport = item.validationReport {
            report += "\n--- VALIDATION ---\n"
            report += "Valid: \(validationReport.validationResult.isValid ? "Yes" : "No")\n"
            
            // Add session summary info if available
            if let summary = validationReport.sessionSummary {
                if let duration = summary["duration_minutes"] as? Int {
                    report += "Duration: \(duration) min\n"
                }
                if let rrCount = summary["rr_interval_count"] as? Int {
                    report += "RR Count: \(rrCount)\n"
                }
            }
            
            if !validationReport.validationResult.errors.isEmpty {
                report += "Errors:\n"
                for error in validationReport.validationResult.errors {
                    report += "  • \(error)\n"
                }
            }
            
            if !validationReport.validationResult.warnings.isEmpty {
                report += "Warnings:\n"
                for warning in validationReport.validationResult.warnings {
                    report += "  • \(warning)\n"
                }
            }
        }
        
        report += "\n--- DATABASE ---\n"
        report += "DB Status: \(item.dbStatus ?? "pending")\n"
        
        report += "\n--- ENDPOINT ---\n"
        report += "API: \(APIClient().baseURLString)/api/v1/sessions/upload\n"
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
        @unknown default:
            return .gray
        }
    }
    
    // MARK: - Computed Properties
    private var queueStatusColor: Color {
        if coreEngine.coreState.hasFailedItems { return .red }
        switch coreEngine.coreState.queueStatus {
        case .uploading: return .blue
        case .retrying: return .yellow
        case .failed: return .red
        case .idle:
            return coreEngine.coreState.hasQueuedItems ? .orange : .green
        }
    }
    
    private var queueStatusText: String {
        let all = coreEngine.coreState.queueItems
        let failed = all.filter { $0.status == .failed }.count
        let uploading = all.filter { $0.status == .uploading }.count
        let pending = all.filter { $0.status == .pending }.count
        if failed > 0 { return "\(failed) failed, \(pending) pending" }
        if coreEngine.coreState.queueStatus == .uploading || uploading > 0 { return "Uploading..." }
        if !all.isEmpty { return "\(pending) pending" }
        return "All uploaded"
    }
}
