/**
 * SupabaseAuthService.swift
 * Clean Supabase Swift SDK authentication service
 * Schema.md compliant user management and session handling
 */

import Foundation
import Combine

@MainActor
class SupabaseAuthService: ObservableObject {
    static let shared = SupabaseAuthService()
    
    // MARK: - Published Properties (Schema.md Compliant)
    @Published var isAuthenticated = false
    @Published var currentUser: SupabaseUser?
    @Published var userEmail: String?
    @Published var userId: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Configuration (NEW SUPABASE PROJECT - ROTATED KEYS)
    private let supabaseURL = "https://hmckwsyksbckxfxuzxca.supabase.co"
    private let supabaseKey = "sb_publishable_oRjabmXPVvT5QMv_5Ec92A_Ytc6xrFr"
    private var accessToken: String?
    
    private init() {
        // Check for existing session
        loadStoredSession()
        print("🟢 SupabaseAuthService initialized (Enhanced HTTP with debugging)")
    }
    
    // MARK: - Session Management
    
    private func loadStoredSession() {
        if let storedToken = UserDefaults.standard.string(forKey: "supabase_access_token"),
           let storedUserId = UserDefaults.standard.string(forKey: "supabase_user_id"),
           let storedEmail = UserDefaults.standard.string(forKey: "supabase_user_email") {
            
            self.accessToken = storedToken
            self.userId = storedUserId
            self.userEmail = storedEmail
            self.currentUser = SupabaseUser(id: storedUserId, email: storedEmail)
            self.isAuthenticated = true
            
            print("🔐 Restored session for: \(storedEmail)")
        }
    }
    
    private func storeSession(accessToken: String, user: SupabaseUser) {
        UserDefaults.standard.set(accessToken, forKey: "supabase_access_token")
        UserDefaults.standard.set(user.id, forKey: "supabase_user_id")
        UserDefaults.standard.set(user.email, forKey: "supabase_user_email")
        
        self.accessToken = accessToken
        self.currentUser = user
        self.userId = user.id
        self.userEmail = user.email
        self.isAuthenticated = true
    }
    
    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: "supabase_access_token")
        UserDefaults.standard.removeObject(forKey: "supabase_user_id")
        UserDefaults.standard.removeObject(forKey: "supabase_user_email")
        
        self.accessToken = nil
        self.currentUser = nil
        self.userId = nil
        self.userEmail = nil
        self.isAuthenticated = false
    }
    
    // MARK: - Authentication Methods
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        print("🔑 Starting sign in for: \(email)")
        
        do {
            let signInData = [
                "email": email,
                "password": password
            ]
            
            let response = try await makeAuthRequest(
                endpoint: "/auth/v1/token?grant_type=password",
                method: "POST",
                body: signInData
            )
            
            print("📝 Sign in response: \(response)")
            
            if let accessToken = response["access_token"] as? String,
               let userDict = response["user"] as? [String: Any],
               let userId = userDict["id"] as? String,
               let userEmail = userDict["email"] as? String {
                
                let user = SupabaseUser(id: userId, email: userEmail)
                storeSession(accessToken: accessToken, user: user)
                
                print("✅ Sign in successful: \(userEmail)")
            } else {
                print("❌ Sign in failed: Invalid response structure")
                throw AuthError.invalidResponse
            }
        } catch {
            let errorMsg = "Sign in failed: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            errorMessage = errorMsg
            throw error
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        print("🔐 Starting sign up for: \(email)")
        
        do {
            let signUpData = [
                "email": email,
                "password": password
            ]
            
            print("🚀 Making sign up request to Supabase...")
            
            let response = try await makeAuthRequest(
                endpoint: "/auth/v1/signup",
                method: "POST",
                body: signUpData
            )
            
            print("📝 Sign up response: \(response)")
            
            // Supabase returns user data directly at root level, not nested in 'user' object
            if let userEmail = response["email"] as? String,
               let userId = response["id"] as? String {
                print("✅ Sign up successful: \(userEmail)")
                print("📬 Check your email for confirmation link")
                print("🆔 User ID: \(userId)")
                
                // Note: User won't be authenticated until email is confirmed
                // This is standard Supabase behavior
                errorMessage = "Sign up successful! Check your email for confirmation."
            } else {
                print("⚠️ Sign up response received but missing email or id")
                print("🔍 Response keys: \(response.keys)")
                print("📧 Email field: \(response["email"] ?? "missing")")
                print("🆔 ID field: \(response["id"] ?? "missing")")
                throw AuthError.invalidResponse
            }
        } catch {
            let errorMsg = "Sign up failed: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            errorMessage = errorMsg
            throw error
        }
        
        isLoading = false
    }
    
    func signOut() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await makeAuthRequest(
                endpoint: "/auth/v1/logout",
                method: "POST",
                body: [:],
                requiresAuth: true
            )
            
            clearSession()
            print("✅ Sign out successful")
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - HTTP Helper
    
    private func makeAuthRequest(
        endpoint: String,
        method: String,
        body: [String: Any],
        requiresAuth: Bool = false
    ) async throws -> [String: Any] {
        
        guard let url = URL(string: supabaseURL + endpoint) else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        if requiresAuth, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if !body.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error_description"] as? String ?? errorData["msg"] as? String {
                throw AuthError.serverError(errorMessage)
            }
            throw AuthError.httpError(httpResponse.statusCode)
        }
        
        guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.invalidResponse
        }
        
        return jsonResponse
    }
    
    // MARK: - Session Access
    
    func getCurrentSession() async throws -> SupabaseSession? {
        guard let token = accessToken, let user = currentUser else {
            return nil
        }
        return SupabaseSession(accessToken: token, user: user)
    }
    
    // signOut() method already implemented above - removing duplicate
    
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let resetData = ["email": email]
            let _ = try await makeAuthRequest(
                endpoint: "/auth/v1/recover",
                method: "POST",
                body: resetData
            )
            print("✅ Password reset email sent to: \(email)")
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
        
        isLoading = false
    }
    
    func getAccessToken() async throws -> String? {
        return accessToken
    }
    
    func getCurrentAccessToken() async -> String? {
        print("🔍 getCurrentAccessToken called")
        print("   isAuthenticated: \(isAuthenticated)")
        print("   accessToken exists: \(accessToken != nil)")
        if let token = accessToken {
            print("   accessToken preview: \(String(token.prefix(20)))...")
        } else {
            print("   accessToken is nil")
        }
        return accessToken
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
