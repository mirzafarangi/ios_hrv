/**
 * DatabaseSessionManager.swift
 * Direct database access for Sessions tab - Clean, Simple, Reliable
 * Uses Supabase Swift SDK for proper database integration
 */

import Foundation
import PostgREST

@MainActor
class DatabaseSessionManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var sessions: [DatabaseSession] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var debugInfo: [String] = []
    
    // MARK: - Private Properties
    private let supabase = SupabaseConfig.client
    
    // MARK: - Core Functions
    
    func loadSessions(for userId: String, limit: Int = 13) {
        isLoading = true
        errorMessage = nil
        debugInfo = ["🔄 Starting Supabase Swift SDK session load for user: \(userId) (limit: \(limit))"]
        
        Task {
            do {
                // Get authenticated user token from SupabaseAuthService
                self.debugInfo.append("🔍 Checking authentication status...")
                
                let authService = SupabaseAuthService.shared
                self.debugInfo.append("   isAuthenticated: \(authService.isAuthenticated)")
                self.debugInfo.append("   userEmail: \(authService.userEmail ?? "none")")
                
                guard let userToken = await authService.getCurrentAccessToken() else {
                    await MainActor.run {
                        self.isLoading = false
                        self.errorMessage = "Authentication required"
                        self.debugInfo.append("❌ No valid user token found")
                        self.debugInfo.append("🔐 Please sign in to view sessions")
                        self.debugInfo.append("🔍 Auth status: \(authService.isAuthenticated)")
                    }
                    return
                }
                
                self.debugInfo.append("🔐 Using authenticated user token")
                self.debugInfo.append("   Token format: JWT (\(String(userToken.prefix(20)))...)")
                self.debugInfo.append("   PostgREST URL: \(SupabaseConfig.url)/rest/v1")
                self.debugInfo.append("   API Key: \(String(SupabaseConfig.anonKey.prefix(20)))...")
                
                // Create authenticated PostgREST client
                let authenticatedClient = PostgrestClient(
                    url: URL(string: "\(SupabaseConfig.url)/rest/v1")!,
                    schema: "public",
                    headers: [
                        "apikey": SupabaseConfig.anonKey,
                        "Authorization": "Bearer \(userToken)",
                        "Content-Type": "application/json"
                    ],
                    logger: nil
                )
                
                // Query sessions table using authenticated PostgREST client
                let response: [DatabaseSession] = try await authenticatedClient
                    .from("sessions")
                    .select("""
                        session_id,
                        user_id,
                        tag,
                        subtag,
                        event_id,
                        duration_minutes,
                        recorded_at,
                        rr_count,
                        status,
                        processed_at,
                        mean_hr,
                        mean_rr,
                        rmssd,
                        sdnn,
                        pnn50,
                        cv_rr,
                        defa,
                        sd2_sd1,
                        created_at,
                        updated_at
                    """)
                    .eq("user_id", value: userId)
                    .order("recorded_at", ascending: false)
                    .limit(limit)
                    .execute()
                    .value
                
                await MainActor.run {
                    self.sessions = response
                    self.isLoading = false
                    self.debugInfo.append("✅ Successfully loaded \(response.count) sessions via Supabase Swift SDK")
                    self.debugInfo.append("📊 Database Schema: v4.2.0 ULTIMATE")
                    self.debugInfo.append("🔗 Connection: Supabase Swift SDK → PostgreSQL")
                    self.debugInfo.append("🏗️ SDK Version: 2.31.1")
                    
                    if response.isEmpty {
                        self.debugInfo.append("ℹ️ No sessions found for user \(userId)")
                        self.debugInfo.append("💡 Record a session in the Record tab to see data here")
                    } else {
                        let sessionTypes = Set(response.map { $0.tag })
                        let completedCount = response.filter { $0.status == "completed" }.count
                        let withMetricsCount = response.filter { $0.hasHrvMetrics }.count
                        
                        self.debugInfo.append("📈 Session types: \(sessionTypes.joined(separator: ", "))")
                        self.debugInfo.append("✅ Completed: \(completedCount)/\(response.count)")
                        self.debugInfo.append("📊 With physiological metrics: \(withMetricsCount)/\(response.count)")
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Database error: \(error.localizedDescription)"
                    self.debugInfo.append("❌ PostgREST query failed: \(error)")
                    
                    // Add detailed debugging information
                    self.debugInfo.append("🔍 Error type: \(type(of: error))")
                    self.debugInfo.append("📝 Error description: \(error.localizedDescription)")
                    
                    // Check for PostgREST specific errors
                    let errorString = String(describing: error)
                    if errorString.contains("Invalid API key") {
                        self.debugInfo.append("🔑 PostgREST API key issue detected")
                        self.debugInfo.append("   - Check if anon key is correct")
                        self.debugInfo.append("   - Check if user token is valid JWT")
                        self.debugInfo.append("   - Check database RLS policies")
                    }
                    if errorString.contains("unauthorized") {
                        self.debugInfo.append("🔐 Authorization issue - check RLS policies")
                    }
                    if errorString.contains("network") {
                        self.debugInfo.append("🌐 Network issue - check internet connection")
                    }
                    if errorString.contains("404") {
                        self.debugInfo.append("📋 Table 'sessions' not found - check database schema")
                    }
                    
                    // Log the full error for debugging
                    print("🔴 Full PostgREST Error: \(error)")
                }
            }
        }
    }
    
    func refreshSessions(for userId: String) {
        debugInfo.append("🔄 Manual refresh triggered")
        loadSessions(for: userId)
    }
    
    func getTotalSessionCount(for userId: String) async -> Int {
        do {
            let authService = SupabaseAuthService.shared
            guard let userToken = await authService.getCurrentAccessToken() else {
                await MainActor.run {
                    self.debugInfo.append("Authentication required for session count")
                }
                return 0
            }
            
            let authenticatedClient = PostgrestClient(
                url: URL(string: "\(SupabaseConfig.url)/rest/v1")!,
                schema: "public",
                headers: [
                    "apikey": SupabaseConfig.anonKey,
                    "Authorization": "Bearer \(userToken)",
                    "Content-Type": "application/json",
                    "Prefer": "count=exact"
                ],
                logger: nil
            )
            
            // Use count query instead of selecting all records
            let response = try await authenticatedClient
                .from("sessions")
                .select("*", head: true, count: .exact)
                .eq("user_id", value: userId)
                .execute()
            
            let count = response.count ?? 0
            
            await MainActor.run {
                self.debugInfo.append("Total session count retrieved: \(count)")
            }
            
            return count
            
        } catch {
            await MainActor.run {
                self.debugInfo.append("Error getting session count: \(error.localizedDescription)")
            }
            return 0
        }
    }
    
    func getSessionsByTag(for userId: String) async -> [String: [DatabaseSession]] {
        do {
            let authService = SupabaseAuthService.shared
            guard let userToken = await authService.getCurrentAccessToken() else {
                await MainActor.run {
                    self.debugInfo.append("Authentication required for sessions by tag")
                }
                return [:]
            }
            
            let authenticatedClient = PostgrestClient(
                url: URL(string: "\(SupabaseConfig.url)/rest/v1")!,
                schema: "public",
                headers: [
                    "apikey": SupabaseConfig.anonKey,
                    "Authorization": "Bearer \(userToken)",
                    "Content-Type": "application/json"
                ],
                logger: nil
            )
            
            let response: [DatabaseSession] = try await authenticatedClient
                .from("sessions")
                .select("""
                    session_id,
                    user_id,
                    tag,
                    subtag,
                    event_id,
                    duration_minutes,
                    recorded_at,
                    rr_count,
                    status,
                    processed_at,
                    mean_hr,
                    mean_rr,
                    rmssd,
                    sdnn,
                    pnn50,
                    cv_rr,
                    defa,
                    sd2_sd1,
                    created_at,
                    updated_at
                """)
                .eq("user_id", value: userId)
                .order("recorded_at", ascending: false)
                .execute()
                .value
            
            // Group sessions by tag
            let groupedSessions = Dictionary(grouping: response) { $0.tag }
            
            await MainActor.run {
                self.debugInfo.append("Sessions grouped by tag: \(groupedSessions.keys.sorted())")
            }
            
            return groupedSessions
            
        } catch {
            await MainActor.run {
                self.debugInfo.append("Error getting sessions by tag: \(error.localizedDescription)")
            }
            return [:]
        }
    }
    
    func deleteSession(sessionId: String, userId: String) async -> Result<Void, Error> {
        debugInfo.append("🗑️ Starting session deletion: \(sessionId)")
        
        do {
            // Get authenticated user token from SupabaseAuthService
            let authService = SupabaseAuthService.shared
            guard let userToken = await authService.getCurrentAccessToken() else {
                let error = NSError(domain: "DatabaseSessionManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required for deletion"])
                debugInfo.append("❌ Deletion failed: No valid user token")
                return .failure(error)
            }
            
            debugInfo.append("🔐 Using authenticated token for deletion")
            
            // Create authenticated PostgREST client
            let authenticatedClient = PostgrestClient(
                url: URL(string: "\(SupabaseConfig.url)/rest/v1")!,
                schema: "public",
                headers: [
                    "apikey": SupabaseConfig.anonKey,
                    "Authorization": "Bearer \(userToken)",
                    "Content-Type": "application/json"
                ],
                logger: nil
            )
            
            // Delete session from database (RLS will ensure user can only delete their own sessions)
            try await authenticatedClient
                .from("sessions")
                .delete()
                .eq("session_id", value: sessionId)
                .eq("user_id", value: userId)
                .execute()
            
            debugInfo.append("✅ Session deleted successfully: \(sessionId)")
            
            // Remove session from local array immediately for responsive UI
            await MainActor.run {
                self.sessions.removeAll { $0.sessionId == sessionId }
                self.debugInfo.append("🔄 Local session list updated (removed: \(sessionId))")
            }
            
            return .success(())
            
        } catch {
            debugInfo.append("❌ Session deletion failed: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    func clearDebugInfo() {
        debugInfo.removeAll()
    }
}

// MARK: - Database Session Model
// Matches our final database schema exactly
struct DatabaseSession: Codable, Identifiable {
    let sessionId: String
    let userId: String
    let tag: String
    let subtag: String
    let eventId: Int
    let durationMinutes: Int
    let recordedAt: Date
    let rrCount: Int?
    let status: String
    let processedAt: Date?
    
    // Physiological Metrics (all 9 from final schema)
    let meanHr: Double?
    let meanRr: Double?
    let rmssd: Double?
    let sdnn: Double?
    let pnn50: Double?
    let cvRr: Double?
    let defa: Double?
    let sd2Sd1: Double?
    
    let createdAt: Date
    let updatedAt: Date
    
    // Computed properties
    var id: String { sessionId }
    
    var statusEmoji: String {
        switch status {
        case "completed": return "✅"
        case "processing": return "⏳"
        case "failed": return "❌"
        default: return "❓"
        }
    }
    
    var tagEmoji: String {
        switch tag {
        case "wake_check": return "☀️"
        case "pre_sleep": return "🌙"
        case "sleep": return "😴"
        case "experiment": return "🧪"
        default: return "📊"
        }
    }
    
    var hasHrvMetrics: Bool {
        return meanHr != nil || rmssd != nil || sdnn != nil
    }
    
    // CodingKeys to match database column names
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case userId = "user_id"
        case tag, subtag
        case eventId = "event_id"
        case durationMinutes = "duration_minutes"
        case recordedAt = "recorded_at"
        case rrCount = "rr_count"
        case status
        case processedAt = "processed_at"
        case meanHr = "mean_hr"
        case meanRr = "mean_rr"
        case rmssd, sdnn, pnn50
        case cvRr = "cv_rr"
        case defa
        case sd2Sd1 = "sd2_sd1"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
