/**
 * AuthPersistenceManager.swift
 * Robust authentication persistence for long-duration recordings
 * Prevents session loss during recordings > 2 minutes
 */

import Foundation
import UIKit

@MainActor
class AuthPersistenceManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = AuthPersistenceManager()
    
    // MARK: - Properties
    @Published var isMonitoringActive = false
    @Published var lastCheckTime: Date?
    @Published var sessionStatus: SessionStatus = .unknown
    
    private var sessionMonitorTimer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var isRecordingActive = false
    
    // MARK: - Session Status
    enum SessionStatus {
        case unknown
        case active
        case expiringSoon
        case expired
        case refreshing
    }
    
    private init() {
        print("🛡️ AuthPersistenceManager initialized")
        setupNotifications()
    }
    
    // MARK: - Lifecycle Management
    
    private func setupNotifications() {
        // Monitor app lifecycle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        print("📱 App entering background - maintaining auth session")
        
        // Start background task to keep session alive
        if isRecordingActive {
            startBackgroundTask()
        }
        
        // Increase monitoring frequency in background
        startIntensiveMonitoring()
    }
    
    @objc private func appWillEnterForeground() {
        print("📱 App entering foreground - checking auth status")
        
        // End background task
        endBackgroundTask()
        
        // Check session immediately
        Task {
            await checkAndMaintainSession()
        }
        
        // Resume normal monitoring
        if isRecordingActive {
            startRecordingModeMonitoring()
        }
    }
    
    @objc private func appWillTerminate() {
        print("📱 App terminating - saving session state")
        // Session state is already persisted in UserDefaults by SupabaseAuthService
    }
    
    // MARK: - Recording Mode Support
    
    /// Enable aggressive session monitoring during recording
    func startRecordingModeMonitoring() {
        print("🎙️ Starting recording mode auth monitoring")
        isRecordingActive = true
        isMonitoringActive = true
        
        // Stop any existing timer
        stopMonitoring()
        
        // Start aggressive monitoring - check every 10 seconds during recording
        sessionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAndMaintainSession()
            }
        }
        
        // Do immediate check
        Task {
            await checkAndMaintainSession()
        }
        
        // Start background task preemptively
        startBackgroundTask()
    }
    
    /// Stop recording mode monitoring
    func stopRecordingModeMonitoring() {
        print("🛑 Stopping recording mode auth monitoring")
        isRecordingActive = false
        stopMonitoring()
        endBackgroundTask()
    }
    
    /// Start intensive monitoring (for background mode)
    private func startIntensiveMonitoring() {
        guard isRecordingActive else { return }
        
        print("⚡ Starting intensive background monitoring")
        
        // Stop existing timer
        sessionMonitorTimer?.invalidate()
        
        // Check every 5 seconds in background
        sessionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAndMaintainSession()
            }
        }
    }
    
    /// Stop all monitoring
    private func stopMonitoring() {
        sessionMonitorTimer?.invalidate()
        sessionMonitorTimer = nil
        isMonitoringActive = false
    }
    
    // MARK: - Session Maintenance
    
    /// Core session check and maintenance
    private func checkAndMaintainSession() async {
        lastCheckTime = Date()
        
        let authService = SupabaseAuthService.shared
        
        // Check if we have a session
        guard authService.isAuthenticated else {
            print("⚠️ No active session detected during monitoring")
            sessionStatus = .expired
            
            // Try to recover session
            await attemptSessionRecovery()
            return
        }
        
        // Get the current token (async version)
        let token = await authService.getCurrentAccessToken()
        
        // Check token status
        guard let accessToken = token else {
            print("⚠️ No access token found")
            sessionStatus = .expired
            await attemptSessionRecovery()
            return
        }
        
        // Check if token is expired or expiring soon
        if authService.isJWTExpired(accessToken) {
            print("🔴 Token is expired - attempting recovery")
            sessionStatus = .expired
            await attemptSessionRecovery()
        } else if isTokenExpiringSoon(accessToken, bufferMinutes: 10) {
            print("🟡 Token expiring soon - proactive refresh")
            sessionStatus = .expiringSoon
            await refreshSession()
        } else {
            print("🟢 Session healthy")
            sessionStatus = .active
        }
    }
    
    /// Attempt to recover an expired session
    private func attemptSessionRecovery() async {
        print("🚨 Attempting session recovery...")
        sessionStatus = .refreshing
        
        let authService = SupabaseAuthService.shared
        
        // Try multiple recovery strategies
        
        // 1. Check if we have stored credentials for re-auth
        if let email = UserDefaults.standard.string(forKey: "supabase_user_email"),
           let password = UserDefaults.standard.string(forKey: "supabase_stored_password") {
            print("🔐 Attempting silent re-authentication")
            
            do {
                try await authService.signIn(email: email, password: password)
                print("✅ Session recovered via re-authentication")
                sessionStatus = .active
                return
            } catch {
                print("❌ Re-authentication failed: \(error)")
            }
        }
        
        // 2. Check if refresh token is available (handled internally by auth service)
        if UserDefaults.standard.string(forKey: "supabase_refresh_token") != nil {
            print("🔑 Refresh token available - will be used by auth service")
            // The SupabaseAuthService handles refresh internally
        }
        
        // If all recovery attempts fail, the user will need to log in again
        if !authService.isAuthenticated {
            print("❌ Session recovery failed - user needs to re-authenticate")
            sessionStatus = .expired
        }
    }
    
    /// Proactively refresh session before expiration
    private func refreshSession() async {
        print("🔄 Proactive session refresh")
        sessionStatus = .refreshing
        
        // The SupabaseAuthService handles the actual refresh
        let authService = SupabaseAuthService.shared
        
        // Trigger token check which will initiate refresh if needed
        _ = await authService.getCurrentAccessToken()
        
        // Wait a moment for refresh to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Check result
        if authService.isAuthenticated {
            sessionStatus = .active
            print("✅ Session refreshed successfully")
        } else {
            sessionStatus = .expired
            print("❌ Session refresh failed")
            await attemptSessionRecovery()
        }
    }
    
    /// Check if token is expiring soon
    private func isTokenExpiringSoon(_ token: String, bufferMinutes: Int) -> Bool {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return true }
        
        let payload = parts[1]
        var paddedPayload = payload
        let remainder = payload.count % 4
        if remainder > 0 {
            paddedPayload += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: paddedPayload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return true
        }
        
        let expirationDate = Date(timeIntervalSince1970: exp)
        let bufferTime = TimeInterval(bufferMinutes * 60)
        let expirationThreshold = Date().addingTimeInterval(bufferTime)
        
        return expirationDate <= expirationThreshold
    }
    
    // MARK: - Background Task Management
    
    private func startBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        
        print("🌙 Starting background task for auth persistence")
        
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "AuthPersistence") { [weak self] in
            print("⚠️ Background task expiring")
            self?.endBackgroundTask()
        }
        
        // iOS gives us ~30 seconds of background execution
        // Use it to maintain the session
        Task {
            await performBackgroundSessionMaintenance()
        }
    }
    
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        
        print("🌙 Ending background task")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    private func performBackgroundSessionMaintenance() async {
        print("🔧 Performing background session maintenance")
        
        // Keep checking session while we have background time
        for _ in 0..<5 { // Check 5 times over ~25 seconds
            await checkAndMaintainSession()
            
            // Wait 5 seconds before next check
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            
            // Stop if app comes back to foreground
            if backgroundTask == .invalid {
                break
            }
        }
    }
}

// MARK: - Integration with RecordingManager

extension AuthPersistenceManager {
    /// Call when recording starts
    func recordingDidStart() {
        startRecordingModeMonitoring()
    }
    
    /// Call when recording stops
    func recordingDidStop() {
        stopRecordingModeMonitoring()
    }
}
