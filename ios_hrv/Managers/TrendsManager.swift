import Foundation
import Combine

/// View model for the Trends tab
/// Manages data fetching, caching, and UI state for all three trend types
@MainActor
class TrendsManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var trendsData: TrendsResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    
    // MARK: - Dependencies
    private let networkManager = HRVNetworkManager.shared
    private let authService = SupabaseAuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var canRefresh: Bool {
        networkManager.canFetch()
    }
    
    var refreshCooldownTime: Int {
        Int(networkManager.getRemainingCooldownTime())
    }
    
    var hasData: Bool {
        trendsData != nil
    }
    
    // MARK: - Initialization
    init() {
        setupBindings()
        loadCachedData()
    }
    
    // MARK: - Public Methods
    
    /// Fetch trends data (with caching and rate limiting)
    func fetchTrends(forceRefresh: Bool = false) async {
        guard let userId = authService.currentUser?.id else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let trends = try await networkManager.fetchTrends(for: userId, forceRefresh: forceRefresh)
            
            await MainActor.run {
                self.trendsData = trends
                self.lastUpdated = Date()
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Load initial data (cache first, then fetch if needed)
    func loadInitialData() async {
        // Try cache first
        loadCachedData()
        
        // If no cached data or data is old, fetch fresh
        if trendsData == nil || shouldRefreshData() {
            await fetchTrends(forceRefresh: false)
        }
    }
    
    /// Clear all data and cache
    func clearData() {
        trendsData = nil
        lastUpdated = nil
        networkManager.clearCache()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind network manager loading state
        networkManager.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        
        // Bind network manager error state
        networkManager.$lastError
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
        
        // Bind network manager last fetch time
        networkManager.$lastFetchTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastUpdated)
    }
    
    private func loadCachedData() {
        // This will be handled by the network manager's cache
        // The cached data will be returned automatically in fetchTrends
    }
    
    private func shouldRefreshData() -> Bool {
        guard let lastUpdated = lastUpdated else { return true }
        
        // Refresh if data is older than 5 minutes
        let refreshInterval: TimeInterval = 5 * 60
        return Date().timeIntervalSince(lastUpdated) > refreshInterval
    }
}

// MARK: - Trend Type Access

extension TrendsManager {
    
    /// Get data for specific trend type
    func getData(for type: TrendType) -> TrendData? {
        guard let trends = trendsData else { return nil }
        
        switch type {
        case .rest:
            return trends.restTrend
        case .sleepEvent:
            return trends.sleepEvent
        case .sleepBaseline:
            return trends.sleepBaseline
        }
    }
    
    /// Get chart data for specific trend type
    func getChartData(for type: TrendType) -> [ChartDataPoint] {
        return getData(for: type)?.chartDataPoints ?? []
    }
    
    /// Get statistics for specific trend type
    func getStatistics(for type: TrendType) -> TrendStatistics? {
        return getData(for: type)?.statistics
    }
}
