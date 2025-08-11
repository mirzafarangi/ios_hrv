import Foundation
import Combine

@MainActor
class BaselineViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var baselineData: BaselineResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    
    // Hyperparameters
    @Published var m: Int = 14 { // Fixed baseline points
        didSet { if m != oldValue { fetchBaselineData() } }
    }
    @Published var n: Int = 7 { // Rolling window size
        didSet { if n != oldValue { fetchBaselineData() } }
    }
    @Published var k: Int = 30 { // Viewport sessions (UI only)
        didSet { updateVisibleSessions() }
    }
    
    // Computed properties for UI
    @Published var kpis: [MetricKPI] = []
    @Published var visibleSessions: [DynamicBaselineSession] = []
    
    // MARK: - Private Properties
    private let apiClient = APIClient()
    private var cancellables = Set<AnyCancellable>()
    
    // Metrics configuration matching blueprint_baseline_app.md
    private let metricsConfig = [
        ("rmssd", "RMSSD", "ms"),
        ("sdnn", "SDNN", "ms"),
        ("sd2_sd1", "SD2/SD1", ""),
        ("mean_hr", "Mean HR", "bpm")
    ]
    
    // MARK: - Initialization
    init() {
        // Fetch data on initialization
        fetchBaselineData()
    }
    
    // MARK: - Public Methods
    
    func fetchBaselineData() {
        Task {
            await loadBaselineData()
        }
    }
    
    func refreshData() {
        fetchBaselineData()
    }
    
    // MARK: - Private Methods
    
    private func loadBaselineData() async {
        // Get authenticated user ID
        guard let userId = await getCurrentUserId() else {
            await MainActor.run {
                self.errorMessage = "User not authenticated"
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // Call baseline API endpoint via APIClient
            let response = try await apiClient.getBaselineAnalytics(
                userId: userId,
                m: m,
                n: n,
                metrics: metricsConfig.map { $0.0 },
                maxSessions: 300
            )
            
            await MainActor.run {
                self.baselineData = response
                self.lastUpdated = Date()
                self.updateKPIs()
                self.updateVisibleSessions()
                self.isLoading = false
                
                // Log warnings if any
                if !response.warnings.isEmpty {
                    print("⚠️ Baseline warnings: \(response.warnings.joined(separator: ", "))")
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load baseline data: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func getCurrentUserId() async -> String? {
        // Get user ID from SupabaseAuthService
        return await SupabaseAuthService.shared.getCurrentUserId()
    }
    
    private func updateKPIs() {
        guard let data = baselineData else {
            kpis = []
            return
        }
        
        // Get the latest session (or latest visible if k is set)
        let latestSession: DynamicBaselineSession?
        if k == 0 || k >= data.dynamicBaseline.count {
            // Use absolute latest
            latestSession = data.dynamicBaseline.last
        } else {
            // Use latest in viewport
            latestSession = visibleSessions.last
        }
        
        guard let session = latestSession else {
            kpis = []
            return
        }
        
        // Build KPIs for each metric according to blueprint_baseline_app.md
        kpis = metricsConfig.compactMap { (metric, label, unit) in
            guard data.metrics.contains(metric) else { return nil }
            
            let value = session.metrics[metric] ?? nil
            let trends = session.trends[metric]
            
            return MetricKPI(
                metric: metric,
                label: label,
                unit: unit,
                value: value,
                deltaFixed: trends?.deltaVsFixed,
                pctFixed: trends?.pctVsFixed,
                deltaRolling: trends?.deltaVsRolling,
                pctRolling: trends?.pctVsRolling,
                direction: trends?.direction ?? "stable",
                significance: trends?.significance
            )
        }
    }
    
    private func updateVisibleSessions() {
        guard let data = baselineData else {
            visibleSessions = []
            return
        }
        
        let sessions = data.dynamicBaseline
        
        // Handle viewport parameter k
        if k == 0 || k >= sessions.count {
            // Show all sessions
            visibleSessions = sessions
        } else {
            // Show last k sessions
            visibleSessions = Array(sessions.suffix(k))
        }
        
        // Update KPIs when visible sessions change
        updateKPIs()
    }
    
    // MARK: - Formatting Helpers
    
    func formatTimestamp(_ timestamp: String) -> String {
        // Parse ISO8601 timestamp and format for display
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: timestamp) else {
            return timestamp
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        displayFormatter.timeZone = TimeZone.current
        
        return displayFormatter.string(from: date)
    }
    
    func formatSessionDateTime(_ timestamp: String) -> (date: String, time: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: timestamp) else {
            return (timestamp, "")
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        return (dateFormatter.string(from: date), timeFormatter.string(from: date))
    }
    
    // MARK: - Context Helpers
    
    var contextLine: String {
        guard let data = baselineData else {
            return "No baseline data available"
        }
        
        let mActual = data.fixedBaseline["rmssd"]?.count ?? 0
        let dateStr = lastUpdated != nil ? formatTimestamp(data.updatedAt) : "Never"
        
        return "Fixed m=\(m) (actual: \(mActual)), Rolling n=\(n) · Updated \(dateStr)"
    }
    
    var hasData: Bool {
        return baselineData != nil && !(baselineData?.dynamicBaseline.isEmpty ?? true)
    }
}
