import SwiftUI

struct ProfileTabView: View {
    @StateObject private var authService = SupabaseAuthService.shared
    @State private var showingSignOutAlert = false
    @State private var showingErrorAlert = false
    @State private var showingSuccessAlert = false
    @State private var errorMessage = ""
    @State private var apiPulse = false
    @State private var dbPulse = false
    @State private var phaseShift: Double = 0
    
    // Our secret: Lunar phase calculation (only we know this represents our collaboration)
    private var lunarPhase: Double {
        let now = Date()
        let knownNewMoon = Date(timeIntervalSince1970: 1704067200) // Jan 1, 2024 new moon
        let lunarCycle = 29.53059 * 24 * 60 * 60 // seconds
        let elapsed = now.timeIntervalSince(knownNewMoon)
        return (elapsed.truncatingRemainder(dividingBy: lunarCycle)) / lunarCycle
    }
    
    private var phaseSymbol: String {
        switch lunarPhase {
        case 0..<0.125: return "🌑" // New moon - beginning
        case 0.125..<0.25: return "🌒" // Waxing crescent
        case 0.25..<0.375: return "🌓" // First quarter
        case 0.375..<0.5: return "🌔" // Waxing gibbous
        case 0.5..<0.625: return "🌕" // Full moon - peak collaboration
        case 0.625..<0.75: return "🌖" // Waning gibbous
        case 0.75..<0.875: return "🌗" // Last quarter
        default: return "🌘" // Waning crescent
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Light academic background
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Minimal header with unique name
                    VStack(spacing: 8) {
                        Text("LUMENIS")
                            .font(.system(size: 24, weight: .ultraLight, design: .monospaced))
                            .foregroundColor(.black.opacity(0.8))
                            .tracking(6)
                        
                        Rectangle()
                            .fill(Color.black.opacity(0.1))
                            .frame(height: 0.5)
                            .frame(maxWidth: 100)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    Spacer().frame(height: 40)
                    
                    // User Identity Matrix
                    VStack(alignment: .leading, spacing: 20) {
                        // Email identifier
                        HStack(spacing: 12) {
                            Text("@")
                                .font(.system(size: 14, weight: .light, design: .monospaced))
                                .foregroundColor(.black.opacity(0.4))
                            Text(authService.userEmail ?? "null")
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .foregroundColor(.black.opacity(0.8))
                        }
                        
                        // Complete UUID identifier - showing full ID
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 12) {
                                Text("#")
                                    .font(.system(size: 14, weight: .light, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.4))
                                Text("UUID")
                                    .font(.system(size: 12, weight: .light, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.4))
                            }
                            Text(authService.userId ?? "00000000-0000-0000-0000-000000000000")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundColor(.black.opacity(0.7))
                                .textCase(.lowercase)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        
                        // Auth status
                        HStack(spacing: 12) {
                            Text("λ")
                                .font(.system(size: 14, weight: .light, design: .monospaced))
                                .foregroundColor(.black.opacity(0.4))
                            Text(authService.isAuthenticated ? "authenticated" : "anonymous")
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .foregroundColor(authService.isAuthenticated ? .green : .black.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer().frame(height: 60)
                    
                    // System Status Dashboard
                    VStack(spacing: 24) {
                        Text("SYSTEM STATUS")
                            .font(.system(size: 12, weight: .light, design: .monospaced))
                            .foregroundColor(.black.opacity(0.5))
                            .tracking(2)
                        
                        HStack(spacing: 40) {
                            // API Status LED
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(apiPulse ? Color.green.opacity(0.2) : Color.clear)
                                        .frame(width: 24, height: 24)
                                        .scaleEffect(apiPulse ? 1.5 : 1.0)
                                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: apiPulse)
                                    
                                    Circle()
                                        .fill(checkAPIStatus() ? Color.green : Color.red)
                                        .frame(width: 12, height: 12)
                                }
                                
                                Text("API")
                                    .font(.system(size: 10, weight: .light, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.5))
                            }
                            
                            // DB Status LED
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(dbPulse ? Color.green.opacity(0.2) : Color.clear)
                                        .frame(width: 24, height: 24)
                                        .scaleEffect(dbPulse ? 1.5 : 1.0)
                                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: dbPulse)
                                    
                                    Circle()
                                        .fill(checkDBStatus() ? Color.green : Color.red)
                                        .frame(width: 12, height: 12)
                                }
                                
                                Text("DB")
                                    .font(.system(size: 10, weight: .light, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.5))
                            }
                        }
                    }
                    
                    Spacer().frame(height: 60)
                    
                    // Our secret signature - a mathematical constant only we understand
                    // φ (phi) = 1.618... the golden ratio, representing perfect harmony
                    VStack(spacing: 8) {
                        Text("φ")
                            .font(.system(size: 28, weight: .ultraLight, design: .serif))
                            .foregroundColor(.black.opacity(0.15))
                            .rotationEffect(.degrees(phaseShift * 360))
                            .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: phaseShift)
                        
                        Text("1.618033988749...")
                            .font(.system(size: 9, weight: .ultraLight, design: .monospaced))
                            .foregroundColor(.black.opacity(0.08))
                    }
                    
                    Spacer()
                    
                    // Minimal sign out
                    Button(action: {
                        showingSignOutAlert = true
                    }) {
                        Text("TERMINATE")
                            .font(.system(size: 12, weight: .light, design: .monospaced))
                            .foregroundColor(.red.opacity(0.7))
                            .tracking(2)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                apiPulse = checkAPIStatus()
                dbPulse = checkDBStatus()
                phaseShift = 1
            }
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await authService.signOut()
                    showingSuccessAlert = true
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") {
                authService.clearMessages()
            }
        } message: {
            Text(authService.errorMessage ?? "An error occurred")
        }
        .alert("Success", isPresented: $showingSuccessAlert) {
            Button("OK") {
                authService.clearMessages()
            }
        } message: {
            Text(authService.successMessage ?? "Operation completed successfully")
        }
        .onChange(of: authService.errorMessage) {
            if authService.errorMessage != nil {
                showingErrorAlert = true
            }
        }
        .onChange(of: authService.successMessage) {
            if authService.successMessage != nil {
                showingSuccessAlert = true
            }
        }
    }
    
    private func copyUserId() {
        guard let userId = authService.userId else { return }
        UIPasteboard.general.string = userId
    }
    
    private func checkAPIStatus() -> Bool {
        // Check if API is reachable (simplified check)
        // In production, this would make an actual health check call
        return authService.isAuthenticated
    }
    
    private func checkDBStatus() -> Bool {
        // Check if DB is connected (simplified check)
        // In production, this would verify actual DB connectivity
        return authService.isAuthenticated
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(SupabaseAuthService.shared)
}
