import SwiftUI
import Charts

struct StatsView: View {
    @State private var selectedPeriod = 0 // 0: 30 days, 1: 90 days, 2: Year
    
    var body: some View {
        ZStack {
            Color.adaptiveBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button {
                        // Back
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.sonPrimary)
                            .padding(10)
                            .background(Color.adaptiveSurface)
                            .clipShape(Circle())
                    }
                    .opacity(0) // Hidden but takes space if needed, or just Spacer
                    
                    Spacer()
                    
                    Text("Learning Statistics")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText)
                    
                    Spacer()
                    
                    Button {
                        // Calendar
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.sonPrimary)
                            .padding(10)
                            .background(Color.adaptiveSurface) // In dark mode surface is distinct?
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .padding(.top, 10) // Safe area top
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Period Filter
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                FilterChip(label: "Last 30 Days", isSelected: selectedPeriod == 0) { selectedPeriod = 0 }
                                FilterChip(label: "Last 90 Days", isSelected: selectedPeriod == 1) { selectedPeriod = 1 }
                                FilterChip(label: "This Year", isSelected: selectedPeriod == 2) { selectedPeriod = 2 }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }
                        
                        // Key Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCard(title: "ACQUIRED", value: "1,240", subtitle: "+12 today", subtitleColor: .sonPrimary)
                            StatCard(title: "RETENTION", value: "85%", subtitle: "Stable", subtitleColor: .green)
                            StatCard(title: "STREAK", value: "12", subtitle: "Keep it up!", subtitleColor: .orange)
                        }
                        .padding(.horizontal, 20)
                        
                        // Forgetting Curve Chart
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Forgetting Curve")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.adaptiveText)
                                    Text("Projected memory decay without review")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                    Text("High")
                                }
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            
                            // Mock Chart
                            ForgettingCurveChart()
                                .frame(height: 180)
                        }
                        .padding(20)
                        .background(Color.adaptiveSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 20)
                        
                        // Heatmap
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Activity Heatmap")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.adaptiveText)
                                Text("342 contributions in the last year")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HeatmapGrid()
                        }
                        .padding(20)
                        .background(Color.adaptiveSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 20)
                        
                        Color.clear.frame(height: 100) // Bottom spacer
                    }
                    .padding(.top, 10)
                }
            }
        }
    }
}

// Components

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.sonPrimary : Color.adaptiveSurface)
                .foregroundStyle(isSelected ? .white : Color.sonPrimary)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.sonPrimary.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let subtitleColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.adaptiveText)
            
            Text(subtitle)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(subtitleColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.adaptiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct ForgettingCurveChart: View {
    var body: some View {
        Chart {
            ForEach(0..<10, id: \.self) { i in
                // Mock decaying curve data y = 100 * e^(-0.3 * x)
                let x = Double(i)
                let y = 100.0 * exp(-0.3 * x)
                LineMark(
                    x: .value("Day", x),
                    y: .value("Retention", y)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.sonPrimary)
                
                AreaMark(
                    x: .value("Day", x),
                    y: .value("Retention", y)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.sonPrimary.opacity(0.3), Color.sonPrimary.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: [0, 2, 6, 9]) { value in
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text(intValue == 0 ? "Now" : "\(intValue)d")
                            .font(.caption2)
                    }
                }
            }
        }
    }
}

struct HeatmapGrid: View {
    let columns = Array(repeating: GridItem(.fixed(12), spacing: 4), count: 14) // 14 weeks approx
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: Array(repeating: GridItem(.fixed(12), spacing: 4), count: 7), spacing: 4) {
                ForEach(0..<98, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForIndex(index))
                        .frame(width: 12, height: 12)
                }
            }
        }
    }
    
    func colorForIndex(_ index: Int) -> Color {
        // Randomize mock data
        let intensity = Int.random(in: 0...4)
        switch intensity {
        case 0: return Color.gray.opacity(0.1)
        case 1: return Color.sonPrimary.opacity(0.2)
        case 2: return Color.sonPrimary.opacity(0.4)
        case 3: return Color.sonPrimary.opacity(0.7)
        default: return Color.sonPrimary
        }
    }
}
