import SwiftUI
import Foundation

struct ModelTabView: View {
    @EnvironmentObject var coreEngine: CoreEngine
    @State private var selectedTag = "rest"
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Available tags for selection
    private let availableTags = ["rest", "sleep", "experiment_paired_pre", "experiment_paired_post", "experiment_duration", "breath_workout"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("HRV Modeling")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Statistics & Recovery Indices")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Tag Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Session Type:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableTags, id: \.self) { tag in
                                    TagButton(
                                        title: tag.capitalized,
                                        isSelected: selectedTag == tag,
                                        action: { selectedTag = tag }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Statistics Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Statistical Analysis")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        // Placeholder for statistics cards
                        VStack(spacing: 12) {
                            StatisticsPlaceholderCard(title: "Descriptive Statistics", subtitle: "Mean, SD, Min/Max, Percentiles")
                            StatisticsPlaceholderCard(title: "Time Domain Analysis", subtitle: "RMSSD, SDNN, pNN50, CV_RR")
                            StatisticsPlaceholderCard(title: "Frequency Domain", subtitle: "LF, HF, LF/HF Ratio")
                        }
                        .padding(.horizontal)
                    }
                    
                    // Modeling Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Advanced Modeling")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        // Placeholder for modeling cards
                        VStack(spacing: 12) {
                            StatisticsPlaceholderCard(title: "Recovery Stress Index", subtitle: "Custom RSI based on HRV trends")
                            StatisticsPlaceholderCard(title: "Readiness Score", subtitle: "Multi-metric readiness assessment")
                            StatisticsPlaceholderCard(title: "Trend Analysis", subtitle: "Long-term pattern recognition")
                        }
                        .padding(.horizontal)
                    }
                    
                    // Coming Soon Notice
                    VStack(spacing: 8) {
                        Image(systemName: "gear.badge")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        Text("Coming Soon")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Advanced statistical modeling and recovery indices are in development")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Model")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct StatisticsPlaceholderCard: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}



#Preview {
    ModelTabView()
        .environmentObject(CoreEngine.shared)
}
