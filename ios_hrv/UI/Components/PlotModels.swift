import SwiftUI
import Foundation

// MARK: - Plot Data Models

struct PlotResult {
    let image: UIImage
    let statistics: PlotStatistics?
}

// Note: PlotStatistics is defined in DatabaseHRVPlotsManager.swift

// MARK: - Plot Display Components

struct HRVPlotCard: View {
    let title: String
    let plotResult: PlotResult
    let tag: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card Header
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("\(tag.capitalized) Analysis")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Plot Image
            Image(uiImage: plotResult.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Statistics
            if let stats = plotResult.statistics {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Statistics Summary")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        PlotDisplayStatisticItem(label: "Mean", value: String(format: "%.1f", stats.mean))
                        PlotDisplayStatisticItem(label: "Std Dev", value: String(format: "%.1f", stats.std))
                        PlotDisplayStatisticItem(label: "Min", value: String(format: "%.1f", stats.min))
                        PlotDisplayStatisticItem(label: "Max", value: String(format: "%.1f", stats.max))
                    }
                    
                    HStack {
                        Text("P10: \(String(format: "%.1f", stats.p10)) | P90: \(String(format: "%.1f", stats.p90))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct PlotDisplayStatisticItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct TagButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}
