import SwiftUI

/// Charts tab with modular RMSSD trend analysis
/// Implements polish_architecture.md specifications for unified chart architecture
struct ChartsTabView: View {
    
    // MARK: - State
    
    @StateObject private var viewModel = TrendChartViewModel()
    @State private var selectedTrendType: TrendType = .rest
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Trend Type Selector
                    trendTypeSelector
                    
                    // Main Chart
                    TrendChartView(viewModel: viewModel, height: 300)
                    
                    // Additional Info
                    additionalInfoCard
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("HRV Trends")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear Cache") {
                        viewModel.clearCache()
                    }
                    .font(.caption)
                }
            }
        }
        .onAppear {
            viewModel.selectTrendType(selectedTrendType)
        }
    }
    
    // MARK: - Trend Type Selector
    
    private var trendTypeSelector: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RMSSD Trend Analysis")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(TrendType.allCases, id: \.self) { trendType in
                    trendTypeCard(for: trendType)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func trendTypeCard(for trendType: TrendType) -> some View {
        Button(action: {
            selectedTrendType = trendType
            viewModel.selectTrendType(trendType)
        }) {
            HStack(spacing: 12) {
                // Selection indicator
                Circle()
                    .fill(selectedTrendType == trendType ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(trendType.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(trendType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Trend type icon
                Image(systemName: trendType.iconName)
                    .font(.body)
                    .foregroundColor(selectedTrendType == trendType ? .blue : .gray)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTrendType == trendType ? Color.blue.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedTrendType == trendType ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Additional Info Card
    
    private var additionalInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About RMSSD Trends")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                infoRow(title: "Rest Trend", description: "Individual non-sleep sessions over time")
                infoRow(title: "Sleep Intervals", description: "All intervals from your most recent sleep event")
                infoRow(title: "Sleep Events", description: "Aggregated sleep event data over time")
            }
            
            Divider()
            
            Text("Chart Elements")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 6) {
                legendRow(color: .blue, style: "●", label: "Raw RMSSD data points")
                legendRow(color: .blue.opacity(0.7), style: "- -", label: "Rolling average (when available)")
                legendRow(color: .gray, style: "—", label: "Baseline (7-day sleep average)")
                legendRow(color: .blue.opacity(0.2), style: "▓", label: "Standard deviation bands")
                legendRow(color: .gray, style: "· ·", label: "10th/90th percentiles")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func infoRow(title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.blue)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func legendRow(color: Color, style: String, label: String) -> some View {
        HStack(spacing: 8) {
            Text(style)
                .foregroundColor(color)
                .font(.body)
                .fontWeight(.bold)
                .frame(width: 20)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    ChartsTabView()
}
