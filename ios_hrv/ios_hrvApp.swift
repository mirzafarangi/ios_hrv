/**
 * ios_hrvApp.swift
 * Main SwiftUI app entry point for Lumenis iOS App
 * Initializes CoreEngine and Supabase for clean dependency injection
 */

import SwiftUI

@main
struct ios_hrvApp: App {
    
    // MARK: - Core Engine
    @StateObject private var coreEngine = CoreEngine.shared
    
    // MARK: - App Lifecycle
    init() {
        // Initialize Supabase configuration
        _ = SupabaseConfig.shared
        print("🟢 Supabase configured successfully")
        
        // Configure app on launch
        configureApp()
        
        // Log app launch
        logInfo("Lumenis App launched", category: .core)
        CoreEvents.shared.emit(.appLaunched)
    }
    
    var body: some Scene {
        WindowGroup {
            MainContentView()
                .onAppear {
                    logInfo("Main view appeared", category: .ui)
                }
        }
    }
    
    // MARK: - Configuration
    private func configureApp() {
        // Configure logging
        logInfo("Configuring Lumenis App...", category: .core)
        
        // Any additional app-wide configuration can go here
        // For example: Firebase configuration, analytics, etc.
    }
}
