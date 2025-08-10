/**
 * QueueManager.swift
 * Queue manager for HRV iOS App
 * Implements offline queueing, retry logic, and upload-to-API
 */

import Foundation
import Combine

class QueueManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var queueItems: [QueueItem] = []
    @Published var queueStatus: QueueStatus = .idle
    
    // MARK: - Private Properties
    private let apiClient: APIClient
    private var uploadTimer: Timer?
    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 5.0
    
    // MARK: - Initialization
    init() {
        self.apiClient = APIClient()
        loadQueueFromStorage()
        startPeriodicUpload()
        print("🔧 QueueManager initialized")
    }
    
    deinit {
        uploadTimer?.invalidate()
    }
    
    // MARK: - Public Interface
    func addSession(_ session: Session) {
        let queueItem = QueueItem(session: session)
        queueItems.append(queueItem)
        saveQueueToStorage()
        
        logInfo("Session queued: id=\(session.id), tag=\(session.tag)", category: .queue)
        
        // Try immediate upload
        uploadNextPendingItem()
    }
    
    func retryFailedUploads() {
        print("🔄 Retrying failed uploads...")
        
        for index in queueItems.indices {
            if queueItems[index].status == .failed {
                queueItems[index].status = .pending
                queueItems[index].errorMessage = nil
            }
        }
        
        saveQueueToStorage()
        uploadNextPendingItem()
    }
    
    func clearQueue() {
        queueItems.removeAll()
        saveQueueToStorage()
        queueStatus = .idle
        logInfo("Queue cleared", category: .queue)
    }
    
    func clearCompletedItems() {
        queueItems.removeAll { $0.status == .completed }
        saveQueueToStorage()
        logInfo("Completed items cleared from queue", category: .queue)
    }
    
    func clearAllItems() {
        queueItems.removeAll()
        saveQueueToStorage()
        logInfo("All items cleared from queue (failed, pending, and completed)", category: .queue)
    }
    
    func removeCompletedItems() {
        queueItems.removeAll { $0.status == .completed }
        saveQueueToStorage()
        
        print("🧹 Removed completed items from queue")
    }
    
    // MARK: - Private Methods
    private func startPeriodicUpload() {
        uploadTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.uploadNextPendingItem()
        }
    }
    
    private func uploadNextPendingItem() {
        guard queueStatus == .idle else {
            print("⚠️ Upload already in progress")
            return
        }
        
        // Special handling for sleep intervals - must be uploaded in strict sequential order
        let pendingIndices = queueItems.enumerated().compactMap { index, item in
            item.status == .pending ? index : nil
        }
        
        guard !pendingIndices.isEmpty else {
            print("ℹ️ No pending items to upload")
            return
        }
        
        // Find the next item to upload, prioritizing sleep intervals in order
        var selectedIndex: Int? = nil
        
        // First, check if there are any pending sleep intervals
        let pendingSleepIntervals = pendingIndices.compactMap { index -> (index: Int, intervalNumber: Int)? in
            let item = queueItems[index]
            if item.session.tag == "sleep",
               let match = item.session.subtag.firstMatch(of: /sleep_interval_(\d+)/),
               let intervalNum = Int(match.1) {
                return (index: index, intervalNumber: intervalNum)
            }
            return nil
        }.sorted { $0.intervalNumber < $1.intervalNumber }
        
        if !pendingSleepIntervals.isEmpty {
            // Upload the sleep interval with the lowest interval number
            selectedIndex = pendingSleepIntervals.first?.index
            logInfo("Prioritizing sleep interval upload in sequential order", category: .queue)
        } else {
            // No sleep intervals, upload the first pending item
            selectedIndex = pendingIndices.first
        }
        
        guard let index = selectedIndex else {
            print("ℹ️ No suitable item to upload")
            return
        }
        
        let queueItem = queueItems[index]
        logFlowStart("Session Upload", category: .api)
        logInfo("Upload initiated: session_id=\(queueItem.session.id)", category: .api)
        
        // Update status
        queueItems[index].status = .uploading
        queueItems[index].lastAttemptAt = Date()
        queueItems[index].attemptCount += 1
        queueStatus = .uploading
        
        saveQueueToStorage()
        
        CoreEvents.shared.emit(.sessionUploadStarted(sessionId: queueItem.session.id))
        
        // Perform upload
        Task {
            do {
                let response = try await apiClient.uploadSession(queueItem.session)
                
                await MainActor.run {
                    // Success - extract validation report and DB status from response
                    if let validationReportDict = response["validation_report"] as? [String: Any] {
                        // Parse the simplified validation report from API
                        if let validationResultDict = validationReportDict["validation_result"] as? [String: Any] {
                            
                            let validationResult = ValidationReport.ValidationResult(
                                isValid: validationResultDict["is_valid"] as? Bool ?? true,
                                errors: validationResultDict["errors"] as? [String] ?? [],
                                warnings: validationResultDict["warnings"] as? [String] ?? []
                            )
                            
                            let sessionSummary = validationReportDict["session_summary"] as? [String: Any]
                            
                            self.queueItems[index].validationReport = ValidationReport(
                                validationResult: validationResult,
                                sessionSummary: sessionSummary
                            )
                        }
                    }
                    if let dbStatus = response["db_status"] as? String {
                        self.queueItems[index].dbStatus = dbStatus
                    }
                    
                    self.queueItems[index].status = .completed
                    self.queueStatus = .idle
                    self.saveQueueToStorage()
                    
                    logFlowComplete("Session Upload", category: .api)
                    logInfo("Upload successful: session_id=\(queueItem.session.id), db_status=\(self.queueItems[index].dbStatus ?? "unknown")", category: .api)
                    
                    // Log validation details if available
                    if let validationReport = self.queueItems[index].validationReport {
                        logInfo("Validation result: valid=\(validationReport.validationResult.isValid)", category: .api)
                    }
                    
                    CoreEvents.shared.emit(.sessionUploadCompleted(sessionId: queueItem.session.id))
                    
                    // Try next item
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { @Sendable [weak self] in
                        self?.uploadNextPendingItem()
                    }
                }
                
            } catch {
                await MainActor.run {
                    // Check if this is an out-of-order sleep interval error
                    let errorMessage = error.localizedDescription
                    let isOutOfOrderError = errorMessage.contains("Out-of-order") || 
                                           errorMessage.contains("out-of-order") ||
                                           errorMessage.contains("sequentially")
                    
                    if isOutOfOrderError && queueItem.session.tag == "sleep" {
                        // For out-of-order errors, mark as pending to retry later
                        // This allows earlier intervals to be uploaded first
                        self.queueItems[index].status = .pending
                        self.queueItems[index].errorMessage = "Waiting for previous interval"
                        
                        logInfo("Sleep interval out of order, will retry after previous intervals", category: .queue)
                    } else {
                        // Other failures
                        self.queueItems[index].status = .failed
                        self.queueItems[index].errorMessage = error.localizedDescription
                    }
                    
                    self.queueStatus = .idle
                    self.saveQueueToStorage()
                    
                    CoreEvents.shared.emit(.sessionUploadFailed(sessionId: queueItem.session.id, error: error.localizedDescription))
                    
                    logError("Upload failed: \(error.localizedDescription)", category: .api)
                    logFlowStep("Session Upload", step: "Failed", category: .api)
                    
                    // Continue with next item
                    self.uploadNextPendingItem()
                }
            }
        }
    }
    
    // MARK: - Persistence
    private var queueStorageURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("queue.json")
    }
    
    private func saveQueueToStorage() {
        do {
            let data = try JSONEncoder().encode(queueItems)
            try data.write(to: queueStorageURL)
            logInfo("Queue persisted: items=\(queueItems.count)", category: .queue)
        } catch {
            print("❌ Failed to save queue: \(error.localizedDescription)")
        }
    }
    
    private func loadQueueFromStorage() {
        do {
            let data = try Data(contentsOf: queueStorageURL)
            queueItems = try JSONDecoder().decode([QueueItem].self, from: data)
            print("📂 Queue loaded from storage (\(queueItems.count) items)")
            
            // Reset any items that were uploading when app was terminated
            for index in queueItems.indices {
                if queueItems[index].status == .uploading {
                    queueItems[index].status = .pending
                }
            }
            
        } catch {
            print("ℹ️ No existing queue found or failed to load: \(error.localizedDescription)")
            queueItems = []
        }
    }
    
    // MARK: - Computed Properties
    var pendingItemCount: Int {
        return queueItems.filter { $0.status == .pending }.count
    }
    
    var failedItemCount: Int {
        return queueItems.filter { $0.status == .failed }.count
    }
    
    var completedItemCount: Int {
        return queueItems.filter { $0.status == .completed }.count
    }
    
    var uploadingItemCount: Int {
        return queueItems.filter { $0.status == .uploading }.count
    }
    
    var queueSummary: String {
        let total = queueItems.count
        let pending = pendingItemCount
        let failed = failedItemCount
        let completed = completedItemCount
        
        if total == 0 {
            return "Queue empty"
        } else {
            return "\(total) total • \(pending) pending • \(failed) failed • \(completed) completed"
        }
    }
}
