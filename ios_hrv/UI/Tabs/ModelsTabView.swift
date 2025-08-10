/**
 * ModelsTabView.swift
 * Models and Analytics tab for HRV iOS App
 * Displays HRV models, analytics, and insights
 */

import SwiftUI
import Charts

struct ModelsTabView: View {
    @EnvironmentObject var coreEngine: CoreEngine
    @StateObject private var databaseManager = DatabaseSessionManager()
    @State private var selectedModel = "Baseline"
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let availableModels = ["Baseline", "Sleep Quality", "Recovery", "Stress", "Performance"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Model Selector
                    modelSelectorCard
                    
                    // Model Visualization
                    modelVisualizationCard
                    
                    // Model Insights
                    modelInsightsCard
                    
                    // Model Parameters
                    modelParametersCard
                }
                .padding()
            }
            .navigationTitle("Models")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Model Selector Card
    private var modelSelectorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Select Model", systemImage: "brain")
                .font(.headline)
                .foregroundColor(.purple)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(availableModels, id: \.self) { model in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedModel = model
                            }
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: modelIcon(for: model))
                                    .font(.system(size: 24))
                                    .foregroundColor(selectedModel == model ? .white : .purple)
                                
                                Text(model)
                                    .font(.caption)
                                    .fontWeight(selectedModel == model ? .semibold : .regular)
                            }
                            .frame(width: 80, height: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedModel == model ? 
                                         Color.purple : Color.purple.opacity(0.1))
                            )
                            .foregroundColor(selectedModel == model ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Model Visualization Card
    private var modelVisualizationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("\(selectedModel) Model", systemImage: "chart.xyaxis.line")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Placeholder chart
            Chart {
                ForEach(sampleDataPoints, id: \.x) { point in
                    LineMark(
                        x: .value("Time", point.x),
                        y: .value("Value", point.y)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    
                    AreaMark(
                        x: .value("Time", point.x),
                        y: .value("Value", point.y)
                    )
                    .foregroundStyle(Color.blue.opacity(0.1).gradient)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(position: .bottom)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Model Insights Card
    private var modelInsightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Key Insights", systemImage: "lightbulb")
                .font(.headline)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 8) {
                insightRow(title: "Current State", value: "Optimal", color: .green)
                insightRow(title: "Trend", value: "Improving", color: .blue)
                insightRow(title: "Recommendation", value: "Maintain routine", color: .purple)
                insightRow(title: "Next Check", value: "Tomorrow 8 AM", color: .orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Model Parameters Card
    private var modelParametersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Model Parameters", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                parameterRow(name: "Sensitivity", value: 0.75)
                parameterRow(name: "Confidence", value: 0.82)
                parameterRow(name: "Accuracy", value: 0.91)
                parameterRow(name: "Data Points", value: 0.68)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Views
    private func insightRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.vertical, 4)
    }
    
    private func parameterRow(name: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(parameterColor(for: value).gradient)
                        .frame(width: geometry.size.width * value, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - Helper Functions
    private func modelIcon(for model: String) -> String {
        switch model {
        case "Baseline":
            return "heart.text.square"
        case "Sleep Quality":
            return "moon.zzz"
        case "Recovery":
            return "arrow.triangle.2.circlepath"
        case "Stress":
            return "waveform.path.ecg"
        case "Performance":
            return "chart.line.uptrend.xyaxis"
        default:
            return "brain"
        }
    }
    
    private func parameterColor(for value: Double) -> Color {
        if value >= 0.8 {
            return .green
        } else if value >= 0.6 {
            return .blue
        } else if value >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Sample Data
    private var sampleDataPoints: [(x: Int, y: Double)] {
        [
            (0, 65), (1, 68), (2, 62), (3, 70), (4, 72),
            (5, 68), (6, 65), (7, 63), (8, 67), (9, 71),
            (10, 69), (11, 66), (12, 64), (13, 68), (14, 70)
        ]
    }
}

// MARK: - Preview
struct ModelsTabView_Previews: PreviewProvider {
    static var previews: some View {
        ModelsTabView()
            .environmentObject(CoreEngine.shared)
    }
}
