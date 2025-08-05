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
                    
                    // Analysis Tab - HRV Data Visualization
                    VisualizationsTabView()
                        .tabItem {
                            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                            Text("Analysis")
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
