import SwiftUI

struct TrendsTabView: View {
    @StateObject private var viewModel = BaselineViewModel()
    @State private var showParametersSheet = false
    @State private var isTableExpanded = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // KPI Chips Section
                    kpiChipsSection
                    
                    // Context Line
                    contextLineSection
                    
                    // Global Legend Card
                    legendCard
                    
                    // Plots Card (Empty for now)
                    plotsCard
                    
                    // Stats Table Card
                    statsTableCard
                    
                    // Footnotes/Methods Card
                    footnotesCard
                }
                .padding()
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showParametersSheet = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.refreshData()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .sheet(isPresented: $showParametersSheet) {
                ParametersSheet(viewModel: viewModel)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading baseline data...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            }
        }
    }
    
    // MARK: - KPI Chips Section
    private var kpiChipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Performance Indicators")
                .font(.headline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.kpis, id: \.metric) { kpi in
                    KPIChipView(kpi: kpi)
                }
            }
        }
    }
    
    // MARK: - Context Line Section
    private var contextLineSection: some View {
        Group {
            if let data = viewModel.baselineData {
                HStack {
                    Text("Fixed m=\(data.mPointsRequested), Rolling n=\(data.nPointsRequested)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let updated = viewModel.lastUpdated {
                        Text("Updated \(updated, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Legend Card
    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Global Style Key")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color(hex: "#0072B2"))
                        .frame(width: 30, height: 2)
                    Text("Fixed baseline (m)")
                        .font(.caption)
                }
                
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color(hex: "#D55E00"))
                        .frame(width: 30, height: 2)
                        .overlay(
                            Rectangle()
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                                .foregroundColor(Color(hex: "#D55E00"))
                        )
                    Text("Rolling mean (n)")
                        .font(.caption)
                }
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color(hex: "#0072B2").opacity(0.25))
                            .frame(width: 15, height: 10)
                        Rectangle()
                            .fill(Color(hex: "#0072B2").opacity(0.15))
                            .frame(width: 15, height: 10)
                    }
                    Text("±1 SD (darker) and ±2 SD (lighter)")
                        .font(.caption)
                }
                
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: "#7F7F7F"))
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#4D4D4D"), lineWidth: 1)
                        )
                    Text("Sessions")
                        .font(.caption)
                }
                
                Text("Timescale: Session Index (equal spacing) · Real Date/Time shown on top axis")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Plots Card (Empty for now)
    private var plotsCard: some View {
        VStack {
            Text("Baseline Plots")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 300)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Plots will be implemented here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
        }
    }
    
    // MARK: - Stats Table Card
    private var statsTableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Session Statistics")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isTableExpanded.toggle()
                    }
                }) {
                    Image(systemName: isTableExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            if isTableExpanded {
                if let sessions = viewModel.baselineData?.dynamicBaseline {
                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header
                            HStack(spacing: 0) {
                                Text("Session #")
                                    .frame(width: 80, alignment: .leading)
                                    .font(.caption.bold())
                                
                                Text("DateTime")
                                    .frame(width: 120, alignment: .leading)
                                    .font(.caption.bold())
                                
                                Text("RMSSD")
                                    .frame(width: 70, alignment: .trailing)
                                    .font(.caption.bold())
                                
                                Text("SDNN")
                                    .frame(width: 70, alignment: .trailing)
                                    .font(.caption.bold())
                                
                                Text("SD2/SD1")
                                    .frame(width: 70, alignment: .trailing)
                                    .font(.caption.bold())
                                
                                Text("Mean HR")
                                    .frame(width: 70, alignment: .trailing)
                                    .font(.caption.bold())
                                
                                Text("Roll RMSSD")
                                    .frame(width: 80, alignment: .trailing)
                                    .font(.caption.bold())
                                
                                Text("Roll SDNN")
                                    .frame(width: 80, alignment: .trailing)
                                    .font(.caption.bold())
                                
                                Text("Subtags")
                                    .frame(width: 100, alignment: .leading)
                                    .font(.caption.bold())
                            }
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemBackground))
                            
                            Divider()
                            
                            // Data rows
                            ForEach(Array(sessions.suffix(viewModel.k).enumerated()), id: \.element.sessionId) { index, session in
                                HStack(spacing: 0) {
                                    Text("\(session.sessionIndex)")
                                        .frame(width: 80, alignment: .leading)
                                        .font(.caption)
                                    
                                    Text(viewModel.formatTimestamp(session.timestamp))
                                        .frame(width: 120, alignment: .leading)
                                        .font(.caption)
                                    
                                    Text(formatMetric(session.metrics["rmssd"] ?? nil, decimals: 1))
                                        .frame(width: 70, alignment: .trailing)
                                        .font(.caption.monospacedDigit())
                                    
                                    Text(formatMetric(session.metrics["sdnn"] ?? nil, decimals: 1))
                                        .frame(width: 70, alignment: .trailing)
                                        .font(.caption.monospacedDigit())
                                    
                                    Text(formatMetric(session.metrics["sd2_sd1"] ?? nil, decimals: 2))
                                        .frame(width: 70, alignment: .trailing)
                                        .font(.caption.monospacedDigit())
                                    
                                    Text(formatMetric(session.metrics["mean_hr"] ?? nil, decimals: 0))
                                        .frame(width: 70, alignment: .trailing)
                                        .font(.caption.monospacedDigit())
                                    
                                    Text(formatMetric(session.rollingStats["rmssd"]??.mean, decimals: 1))
                                        .frame(width: 80, alignment: .trailing)
                                        .font(.caption.monospacedDigit())
                                    
                                    Text(formatMetric(session.rollingStats["sdnn"]??.mean, decimals: 1))
                                        .frame(width: 80, alignment: .trailing)
                                        .font(.caption.monospacedDigit())
                                    
                                    Text(session.tags.joined(separator: ", "))
                                        .frame(width: 100, alignment: .leading)
                                        .font(.caption)
                                }
                                .padding(.vertical, 4)
                                .background(index % 2 == 0 ? Color.clear : Color(.quaternarySystemFill))
                                
                                if index < sessions.suffix(viewModel.k).count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                } else {
                    Text("No session data available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Footnotes Card
    private var footnotesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Methods & Notes")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• SD bands: Standard deviation bands calculated from baseline sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• Median-based SD: MAD × 1.4826 for robust outlier detection")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• Significance: |z-score| ≥ 1.96 indicates statistical significance (p < 0.05)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• Non-negative clamp: Negative values displayed as 0 for physiological validity")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Helper Functions
    private func formatMetric(_ value: Double?, decimals: Int) -> String {
        guard let value = value else { return "—" }
        return String(format: "%.\(decimals)f", value)
    }
}

// MARK: - KPI Chip View
struct KPIChipView: View {
    let kpi: MetricKPI
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(kpi.label)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(kpi.directionSymbol)
                    .font(.caption.bold())
                    .foregroundColor(Color(hex: kpi.directionColor))
            }
            
            HStack(alignment: .bottom, spacing: 4) {
                Text(kpi.formattedValue)
                    .font(.title2.bold().monospacedDigit())
                
                Text(kpi.unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !kpi.formattedDeltaFixed.isEmpty {
                Text("vs fixed: \(kpi.formattedDeltaFixed)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(kpi.direction)
                    .font(.caption2)
                    .foregroundColor(Color(hex: kpi.directionColor))
                
                if let significance = kpi.significance {
                    Text("(\(significance))")
                        .font(.caption2.bold())
                        .foregroundColor(Color(hex: kpi.directionColor))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Parameters Sheet
struct ParametersSheet: View {
    @ObservedObject var viewModel: BaselineViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var tempM: Double
    @State private var tempN: Double
    @State private var tempK: Double
    
    init(viewModel: BaselineViewModel) {
        self.viewModel = viewModel
        _tempM = State(initialValue: Double(viewModel.m))
        _tempN = State(initialValue: Double(viewModel.n))
        _tempK = State(initialValue: Double(viewModel.k))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Fixed Baseline (m)")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("m = \(Int(tempM)) sessions")
                                .font(.body.monospacedDigit())
                            Spacer()
                        }
                        Slider(value: $tempM, in: 5...30, step: 1)
                        Text("Number of sessions for fixed baseline calculation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Rolling Window (n)")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("n = \(Int(tempN)) sessions")
                                .font(.body.monospacedDigit())
                            Spacer()
                        }
                        Slider(value: $tempN, in: 3...20, step: 1)
                        Text("Window size for rolling statistics")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Viewport Sessions (k)")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("k = \(Int(tempK)) sessions")
                                .font(.body.monospacedDigit())
                            Spacer()
                        }
                        Slider(value: $tempK, in: 5...50, step: 1)
                        Text("Number of sessions to display in table")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(action: {
                        tempM = 13
                        tempN = 7
                        tempK = 13
                    }) {
                        Text("Reset to Defaults")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Parameters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        viewModel.m = Int(tempM)
                        viewModel.n = Int(tempN)
                        viewModel.k = Int(tempK)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    TrendsTabView()
}
