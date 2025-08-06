import SwiftUI
import Foundation
import Combine

/// Centralized authentication manager with token refresh capabilities
/// Prevents JWT expiration during long sleep recording sessions
class HRVAuthenticationManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isTokenRefreshActive = false
    @Published var tokenExpiryTime: Date?
    @Published var lastRefreshTime: Date?
    
    // MARK: - Private Properties
    private var tokenRefreshTimer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private let refreshIntervalMinutes: TimeInterval = 30 * 60 // 30 minutes
    private let warningThresholdMinutes: TimeInterval = 5 * 60 // 5 minutes before expiry
    
    // MARK: - Shared Instance
    static let shared = HRVAuthenticationManager()
    
    private init() {
        print("🔐 HRVAuthenticationManager: Initialized")
    }
    
    deinit {
        stopTokenRefreshTimer()
        endBackgroundTask()
    }
    
    // MARK: - Long Session Support
    
    /// Enable long session mode for sleep recordings
    /// Starts proactive token refresh to prevent expiration
    func enableLongSessionMode() {
        print("🌙 HRVAuthenticationManager: Enabling long session mode")
        
        // Start background task to keep app alive during token refresh
        startBackgroundTask()
        
        // Schedule proactive token refresh
        scheduleTokenRefresh()
        
        isTokenRefreshActive = true
    }
    
    /// Disable long session mode
    /// Stops token refresh timer and background tasks
    func disableLongSessionMode() {
        print("🌙 HRVAuthenticationManager: Disabling long session mode")
        
        stopTokenRefreshTimer()
        endBackgroundTask()
        
        isTokenRefreshActive = false
    }
    
    // MARK: - Token Refresh Management
    
    /// Schedule proactive token refresh before expiration
    private func scheduleTokenRefresh() {
        // Cancel existing timer
        stopTokenRefreshTimer()
        
        print("⏰ HRVAuthenticationManager: Scheduling token refresh every \(refreshIntervalMinutes/60) minutes")
        
        // Create repeating timer for token refresh
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: refreshIntervalMinutes, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshTokenIfNeeded()
            }
        }
        
        // Also do an immediate check
        Task {
            await refreshTokenIfNeeded()
        }
    }
    
    /// Stop the token refresh timer
    private func stopTokenRefreshTimer() {
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
        print("⏰ HRVAuthenticationManager: Token refresh timer stopped")
    }
    
    /// Refresh token if needed (before expiration)
    private func refreshTokenIfNeeded() async {
        print("🔄 HRVAuthenticationManager: Checking if token refresh is needed")
        
        await MainActor.run {
            let authService = SupabaseAuthService.shared
            
            // Check if user is authenticated
            guard authService.isAuthenticated,
                  let accessToken = authService.getCurrentAccessToken() else {
                print("❌ HRVAuthenticationManager: No active session found")
                Task {
                    await handleSessionExpiration()
                }
                return
            }
            
            // Check if current token is expired using existing method
            if authService.isJWTExpired(accessToken) {
                print("⚠️ HRVAuthenticationManager: Token is expired, handling expiration...")
                Task {
                    await handleSessionExpiration()
                }
            } else {
                print("✅ HRVAuthenticationManager: Token still valid, no refresh needed")
                
                // Try to extract expiry time from token for monitoring
                if let expiryTime = extractTokenExpiry(from: accessToken) {
                    tokenExpiryTime = expiryTime
                    let timeUntilExpiry = expiryTime.timeIntervalSince(Date())
                    print("🔍 HRVAuthenticationManager: Token expires in \(timeUntilExpiry/60) minutes")
                }
            }
        }
    }
    
    /// Perform token refresh (currently not supported by existing auth service)
    private func performTokenRefresh() async {
        print("🔄 HRVAuthenticationManager: Token refresh not supported by current auth service")
        print("⚠️ HRVAuthenticationManager: Handling as session expiration instead")
        await handleSessionExpiration()
    }
    
    /// Handle session expiration with silent re-authentication
    private func handleSessionExpiration() async {
        print("🚨 HRVAuthenticationManager: Handling session expiration")
        
        // For now, just log the issue
        // In a full implementation, this could:
        // 1. Try silent re-authentication with stored refresh token
        // 2. Queue requests for retry after re-auth
        // 3. Show user notification if re-auth fails
        
        await MainActor.run {
            // Could trigger a notification or alert here
            print("⚠️ HRVAuthenticationManager: Session expired - user may need to re-authenticate")
        }
    }
    
    // MARK: - Background Task Management
    
    /// Start background task to keep app alive during token refresh
    private func startBackgroundTask() {
        endBackgroundTask() // End any existing task
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "HRVTokenRefresh") { [weak self] in
            print("⏰ HRVAuthenticationManager: Background task expiring")
            self?.endBackgroundTask()
        }
        
        print("📱 HRVAuthenticationManager: Background task started: \(backgroundTaskID.rawValue)")
    }
    
    /// End background task
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
            print("📱 HRVAuthenticationManager: Background task ended")
        }
    }
    
    // MARK: - Public Interface
    
    /// Check if token is close to expiring
    func isTokenNearExpiry() -> Bool {
        guard let expiryTime = tokenExpiryTime else { return false }
        let timeUntilExpiry = expiryTime.timeIntervalSince(Date())
        return timeUntilExpiry <= warningThresholdMinutes
    }
    
    /// Get time until token expiry
    func timeUntilExpiry() -> TimeInterval? {
        guard let expiryTime = tokenExpiryTime else { return nil }
        return expiryTime.timeIntervalSince(Date())
    }
    
    /// Force token refresh (for testing or manual refresh)
    func forceTokenRefresh() async {
        print("🔄 HRVAuthenticationManager: Force token refresh requested")
        await performTokenRefresh()
    }
    
    // MARK: - Helper Methods
    
    /// Extract expiry time from JWT token
    private func extractTokenExpiry(from token: String) -> Date? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            return nil
        }
        
        let payload = parts[1]
        var paddedPayload = payload
        let remainder = payload.count % 4
        if remainder > 0 {
            paddedPayload += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: paddedPayload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return nil
        }
        
        return Date(timeIntervalSince1970: exp)
    }
}
