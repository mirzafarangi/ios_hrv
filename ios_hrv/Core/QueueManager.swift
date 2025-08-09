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
        
        print("🗑️ Queue cleared")
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
        
        guard let index = queueItems.firstIndex(where: { $0.status == .pending }) else {
            print("ℹ️ No pending items to upload")
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
                    if let validationReport = response["validation_report"] as? [String: Any] {
                        self.queueItems[index].validationReport = validationReport
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
                    if let validationReport = self.queueItems[index].validationReport,
                       let validationResult = validationReport["validation_result"] as? [String: Any],
                       let isValid = validationResult["is_valid"] as? Bool {
                        logInfo("Validation result: valid=\(isValid)", category: .api)
                    }
                    
                    CoreEvents.shared.emit(.sessionUploadCompleted(sessionId: queueItem.session.id))
                    
                    // Try next item
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { @Sendable [weak self] in
                        self?.uploadNextPendingItem()
                    }
                }
                
            } catch {
                await MainActor.run {
                    // Failure
                    let errorMessage = error.localizedDescription
                    logFlowError("Session Upload", error: errorMessage, category: .api)
                    logError("Upload failed: session_id=\(queueItem.session.id), error=\(errorMessage)", category: .api)
                    
                    if self.queueItems[index].attemptCount >= self.maxRetryAttempts {
                        // Max retries reached
                        self.queueItems[index].status = .failed
                        self.queueItems[index].errorMessage = errorMessage
                        self.queueStatus = .idle
                        
                        CoreEvents.shared.emit(.sessionUploadFailed(sessionId: queueItem.session.id, error: errorMessage))
                        
                    } else {
                        // Retry later
                        self.queueItems[index].status = .pending
                        self.queueStatus = .idle
                        
                        logInfo("Upload retry scheduled: session_id=\(queueItem.session.id), attempt=\(self.queueItems[index].attemptCount)/\(self.maxRetryAttempts)", category: .api)
                        
                        // Schedule retry
                        DispatchQueue.main.asyncAfter(deadline: .now() + self.retryDelay) { @Sendable [weak self] in
                            self?.uploadNextPendingItem()
                        }
                    }
                    
                    self.saveQueueToStorage()
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
