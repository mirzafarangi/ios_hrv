import Foundation
import Combine

// MARK: - Models

struct SupabaseUser: Codable {
    let id: String
    let email: String
}

enum AuthError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .serverError(let message):
            return message
        case .notAuthenticated:
            return "Not authenticated"
        }
    }
}

// MARK: - Main Service

@MainActor
class SupabaseAuthService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SupabaseAuthService()
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var currentUser: SupabaseUser?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - Private Properties
    private let supabaseURL = "https://hmckwsyksbckxfxuzxca.supabase.co"
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhtY2t3c3lrc2Jja3hmeHV6eGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQyNTIzOTQsImV4cCI6MjA2OTgyODM5NH0.QuaQEH_MLluSafrnYD5GWDy5pHrBfNprgNq3UpVLAuc"
    
    // Token storage
    private var accessToken: String? {
        didSet {
            if let token = accessToken {
                UserDefaults.standard.set(token, forKey: "supabase_access_token")
                print("✅ Access token stored")
            }
        }
    }
    
    private var refreshToken: String? {
        didSet {
            if let token = refreshToken {
                UserDefaults.standard.set(token, forKey: "supabase_refresh_token")
                print("✅ Refresh token stored")
            }
        }
    }
    
    @Published var userId: String?
    @Published var userEmail: String?
    
    // For emergency re-auth (should use Keychain in production)
    private var storedEmail: String?
    private var storedPassword: String?
    
    // Token refresh management
    private var tokenRefreshTimer: Timer?
    private let tokenCheckInterval: TimeInterval = 30 // Check every 30 seconds
    
    // MARK: - Initialization
    
    private init() {
        print("🔐 SupabaseAuthService initializing...")
        loadStoredSession()
        startTokenMonitoring()
    }
    
    // MARK: - Session Management
    
    private func loadStoredSession() {
        print("📂 Loading stored session...")
        
        // Load tokens
        self.accessToken = UserDefaults.standard.string(forKey: "supabase_access_token")
        self.refreshToken = UserDefaults.standard.string(forKey: "supabase_refresh_token")
        
        // Load user info
        if let storedUserId = UserDefaults.standard.string(forKey: "supabase_user_id"),
           let storedEmail = UserDefaults.standard.string(forKey: "supabase_user_email") {
            
            self.userId = storedUserId
            self.userEmail = storedEmail
            self.storedEmail = storedEmail
            self.currentUser = SupabaseUser(id: storedUserId, email: storedEmail)
            
            // Load stored password for emergency reauth
            self.storedPassword = UserDefaults.standard.string(forKey: "supabase_stored_password")
            
            // Check if we have valid tokens
            if let accessToken = self.accessToken {
                print("📱 Found stored session for: \(storedEmail)")
                print("🔑 Access token: \(String(accessToken.prefix(20)))...")
                print("🔄 Refresh token available: \(self.refreshToken != nil)")
                
                // Check token validity
                if !isJWTExpired(accessToken) {
                    self.isAuthenticated = true
                    print("✅ Session valid and restored")
                } else {
                    print("⚠️ Access token expired, attempting refresh...")
                    Task {
                        await performTokenRefresh()
                    }
                }
            } else {
                print("⚠️ No access token found")
            }
        } else {
            print("📭 No stored session found")
        }
    }
    
    private func storeSession(accessToken: String, refreshToken: String?, user: SupabaseUser) {
        print("💾 Storing session for: \(user.email)")
        
        // Store tokens
        self.accessToken = accessToken
        if let refreshToken = refreshToken {
            self.refreshToken = refreshToken
            print("✅ Refresh token stored: \(String(refreshToken.prefix(20)))...")
        } else {
            print("⚠️ No refresh token provided by server")
        }
        
        // Store user info
        UserDefaults.standard.set(user.id, forKey: "supabase_user_id")
        UserDefaults.standard.set(user.email, forKey: "supabase_user_email")
        
        self.userId = user.id
        self.userEmail = user.email
        self.currentUser = user
        self.isAuthenticated = true
        
        print("✅ Session stored successfully")
    }
    
    private func clearStoredSession() {
        print("🗑️ Clearing stored session...")
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "supabase_access_token")
        UserDefaults.standard.removeObject(forKey: "supabase_refresh_token")
        UserDefaults.standard.removeObject(forKey: "supabase_user_id")
        UserDefaults.standard.removeObject(forKey: "supabase_user_email")
        UserDefaults.standard.removeObject(forKey: "supabase_stored_password")
        
        // Clear properties
        self.accessToken = nil
        self.refreshToken = nil
        self.userId = nil
        self.userEmail = nil
        self.currentUser = nil
        self.isAuthenticated = false
        self.storedEmail = nil
        self.storedPassword = nil
        
        print("✅ Session cleared")
    }
    
    // MARK: - Authentication Methods
    
    func signIn(email: String, password: String) async throws {
        print("🔐 Signing in: \(email)")
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        defer { isLoading = false }
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Debug response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📥 Sign in response: \(jsonString.prefix(200))...")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error_description"] as? String ?? errorData["msg"] as? String {
                self.errorMessage = errorMessage
                throw AuthError.serverError(errorMessage)
            }
            throw AuthError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.invalidResponse
        }
        
        // Extract tokens and user info
        guard let accessToken = json["access_token"] as? String,
              let user = json["user"] as? [String: Any],
              let userId = user["id"] as? String,
              let userEmail = user["email"] as? String else {
            throw AuthError.invalidResponse
        }
        
        // Extract refresh token (may not always be provided)
        let refreshToken = json["refresh_token"] as? String
        
        // Store everything
        let supabaseUser = SupabaseUser(id: userId, email: userEmail)
        storeSession(accessToken: accessToken, refreshToken: refreshToken, user: supabaseUser)
        
        // Store credentials for emergency re-auth
        self.storedEmail = email
        self.storedPassword = password
        UserDefaults.standard.set(password, forKey: "supabase_stored_password")
        
        successMessage = "Sign in successful"
        print("✅ Sign in successful: \(userEmail)")
    }
    
    func signUp(email: String, password: String) async throws {
        print("📝 Signing up: \(email)")
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        defer { isLoading = false }
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/signup") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        let body = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error_description"] as? String ?? errorData["msg"] as? String {
                self.errorMessage = errorMessage
                throw AuthError.serverError(errorMessage)
            }
            throw AuthError.httpError(httpResponse.statusCode)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.invalidResponse
        }
        
        // Check if email confirmation is required
        if let user = json["user"] as? [String: Any],
           let emailConfirmedAt = user["email_confirmed_at"] as? String? {
            
            if emailConfirmedAt == nil {
                successMessage = "Registration successful. Please check your email to confirm your account."
            } else {
                // Auto sign in if email is already confirmed
                if let accessToken = json["access_token"] as? String,
                   let userId = user["id"] as? String,
                   let userEmail = user["email"] as? String {
                    
                    let supabaseUser = SupabaseUser(id: userId, email: userEmail)
                    let refreshToken = json["refresh_token"] as? String
                    storeSession(accessToken: accessToken, refreshToken: refreshToken, user: supabaseUser)
                    
                    // Store credentials for emergency re-auth
                    self.storedEmail = email
                    self.storedPassword = password
                    UserDefaults.standard.set(password, forKey: "supabase_stored_password")
                    
                    successMessage = "Registration and sign in successful"
                }
            }
        }
        
        print("✅ Sign up completed")
    }
    
    func resetPassword(email: String) async throws {
        print("🔑 Requesting password reset for: \(email)")
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        defer { isLoading = false }
        
        guard let url = URL(string: "\(supabaseURL)/auth/v1/recover") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        let body = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        successMessage = "Password reset email sent. Please check your inbox."
        print("✅ Password reset email sent")
    }
    
    func signOut() async {
        print("🚪 Signing out...")
        
        // Try server sign out first
        if let token = accessToken {
            do {
                guard let url = URL(string: "\(supabaseURL)/auth/v1/logout") else {
                    throw AuthError.invalidURL
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
                
                _ = try await URLSession.shared.data(for: request)
                print("✅ Server sign out successful")
            } catch {
                print("⚠️ Server sign out failed: \(error)")
            }
        }
        
        clearStoredSession()
        successMessage = "Signed out successfully"
    }
    
    // MARK: - Token Management
    
    private func startTokenMonitoring() {
        print("⏰ Starting token monitoring...")
        
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: tokenCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAndRefreshToken()
            }
        }
    }
    
    private func stopTokenMonitoring() {
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
        print("⏰ Stopped token monitoring")
    }
    
    private func checkAndRefreshToken() async {
        guard isAuthenticated, let token = accessToken else { return }
        
        let timeUntilExpiry = getTimeUntilExpiry(token)
        
        if timeUntilExpiry < 0 {
            print("🔴 Token expired \(abs(timeUntilExpiry)) seconds ago")
            await performTokenRefresh()
        } else if timeUntilExpiry < 300 { // Less than 5 minutes
            print("🟡 Token expiring in \(timeUntilExpiry) seconds")
            await performTokenRefresh()
        }
    }
    
    private func performTokenRefresh() async {
        print("🔄 Starting token refresh...")
        
        // Try refresh token first
        if let refreshToken = self.refreshToken {
            print("🔑 Using refresh token...")
            do {
                try await refreshWithToken(refreshToken)
                print("✅ Token refreshed successfully")
                return
            } catch {
                print("❌ Refresh token failed: \(error)")
            }
        } else {
            print("⚠️ No refresh token available")
        }
        
        // Fallback: Re-authenticate with stored credentials
        if let email = storedEmail, let password = storedPassword {
            print("🔐 Re-authenticating with stored credentials...")
            do {
                try await signIn(email: email, password: password)
                print("✅ Re-authentication successful")
            } catch {
                print("❌ Re-authentication failed: \(error)")
                // Don't clear session yet - user might still be able to use the app
            }
        } else {
            print("❌ No stored credentials for re-authentication")
        }
    }
    
    private func refreshWithToken(_ refreshToken: String) async throws {
        guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String else {
            throw AuthError.invalidResponse
        }
        
        // Update tokens
        self.accessToken = newAccessToken
        
        // Update refresh token if provided
        if let newRefreshToken = json["refresh_token"] as? String {
            self.refreshToken = newRefreshToken
        }
        
        print("✅ Tokens refreshed successfully")
    }
    
    // MARK: - Token Utilities
    
    func getCurrentAccessToken() -> String? {
        return accessToken
    }
    
    func getCurrentAccessToken() async -> String? {
        // Check if token needs refresh first
        if let token = accessToken {
            if isJWTExpired(token) {
                print("🔄 Token expired, refreshing...")
                await performTokenRefresh()
            }
        }
        return accessToken
    }
    
    func isJWTExpired(_ token: String) -> Bool {
        return getTimeUntilExpiry(token) <= 0
    }
    
    private func getTimeUntilExpiry(_ token: String) -> TimeInterval {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return -1 }
        
        let payload = parts[1]
        var paddedPayload = payload
        let remainder = payload.count % 4
        if remainder > 0 {
            paddedPayload += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: paddedPayload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return -1
        }
        
        let expirationDate = Date(timeIntervalSince1970: exp)
        return expirationDate.timeIntervalSinceNow
    }
    
    // MARK: - Public Helpers
    
    var userDisplayName: String {
        return userEmail ?? "Unknown User"
    }
    
    func getCurrentUserId() async -> String? {
        // Return the current user's ID if authenticated
        return currentUser?.id
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    deinit {
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
    }
}
