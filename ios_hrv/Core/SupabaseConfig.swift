/**
 * SupabaseConfig.swift
 * Hybrid Supabase configuration for HRV iOS App
 * HTTP-based auth + Swift SDK for database queries
 * Schema v4.2.0 ULTIMATE compliant
 */

import Foundation
import PostgREST
import Auth

struct SupabaseConfig {
    // NEW SUPABASE PROJECT: atriom_hrv_db (Railway-compatible, ROTATED KEYS)
    static let url = "https://hmckwsyksbckxfxuzxca.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhtY2t3c3lrc2Jja3hmeHV6eGNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQyNTIzOTQsImV4cCI6MjA2OTgyODM5NH0.QuaQEH_MLluSafrnYD5GWDy5pHrBfNprgNq3UpVLAuc"
    
    // PostgREST client for database operations
    static let client = PostgrestClient(
        url: URL(string: "\(url)/rest/v1")!,
        schema: "public",
        headers: [
            "apikey": anonKey,
            "Authorization": "Bearer \(anonKey)"
        ],
        logger: nil
    )
    
    // Singleton instance for app initialization
    static let shared = SupabaseConfig()
    
    private init() {
        print("🟢 Supabase Hybrid Configuration Initialized")
        print("   Project URL: \(Self.url)")
        print("   🔐 Auth: HTTP-based (SupabaseAuthService)")
        print("   🗄️ Database: Swift SDK v2.31.1 (DatabaseSessionManager)")
        print("   📊 Schema: v4.2.0 ULTIMATE")
    }
}
