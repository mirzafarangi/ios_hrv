/**
 * SupabaseAuthService.swift
 * Clean Supabase authentication service with comprehensive error handling
 * Addresses JWT expiration, sign out issues, and user feedback
 */

import Foundation
import Combine

@MainActor
class SupabaseAuthService: ObservableObject {
    static let shared = SupabaseAuthService()
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var currentUser: SupabaseUser?
    @Published var userEmail: String?
    @Published var userId: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - Configuration (Hybrid Pattern - HTTP Auth)
    private let supabaseURL = "https://hmckwsyksbckxfxuzxca.supabase.co"
    private let supabaseKey = "sb_publishable_oRjabmXPVvT5QMv_5Ec92A_Ytc6xrFr"
    private var accessToken: String?
    
    private init() {
        loadStoredSession()
        print("SupabaseAuthService initialized")
    }
    
    // MARK: - Session Management
    
    private func loadStoredSession() {
        if let storedToken = UserDefaults.standard.string(forKey: "supabase_access_token"),
           let storedUserId = UserDefaults.standard.string(forKey: "supabase_user_id"),
           let storedEmail = UserDefaults.standard.string(forKey: "supabase_user_email") {
            
            // Check if stored token is expired before restoring session
            if !isJWTExpired(storedToken) {
                self.accessToken = storedToken
                self.userId = storedUserId
                self.userEmail = storedEmail
                self.currentUser = SupabaseUser(id: storedUserId, email: storedEmail)
                self.isAuthenticated = true
                print("Session restored for: \(storedEmail)")
            } else {
                print("Stored token is expired, clearing session")
                clearStoredSession()
            }
        }
    }
    
    private func storeSession(accessToken: String, user: SupabaseUser) {
        UserDefaults.standard.set(accessToken, forKey: "supabase_access_token")
        UserDefaults.standard.set(user.id, forKey: "supabase_user_id")
        UserDefaults.standard.set(user.email, forKey: "supabase_user_email")
        
        self.accessToken = accessToken
        self.userId = user.id
        self.userEmail = user.email
        self.currentUser = user
        self.isAuthenticated = true
        
        print("Session stored for: \(user.email)")
    }
    
    private func clearStoredSession() {
        UserDefaults.standard.removeObject(forKey: "supabase_access_token")
        UserDefaults.standard.removeObject(forKey: "supabase_user_id")
        UserDefaults.standard.removeObject(forKey: "supabase_user_email")
        
        self.accessToken = nil
        self.userId = nil
        self.userEmail = nil
        self.currentUser = nil
        self.isAuthenticated = false
        
        print("Session cleared")
    }
    
    // MARK: - Authentication Methods
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        print("Starting sign in for: \(email)")
        
        do {
            guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=password") else {
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
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Sign in response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    // Handle specific authentication errors
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorData["error_description"] as? String ?? errorData["message"] as? String {
                        
                        // Provide user-friendly error messages
                        let friendlyMessage = getFriendlyErrorMessage(errorMessage)
                        self.errorMessage = friendlyMessage
                        throw AuthError.serverError(friendlyMessage)
                    } else {
                        self.errorMessage = "Authentication failed"
                        throw AuthError.httpError(httpResponse.statusCode)
                    }
                }
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String,
                  let userDict = json["user"] as? [String: Any],
                  let userId = userDict["id"] as? String,
                  let userEmail = userDict["email"] as? String else {
                throw AuthError.invalidResponse
            }
            
            let user = SupabaseUser(id: userId, email: userEmail)
            storeSession(accessToken: accessToken, user: user)
            
            successMessage = "Sign in successful"
            print("Sign in successful: \(userEmail)")
            
        } catch {
            print("Sign in error: \(error)")
            if errorMessage == nil {
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
            throw error
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        print("Starting sign up for: \(email)")
        
        do {
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
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Sign up response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    // Handle specific registration errors
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorData["error_description"] as? String ?? errorData["message"] as? String {
                        
                        let friendlyMessage = getFriendlyErrorMessage(errorMessage)
                        self.errorMessage = friendlyMessage
                        throw AuthError.serverError(friendlyMessage)
                    } else {
                        self.errorMessage = "Registration failed"
                        throw AuthError.httpError(httpResponse.statusCode)
                    }
                }
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
                        storeSession(accessToken: accessToken, user: supabaseUser)
                        successMessage = "Registration and sign in successful"
                    }
                }
            }
            
            print("Sign up successful: \(email)")
            
        } catch {
            print("Sign up error: \(error)")
            if errorMessage == nil {
                errorMessage = "Sign up failed: \(error.localizedDescription)"
            }
            throw error
        }
        
        isLoading = false
    }
    
    func signOut() async throws {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        print("Starting sign out")
        
        // Store current token before clearing (for server logout)
        let currentToken = accessToken
        
        // Always clear local session first to prevent loops
        clearStoredSession()
        
        // Try to invalidate token on server (but don't fail if it doesn't work)
        if let token = currentToken {
            do {
                guard let url = URL(string: "\(supabaseURL)/auth/v1/logout") else {
                    throw AuthError.invalidURL
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Sign out response status: \(httpResponse.statusCode)")
                }
            } catch {
                print("Server sign out failed (but local session cleared): \(error)")
                // Don't throw error here - local session is already cleared
            }
        }
        
        successMessage = "Signed out successfully"
        print("Sign out completed")
        
        isLoading = false
    }
    
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        print("Starting password reset for: \(email)")
        
        do {
            guard let url = URL(string: "\(supabaseURL)/auth/v1/recover") else {
                throw AuthError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            
            let body = ["email": email]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Password reset response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorData["error_description"] as? String ?? errorData["message"] as? String {
                        
                        let friendlyMessage = getFriendlyErrorMessage(errorMessage)
                        self.errorMessage = friendlyMessage
                        throw AuthError.serverError(friendlyMessage)
                    } else {
                        self.errorMessage = "Password reset failed"
                        throw AuthError.httpError(httpResponse.statusCode)
                    }
                }
            }
            
            successMessage = "Password reset email sent. Please check your inbox."
            print("Password reset email sent to: \(email)")
            
        } catch {
            print("Password reset error: \(error)")
            if errorMessage == nil {
                errorMessage = "Password reset failed: \(error.localizedDescription)"
            }
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Token Management
    
    func getCurrentAccessToken() async -> String? {
        print("getCurrentAccessToken called")
        print("   isAuthenticated: \(isAuthenticated)")
        print("   accessToken exists: \(accessToken != nil)")
        
        guard let token = accessToken else {
            print("   accessToken is nil")
            return nil
        }
        
        print("   accessToken preview: \(String(token.prefix(20)))...")
        
        // Check if token is expired
        if isJWTExpired(token) {
            print("JWT token is expired, clearing session")
            clearStoredSession()
            return nil
        }
        
        return token
    }
    
    private func isJWTExpired(_ token: String) -> Bool {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            print("Invalid JWT format")
            return true
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
            print("Could not parse JWT expiration")
            return true
        }
        
        let expirationDate = Date(timeIntervalSince1970: exp)
        let isExpired = Date() >= expirationDate
        
        if isExpired {
            print("JWT expired at: \(expirationDate)")
        } else {
            print("JWT valid until: \(expirationDate)")
        }
        
        return isExpired
    }
    
    // MARK: - Helper Methods
    
    private func getFriendlyErrorMessage(_ errorMessage: String) -> String {
        let lowercased = errorMessage.lowercased()
        
        if lowercased.contains("invalid login credentials") || lowercased.contains("invalid email or password") {
            return "Invalid email or password. Please check your credentials and try again."
        } else if lowercased.contains("email not confirmed") {
            return "Please check your email and click the confirmation link before signing in."
        } else if lowercased.contains("user not found") {
            return "No account found with this email address. Please sign up first."
        } else if lowercased.contains("user already registered") {
            return "An account with this email already exists. Please sign in instead."
        } else if lowercased.contains("password") && lowercased.contains("weak") {
            return "Password is too weak. Please use at least 8 characters with a mix of letters and numbers."
        } else if lowercased.contains("email") && lowercased.contains("invalid") {
            return "Please enter a valid email address."
        } else {
            return errorMessage
        }
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}

// MARK: - Models

struct SupabaseUser: Codable {
    let id: String
    let email: String
}

struct SupabaseSession {
    let accessToken: String
    let user: SupabaseUser
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
}
