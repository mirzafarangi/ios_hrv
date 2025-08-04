/**
 * QueueCard.swift
 * Upload queue UI component for HRV iOS App
 * Displays queue state, errors, and debugging panel for uploads
 */

import SwiftUI

struct QueueCard: View {
    @EnvironmentObject var coreEngine: CoreEngine
    @State private var showingDebugLog = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header
            HStack {
                Image(systemName: coreEngine.coreState.queueStatus.icon)
                    .foregroundColor(queueStatusColor)
                    .font(.title2)
                
                Text("Upload Queue")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Queue Status Badge
                if coreEngine.coreState.hasQueuedItems {
                    Text("\(coreEngine.coreState.queueItemCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(queueStatusColor)
                        .cornerRadius(8)
                }
            }
            
            // Queue Status
            HStack {
                Text("Status:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(coreEngine.coreState.queueStatus.displayText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(queueStatusColor)
                
                Spacer()
            }
            
            // Queue Summary
            if coreEngine.coreState.hasQueuedItems {
                queueSummaryView
            } else {
                emptyQueueView
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                
                // Retry Button
                if coreEngine.coreState.failedQueueItemCount > 0 {
                    Button(action: {
                        coreEngine.retryFailedUploads()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                            
                            Text("Retry Failed")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .cornerRadius(6)
                    }
                }
                
                // Debug Log Button
                Button(action: {
                    showingDebugLog.toggle()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.caption)
                        
                        Text("Debug Log")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
                
                Spacer()
                
                // Clear Queue Button
                if coreEngine.coreState.hasQueuedItems {
                    Button(action: {
                        coreEngine.clearQueue()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.caption)
                            
                            Text("Clear")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .cornerRadius(6)
                    }
                }
            }
            .padding(.top, 8)
            
            // Debug Log Panel
            if showingDebugLog {
                debugLogView
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Queue Summary View
    @ViewBuilder
    private var queueSummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // Queue Stats
            HStack(spacing: 16) {
                
                // Pending Items
                if coreEngine.coreState.queueItems.filter({ $0.status == .pending }).count > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text("\(coreEngine.coreState.queueItems.filter({ $0.status == .pending }).count) pending")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Failed Items
                if coreEngine.coreState.failedQueueItemCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        
                        Text("\(coreEngine.coreState.failedQueueItemCount) failed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Completed Items
                if coreEngine.coreState.queueItems.filter({ $0.status == .completed }).count > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text("\(coreEngine.coreState.queueItems.filter({ $0.status == .completed }).count) completed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Recent Queue Items
            if !coreEngine.coreState.queueItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(coreEngine.coreState.queueItems.prefix(3)), id: \.id) { item in
                        HStack {
                            Image(systemName: item.status.icon)
                                .foregroundColor(queueItemColor(item.status))
                                .font(.caption)
                            
                            Text(item.displayName)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(item.status.displayText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if coreEngine.coreState.queueItemCount > 3 {
                Text("... and \(coreEngine.coreState.queueItemCount - 3) more")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 16)
            }
        }
    }
    
    // MARK: - Empty Queue View
    @ViewBuilder
    private var emptyQueueView: some View {
        HStack {
            Image(systemName: "tray")
                .foregroundColor(.gray)
                .font(.subheadline)
            
            Text("No sessions in queue")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Debug Log View
    @ViewBuilder
    private var debugLogView: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // Debug Header
            HStack {
                Text("Debug Log")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Clear") {
                    coreEngine.coreState.clearDebugMessages()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Debug Messages
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(coreEngine.coreState.debugMessages.suffix(10).enumerated()), id: \.offset) { _, message in
                        Text(message)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxHeight: 120)
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(6)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Computed Properties
    private var queueStatusColor: Color {
        switch coreEngine.coreState.queueStatus {
        case .idle:
            return coreEngine.coreState.failedQueueItemCount > 0 ? .red : .gray
        case .uploading:
            return .blue
        case .retrying:
            return .orange
        case .failed:
            return .red
        }
    }
    
    private func queueItemColor(_ status: QueueItemStatus) -> Color {
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
}

#Preview {
    VStack(spacing: 16) {
        // Empty queue
        QueueCard()
            .environmentObject({
                let engine = CoreEngine.shared
                engine.coreState.queueItems = []
                engine.coreState.queueStatus = .idle
                return engine
            }())
        
        // Queue with items
        QueueCard()
            .environmentObject({
                let engine = CoreEngine.shared
                var items: [QueueItem] = []
                
                // Add some mock queue items (Unified Schema)
                let session1 = Session(userId: "test", tag: "rest", subtag: "rest_single", eventId: 0, duration: 5, rrIntervals: [800, 820])
                var item1 = QueueItem(session: session1)
                item1.status = .completed
                items.append(item1)
                
                let session2 = Session(userId: "test", tag: "sleep", subtag: "sleep_interval_1", eventId: 1001, duration: 10, rrIntervals: [850, 860])
                var item2 = QueueItem(session: session2)
                item2.status = .failed
                item2.errorMessage = "Network error"
                items.append(item2)
                
                engine.coreState.queueItems = items
                engine.coreState.queueStatus = .idle
                engine.coreState.debugMessages = [
                    "[10:30:15] Session queued: abc123",
                    "[10:30:20] Upload started: abc123",
                    "[10:30:25] Upload failed: Network error"
                ]
                return engine
            }())
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
