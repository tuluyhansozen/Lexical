import SwiftUI
import Charts
import SwiftData
import LexicalCore

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedPeriod: StatsPeriod = .last30
    @State private var availablePeriods: [StatsPeriod] = [.last30]
    @State private var isPremiumTier = false
    @State private var showingPremiumOffer = false
    @State private var acquiredCount: Int = 0
    @State private var retentionRate: Double = 0.0
    @State private var currentStreak: Int = 0
    @State private var curvePoints: [(Double, Double)] = []
    @State private var heatmapPoints: [HeatmapPoint] = []

    private let featureGateService = FeatureGateService()

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
                        .font(.sectionTitle)
                        .foregroundStyle(Color.adaptiveText)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("stats.title")

                    Spacer()

                    Button { } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.sonPrimary)
                            .padding(10)
                            .background(Color.adaptiveSurface)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Date range")
                    .accessibilityHint("Selects the statistics time range.")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .padding(.top, 10)

                ScrollView {
                    VStack(spacing: 24) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(StatsPeriod.allCases, id: \.rawValue) { period in
                                    let isUnlocked = availablePeriods.contains(period)
                                    FilterChip(
                                        label: period.label,
                                        isSelected: selectedPeriod == period,
                                        isLocked: !isUnlocked
                                    ) {
                                        if isUnlocked {
                                            selectedPeriod = period
                                        } else {
                                            showingPremiumOffer = true
                                        }
                                    }
                                    .accessibilityIdentifier(period.accessibilityIdentifier)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }

                        if !isPremiumTier {
                            premiumUpsellBanner
                                .padding(.horizontal, 20)
                                .padding(.top, -8)
                        }

                        LazyVGrid(
                            columns: statGridColumns,
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
                            .accessibilityElement()
                            .accessibilityLabel("Forgetting curve")
                            .accessibilityValue(forgettingCurveSummary)
                        }
                        .padding(20)
                        .background(Color.adaptiveSurfaceElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.adaptiveBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.cardShadow.opacity(0.55), radius: 10, x: 0, y: 5)
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

                            HeatmapGrid(
                                points: heatmapPoints,
                                differentiateWithoutColor: differentiateWithoutColor
                            )
                            .accessibilityElement()
                            .accessibilityLabel("Activity heatmap")
                            .accessibilityValue(heatmapSummary)
                        }
                        .padding(20)
                        .background(Color.adaptiveSurfaceElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.adaptiveBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.cardShadow.opacity(0.55), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 20)

                        Color.clear.frame(height: 100)
                    }
                    .padding(.top, 10)
                }
            }
        }
        .task {
            refreshPeriodAccessState()
            await loadStats()
        }
        .onChange(of: selectedPeriod) {
            Task {
                await loadStats()
            }
        }
        .sheet(isPresented: $showingPremiumOffer, onDismiss: {
            refreshPeriodAccessState()
            Task {
                await loadStats()
            }
        }) {
            PremiumOfferView(
                productIDs: SubscriptionEntitlementService.configuredProductIDs(),
                onEntitlementChanged: {
                    refreshPeriodAccessState()
                    Task {
                        await loadStats()
                    }
                }
            )
        }
    }

    private func refreshPeriodAccessState() {
        let available = featureGateService.availableStatsPeriods(modelContext: modelContext)
        availablePeriods = available
        isPremiumTier = featureGateService.activeTier(modelContext: modelContext) == .premium

        if !available.contains(selectedPeriod) {
            selectedPeriod = available.first ?? .last30
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

    private var forgettingCurveSummary: String {
        guard let start = curvePoints.first?.1, let end = curvePoints.last?.1 else {
            return "No projected retention values."
        }
        return "Projected retention drops from \(Int(start * 100)) percent to \(Int(end * 100)) percent."
    }

    private var heatmapSummary: String {
        let totalReviews = heatmapPoints.reduce(0) { $0 + $1.count }
        return "\(totalReviews) review actions recorded in this period."
    }

    private var premiumUpsellBanner: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "5D6B5E"))
                        Text("Free plan includes Last 30 Days. Upgrade for 90-day and yearly trends.")
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary)
                        Spacer(minLength: 0)
                    }
                    Button("Upgrade") {
                        showingPremiumOffer = true
                    }
                    .font(.headline)
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "5D6B5E"))
                    Text("Free plan includes Last 30 Days. Upgrade for 90-day and yearly trends.")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveTextSecondary)
                    Spacer(minLength: 0)
                    Button("Upgrade") {
                        showingPremiumOffer = true
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var statGridColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        if dynamicTypeSize >= .xxLarge {
            return [GridItem(.flexible()), GridItem(.flexible())]
        }
        return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                }

                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected && !isLocked ? Color.sonPrimary : Color.adaptiveSurface)
            .foregroundStyle(isSelected && !isLocked ? .white : (isLocked ? Color.secondary : Color.sonPrimary))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    isLocked ? Color.gray.opacity(0.22) : Color.sonPrimary.opacity(0.2),
                    lineWidth: 1
                )
            )
        }
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(isLocked ? "Premium required for this period." : "Shows statistics for \(label).")
    }
}

private extension StatsPeriod {
    var accessibilityIdentifier: String {
        switch self {
        case .last30:
            return "stats.period.last30"
        case .last90:
            return "stats.period.last90"
        case .year:
            return "stats.period.year"
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
                .font(.metricLabel)
                .foregroundStyle(Color.adaptiveTextSecondary)

            Text(value)
                .font(.metricValue)
                .foregroundStyle(Color.adaptiveText)

            Text(subtitle)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(subtitleColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.adaptiveSurfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.adaptiveBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.cardShadow.opacity(0.4), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }
}

struct HeatmapGrid: View {
    let points: [HeatmapPoint]
    let differentiateWithoutColor: Bool
    private let rows = Array(repeating: GridItem(.fixed(12), spacing: 4), count: 7)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: rows, spacing: 4) {
                ForEach(points) { point in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: point.count))
                        .overlay {
                            if differentiateWithoutColor, point.count > 0 {
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.sonMidnight.opacity(0.65), lineWidth: 0.6)
                            }
                        }
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
