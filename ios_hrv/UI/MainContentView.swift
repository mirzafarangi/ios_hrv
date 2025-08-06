import SwiftUI

struct MainContentView: View {
    @StateObject private var coreEngine = CoreEngine.shared
    
    var body: some View {
        Group {
            if coreEngine.isAuthenticated {
                // Main app with tabs
                TabView {
                    // Record Tab
                    RecordTabView()
                        .tabItem {
                            Image(systemName: "heart.circle.fill")
                            Text("Record")
                        }
                    
                    // Sessions Tab
                    SessionsTabView()
                        .tabItem {
                            Image(systemName: "list.bullet.clipboard.fill")
                            Text("Sessions")
                        }
                    
                    // Rest Tab - Rest Baseline Trends
                    RestTabView()
                        .tabItem {
                            Image(systemName: "figure.walk")
                            Text("Rest")
                        }
                    
                    // Sleep Tab - Sleep Event & Baseline Trends
                    SleepTabView()
                        .tabItem {
                            Image(systemName: "moon.fill")
                            Text("Sleep")
                        }
                    
                    // Model Tab - Statistics & Modeling
                    ModelTabView()
                        .tabItem {
                            Image(systemName: "function")
                            Text("Model")
                        }
                    
                    // Profile Tab
                    ProfileTabView()
                        .tabItem {
                            Image(systemName: "person.circle.fill")
                            Text("Profile")
                        }
                }
                .environmentObject(coreEngine)
            } else {
                // Authentication view
                AuthView()
                    .environmentObject(coreEngine)
            }
        }
        .onAppear {
            print("🚀 MainContentView appeared - Auth state: \(coreEngine.isAuthenticated)")
        }
    }
}

#Preview {
    MainContentView()
}
