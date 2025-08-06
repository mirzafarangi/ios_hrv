import SwiftUI

struct MainContentView: View {
    @StateObject private var coreEngine = CoreEngine.shared
    
    var body: some View {
        Group {
            if coreEngine.isAuthenticated {
                // Main app with tabs - Clean fresh start with core functionality only
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
