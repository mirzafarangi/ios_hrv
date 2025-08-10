import SwiftUI
import PostgREST

struct ProfileTabView: View {
    @StateObject private var authService = SupabaseAuthService.shared
    @State private var showingSignOutAlert = false
    @State private var showingErrorAlert = false
    @State private var showingSuccessAlert = false
    @State private var errorMessage = ""
    @State private var apiPulse = false
    @State private var dbPulse = false
    @State private var phaseShift: Double = 0
    
    // Real-time status monitoring
    @State private var apiStatus = false
    @State private var dbStatus = false
    @State private var statusLogs: [String] = []
    @State private var lastCheckTime = Date()
    @State private var isCheckingStatus = false
    @State private var isPhiChecking = false  // Special state for phi-triggered checks
    
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
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
                                        .fill(isPhiChecking ? Color.orange.opacity(0.2) : (apiPulse ? Color.green.opacity(0.2) : Color.clear))
                                        .frame(width: 24, height: 24)
                                        .scaleEffect(isPhiChecking || apiPulse ? 1.5 : 1.0)
                                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPhiChecking || apiPulse)
                                    
                                    Circle()
                                        .fill(isPhiChecking ? Color.orange : (apiStatus ? Color.green : Color.red))
                                        .frame(width: 12, height: 12)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                                        )
                                }
                                
                                Text("API")
                                    .font(.system(size: 10, weight: .light, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.5))
                            }
                            
                            // DB Status LED
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(isPhiChecking ? Color.orange.opacity(0.2) : (dbPulse ? Color.green.opacity(0.2) : Color.clear))
                                        .frame(width: 24, height: 24)
                                        .scaleEffect(isPhiChecking || dbPulse ? 1.5 : 1.0)
                                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPhiChecking || dbPulse)
                                    
                                    Circle()
                                        .fill(isPhiChecking ? Color.orange : (dbStatus ? Color.green : Color.red))
                                        .frame(width: 12, height: 12)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                                        )
                                }
                                
                                Text("DB")
                                    .font(.system(size: 10, weight: .light, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.5))
                            }
                        }
                    }
                    
                    Spacer().frame(height: 30)
                    
                    // Status Log Display - Integrated with LUMENIS greeting
                    VStack(alignment: .leading, spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                // LUMENIS greeting header inside the log box
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Hello, I'm LUMENIS, your HRV Analyzer assistant")
                                        .font(.system(size: 10, weight: .medium, design: .default))
                                        .foregroundColor(.black.opacity(0.7))
                                    
                                    HStack(spacing: 4) {
                                        Text("Current status of")
                                            .font(.system(size: 9, weight: .light, design: .monospaced))
                                            .foregroundColor(.black.opacity(0.5))
                                        
                                        HStack(spacing: 6) {
                                            Text("API:")
                                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                            Circle()
                                                .fill(isPhiChecking ? Color.orange : (apiStatus ? Color.green : Color.red))
                                                .frame(width: 6, height: 6)
                                            
                                            Text("DB:")
                                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                            Circle()
                                                .fill(isPhiChecking ? Color.orange : (dbStatus ? Color.green : Color.red))
                                                .frame(width: 6, height: 6)
                                        }
                                        .foregroundColor(.black.opacity(0.6))
                                        
                                        Spacer()
                                        
                                        if isCheckingStatus {
                                            ProgressView()
                                                .scaleEffect(0.5)
                                                .frame(width: 10, height: 10)
                                        }
                                    }
                                }
                                .padding(.bottom, 6)
                                
                                Divider()
                                    .background(Color.black.opacity(0.1))
                                    .padding(.bottom, 4)
                                
                                // Status logs
                                ForEach(statusLogs.suffix(4).reversed(), id: \.self) { log in
                                    Text(log)
                                        .font(.system(size: 9, weight: .light, design: .monospaced))
                                        .foregroundColor(.black.opacity(0.6))
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 100)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                                )
                        )
                    }
                    .padding(.horizontal, 24)
                    .refreshable {
                        await checkSystemStatus()
                    }
                    
                    Spacer().frame(height: 30)
                    
                    // Our secret signature - a mathematical constant only we understand
                    // φ (phi) = 1.618... the golden ratio, representing perfect harmony
                    // SECRET: This is actually a refresh button for LUMENIS brain control
                    Button(action: {
                        Task {
                            await phiRefresh()
                        }
                    }) {
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
                phaseShift = 1
                Task {
                    await checkSystemStatus()
                }
            }
            .onReceive(timer) { _ in
                Task {
                    await checkSystemStatus()
                }
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
    
    @MainActor
    private func phiRefresh() async {
        // Clear logs and reset with LUMENIS greeting
        statusLogs.removeAll()
        statusLogs.append("Got you! φ clicked - LUMENIS brain refresh initiated...")
        
        // Set LEDs to orange during check
        isPhiChecking = true
        apiStatus = false
        dbStatus = false
        apiPulse = false
        dbPulse = false
        
        // Small delay to show orange state
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Perform the actual status check
        await checkSystemStatus()
        
        // Turn off phi checking state after status check completes
        isPhiChecking = false
        
        // Add completion message
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeString = formatter.string(from: timestamp)
        statusLogs.append("[\(timeString)] Brain refresh complete")
    }
    
    @MainActor
    private func checkSystemStatus() async {
        isCheckingStatus = true
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeString = formatter.string(from: timestamp)
        
        // Check API Status
        let apiResult = await checkAPIHealth()
        apiStatus = apiResult
        apiPulse = apiResult
        
        // Check DB Status  
        let dbResult = await checkDBHealth()
        dbStatus = dbResult
        dbPulse = dbResult
        
        // Add to status log
        let statusEntry = "[\(timeString)] API: \(apiResult ? "✓" : "✗") | DB: \(dbResult ? "✓" : "✗")"
        statusLogs.append(statusEntry)
        
        // Keep only last 20 entries
        if statusLogs.count > 20 {
            statusLogs.removeFirst(statusLogs.count - 20)
        }
        
        lastCheckTime = timestamp
        isCheckingStatus = false
    }
    
    private func checkAPIHealth() async -> Bool {
        guard let url = URL(string: "https://hrv-brain-api-production.up.railway.app/health") else {
            return false
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                let isHealthy = httpResponse.statusCode == 200
                if !isHealthy {
                    statusLogs.append("  → API returned \(httpResponse.statusCode)")
                }
                return isHealthy
            }
        } catch {
            statusLogs.append("  → API error: \(error.localizedDescription.prefix(30))...")
        }
        return false
    }
    
    private func checkDBHealth() async -> Bool {
        // Check Supabase client connection
        guard authService.isAuthenticated else {
            statusLogs.append("  → DB: Not authenticated")
            return false
        }
        
        // Try a simple query to verify DB connectivity
        do {
            // Get current access token for authenticated query
            guard let token = await authService.getCurrentAccessToken() else {
                statusLogs.append("  → DB: No access token")
                return false
            }
            
            // Create authenticated client
            let client = PostgrestClient(
                url: URL(string: "\(SupabaseConfig.url)/rest/v1")!,
                schema: "public",
                headers: [
                    "apikey": SupabaseConfig.anonKey,
                    "Authorization": "Bearer \(token)"
                ],
                logger: nil
            )
            
            // Simple query to test connection with auth
            // Use a count query which is lightweight and reliable
            let response = try await client
                .from("sessions")
                .select("*", head: false, count: .exact)
                .eq("user_id", value: authService.userId ?? "")
                .limit(0)  // Don't fetch any rows, just test connection
                .execute()
            
            // If we get here without throwing, the connection is good
            return true
        } catch {
            statusLogs.append("  → DB error: \(error.localizedDescription.prefix(30))...")
            return false
        }
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(SupabaseAuthService.shared)
}
