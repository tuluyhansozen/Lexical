import SwiftUI
import Charts
import SwiftData
import LexicalCore

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedPeriod: StatsPeriod = .last30
    @State private var acquiredCount: Int = 0
    @State private var retentionRate: Double = 0.0
    @State private var currentStreak: Int = 0
    @State private var curvePoints: [(Double, Double)] = []
    @State private var heatmapPoints: [HeatmapPoint] = []

    var body: some View {
        ZStack {
            Color.adaptiveBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.sonPrimary)
                            .padding(10)
                            .background(Color.adaptiveSurface)
                            .clipShape(Circle())
                    }
                    .opacity(0)

                    Spacer()

                    Text("Learning Statistics")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.adaptiveText)

                    Spacer()

                    Button { } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.sonPrimary)
                            .padding(10)
                            .background(Color.adaptiveSurface)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .padding(.top, 10)

                ScrollView {
                    VStack(spacing: 24) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(StatsPeriod.allCases, id: \.rawValue) { period in
                                    FilterChip(
                                        label: period.label,
                                        isSelected: selectedPeriod == period
                                    ) {
                                        selectedPeriod = period
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }

                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 12
                        ) {
                            StatCard(
                                title: "ACQUIRED",
                                value: "\(acquiredCount)",
                                subtitle: selectedPeriod.shortLabel,
                                subtitleColor: .sonPrimary
                            )
                            StatCard(
                                title: "RETENTION",
                                value: String(format: "%.0f%%", retentionRate * 100),
                                subtitle: selectedPeriod.shortLabel,
                                subtitleColor: .green
                            )
                            StatCard(
                                title: "STREAK",
                                value: "\(currentStreak)",
                                subtitle: "Days",
                                subtitleColor: .orange
                            )
                        }
                        .padding(.horizontal, 20)

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
                            }

                            Chart {
                                ForEach(curvePoints, id: \.0) { point in
                                    LineMark(
                                        x: .value("Day", point.0),
                                        y: .value("Retention", point.1)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(Color.sonPrimary)

                                    AreaMark(
                                        x: .value("Day", point.0),
                                        y: .value("Retention", point.1)
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
                            .frame(height: 180)
                        }
                        .padding(20)
                        .background(Color.adaptiveSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Activity Heatmap")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.adaptiveText)
                                Text("Daily review activity")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HeatmapGrid(points: heatmapPoints)
                        }
                        .padding(20)
                        .background(Color.adaptiveSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 20)

                        Color.clear.frame(height: 100)
                    }
                    .padding(.top, 10)
                }
            }
        }
        .task {
            await loadStats()
        }
        .onChange(of: selectedPeriod) {
            Task {
                await loadStats()
            }
        }
    }

    private func loadStats() async {
        let service = StatsService(modelContext: modelContext)
        let snapshot = service.loadSnapshot(period: selectedPeriod)
        acquiredCount = snapshot.acquiredCount
        retentionRate = snapshot.retentionRate
        currentStreak = snapshot.streak
        curvePoints = snapshot.curvePoints
        heatmapPoints = snapshot.heatmap
    }
}

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

struct HeatmapGrid: View {
    let points: [HeatmapPoint]
    private let rows = Array(repeating: GridItem(.fixed(12), spacing: 4), count: 7)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: rows, spacing: 4) {
                ForEach(points) { point in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: point.count))
                        .frame(width: 12, height: 12)
                }
            }
        }
    }

    private func color(for count: Int) -> Color {
        let maxCount = max(points.map(\.count).max() ?? 1, 1)
        let normalized = Double(count) / Double(maxCount)
        switch normalized {
        case ..<0.01:
            return Color.gray.opacity(0.10)
        case ..<0.25:
            return Color.sonPrimary.opacity(0.25)
        case ..<0.5:
            return Color.sonPrimary.opacity(0.45)
        case ..<0.75:
            return Color.sonPrimary.opacity(0.70)
        default:
            return Color.sonPrimary
        }
    }
}

#Preview {
    StatsView()
}
