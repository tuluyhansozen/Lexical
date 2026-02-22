import SwiftUI
import Charts
import SwiftData
import LexicalCore

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedPeriod: StatsPeriod = .week
    @State private var availablePeriods: [StatsPeriod] = [.week]
    @State private var isPremiumTier = false
    @State private var showingPremiumOffer = false
    @State private var acquiredCount: Int = 0
    @State private var todayAcquired: Int = 0
    @State private var periodAcquired: Int = 0
    @State private var retentionRate: Double = 0.0
    @State private var retentionLabel: String = ""
    @State private var currentStreak: Int = 0
    @State private var curvePoints: [(Double, Double)] = []
    @State private var heatmapPoints: [HeatmapPoint] = []

    private let featureGateService = FeatureGateService()

    var body: some View {
        ZStack {
            Color.adaptiveBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Title
                VStack(spacing: 0) {
                    Text("Learning Statistics")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.adaptiveText)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("stats.title")
                }
                .padding(.top, 16)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Period Segmented Picker
                        periodSegmentedPicker
                            .padding(.horizontal, 24)

                        // MARK: - Stat Cards
                        HStack(spacing: 12) {
                            AcquiredStatCard(
                                value: formattedNumber(acquiredCount),
                                deltaCountStr: formattedNumber(selectedPeriod == .week ? todayAcquired : periodAcquired),
                                deltaLabel: acquiredDeltaLabel
                            )
                            RetentionStatCard(
                                value: "\(Int((retentionRate * 100).rounded()))%",
                                label: retentionLabel
                            )
                            StreakStatCard(
                                value: "\(currentStreak)"
                            )
                        }
                        .padding(.horizontal, 24)

                        // MARK: - Retention Curve
                        retentionCurveCard
                            .padding(.horizontal, 24)

                        // MARK: - Activity Heatmap
                        activityHeatmapCard
                            .padding(.horizontal, 24)

                        Color.clear.frame(height: 100)
                    }
                    .padding(.top, 4)
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

    // MARK: - Period Segmented Picker

    private var periodSegmentedPicker: some View {
        HStack(spacing: 0) {
            let periods = StatsPeriod.allCases
            ForEach(Array(periods.enumerated()), id: \.element.rawValue) { index, period in
                let isUnlocked = availablePeriods.contains(period)
                let isSelected = selectedPeriod == period

                Button {
                    if isUnlocked {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPeriod = period
                        }
                    } else {
                        showingPremiumOffer = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        if !isUnlocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .bold))
                        }
                        Text(period.label)
                            .font(.system(size: 15, weight: isSelected ? .medium : .light, design: .default))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        isSelected
                            ? Color.gray.opacity(0.15)
                            : Color.clear
                    )
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.7))
                }
                .accessibilityLabel(period.label)
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
                .accessibilityHint(isUnlocked ? "Shows statistics for \(period.label)." : "Premium required.")
                .accessibilityIdentifier(period.accessibilityIdentifier)

                if index < periods.count - 1 {
                    Rectangle()
                        .fill(Color.sonPrimary.opacity(0.2))
                        .frame(width: 0.7, height: 36)
                }
            }
        }
        .frame(height: 36)
        .background(Color.adaptiveSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
    }

    // MARK: - Retention Curve Card

    private var retentionCurveCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text("Retention Curve")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.adaptiveText)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(retentionLabel)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color(red: 180 / 255, green: 83 / 255, blue: 9 / 255))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 255 / 255, green: 251 / 255, blue: 235 / 255))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            Chart {
                ForEach(curvePoints, id: \.0) { point in
                    LineMark(
                        x: .value("Day", point.0),
                        y: .value("Retention", point.1)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.sonPrimary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Day", point.0),
                        y: .value("Retention", point.1)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.sonPrimary.opacity(0.2), Color.sonPrimary.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    PointMark(
                        x: .value("Day", point.0),
                        y: .value("Retention", point.1)
                    )
                    .foregroundStyle(Color.sonPrimary)
                    .symbolSize(30)
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: curveXAxisValues) { value in
                    AxisValueLabel {
                        if let day = value.as(Double.self) {
                            Text(curveXLabel(for: day))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.adaptiveTextSecondary)
                        }
                    }
                }
            }
            .frame(height: 160)
            .accessibilityElement()
            .accessibilityLabel("Historical retention over period")
            .accessibilityValue(retentionCurveSummary)
        }
        .padding(20)
        .background(Color.adaptiveSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.adaptiveBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
    }

    // MARK: - Activity Heatmap Card

    private var activityHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Activity Heatmap")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.adaptiveText)
                Text("Daily review activity")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.adaptiveTextSecondary)
            }

            Group {
                switch selectedPeriod {
                case .week:
                    ActivityGridWeek(points: heatmapPoints, differentiateWithoutColor: differentiateWithoutColor)
                case .month:
                    HeatmapGrid(points: heatmapPoints, differentiateWithoutColor: differentiateWithoutColor)
                case .year:
                    ActivityGridYear(points: heatmapPoints, differentiateWithoutColor: differentiateWithoutColor)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Activity heatmap")
            .accessibilityValue(heatmapSummary)

            // Legend
            HStack(spacing: 6) {
                Text("Less")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.adaptiveTextSecondary)
                
                if #available(iOS 26, macOS 16.0, *) {
                    GlassEffectContainer(spacing: 6) {
                        legendSquares
                    }
                } else {
                    HStack(spacing: 6) {
                        legendSquares
                    }
                }

                Text("More")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.adaptiveTextSecondary)
            }
        }
        .padding(20)
        .background(Color.adaptiveSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.adaptiveBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
    }

    // MARK: - Helpers

    private func refreshPeriodAccessState() {
        let available = featureGateService.availableStatsPeriods(modelContext: modelContext)
        availablePeriods = available
        isPremiumTier = featureGateService.activeTier(modelContext: modelContext) == .premium

        if !available.contains(selectedPeriod) {
            selectedPeriod = available.first ?? .week
        }
    }

    private func loadStats() async {
        let service = StatsService(modelContext: modelContext)
        let snapshot = service.loadSnapshot(period: selectedPeriod)
        acquiredCount = snapshot.acquiredCount
        todayAcquired = snapshot.todayAcquired
        periodAcquired = snapshot.periodAcquired
        retentionRate = snapshot.retentionRate
        retentionLabel = snapshot.retentionLabel
        currentStreak = snapshot.streak
        curvePoints = snapshot.curvePoints
        heatmapPoints = snapshot.heatmap
    }

    private var acquiredDeltaLabel: String {
        switch selectedPeriod {
        case .week: return "today"
        case .month: return "this mo."
        case .year: return "this yr"
        }
    }

    private var retentionCurveSummary: String {
        guard let start = curvePoints.first?.1, let end = curvePoints.last?.1 else {
            return "No historical retention values."
        }
        return "Retention progressed from \(Int(start)) percent to \(Int(end)) percent."
    }

    private var heatmapSummary: String {
        let totalReviews = heatmapPoints.reduce(0) { $0 + $1.count }
        return "\(totalReviews) review actions recorded in this period."
    }

    private var curveXAxisValues: [Double] {
        guard !curvePoints.isEmpty else { return [0] }
        let maxDay = curvePoints.last!.0
        return [0, maxDay * 0.33, maxDay * 0.66, maxDay]
    }

    private func curveXLabel(for day: Double) -> String {
        guard let maxDay = curvePoints.last?.0, maxDay > 0 else { return "" }
        if day <= 0 { return "START" }
        if abs(day - maxDay) < 0.5 { return "NOW" }
        
        if selectedPeriod == .year {
            let percentage = 1.0 - (day / maxDay)
            let monthsAgo = Int((12.0 * percentage).rounded())
            if monthsAgo == 0 { return "NOW" }
            let cal = Calendar.current
            let pastDate = cal.date(byAdding: .month, value: -monthsAgo, to: Date()) ?? Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            return formatter.string(from: pastDate)
        } else if selectedPeriod == .month {
            let percentage = 1.0 - (day / maxDay)
            let weeksAgo = Int((4.0 * percentage).rounded())
            if weeksAgo == 0 { return "NOW" }
            return "W\(5 - weeksAgo)"
        } else {
            let percentage = 1.0 - (day / maxDay)
            let daysAgo = Int((Double(selectedPeriod.days) * percentage).rounded())
            return "\(daysAgo)d ago"
        }
    }

    private func formattedNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    @ViewBuilder
    private var legendSquares: some View {
        ForEach(0..<5) { level in
            let color = heatmapLegendColor(level: level)
            if #available(iOS 26, macOS 16.0, *) {
                Color.clear
                    .frame(width: 12, height: 12)
                    .glassEffect(.regular.tint(color), in: .rect(cornerRadius: 2))
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 12, height: 12)
            }
        }
    }

    private func heatmapLegendColor(level: Int) -> Color {
        switch level {
        case 0: return Color.gray.opacity(0.10)
        case 1: return Color.sonPrimary.opacity(0.25)
        case 2: return Color.sonPrimary.opacity(0.45)
        case 3: return Color.sonPrimary.opacity(0.70)
        default: return Color.sonPrimary
        }
    }
}

// MARK: - Stat Card Views

private struct AcquiredStatCard: View {
    let value: String
    let deltaCountStr: String
    let deltaLabel: String

    var body: some View {
        VStack(spacing: 8) {
            Text("ACQUIRED")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.adaptiveTextSecondary)
                .tracking(0.5)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.adaptiveText)

            Text("+\(deltaCountStr) \(deltaLabel)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.sonPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
        .background(Color.adaptiveSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.adaptiveBorder, lineWidth: 1)
        )
        .shadow(color: Color.cardShadow.opacity(0.3), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Acquired \(value)")
    }
}

private struct RetentionStatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Text("RETENTION")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.adaptiveTextSecondary)
                .tracking(0.5)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.adaptiveText)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.adaptiveTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
        .background(Color.adaptiveSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.adaptiveBorder, lineWidth: 1)
        )
        .shadow(color: Color.cardShadow.opacity(0.3), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Retention \(value)")
    }
}

private struct StreakStatCard: View {
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Text("STREAK")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.adaptiveTextSecondary)
                .tracking(0.5)

            HStack(spacing: 4) {
                Text("🔥")
                    .font(.system(size: 20))
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.adaptiveText)
            }

            Text("Keep it up!")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.adaptiveTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
        .background(Color.adaptiveSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.adaptiveBorder, lineWidth: 1)
        )
        .shadow(color: Color.cardShadow.opacity(0.3), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Streak \(value) days")
    }
}

// MARK: - Period Accessibility

private extension StatsPeriod {
    var accessibilityIdentifier: String {
        switch self {
        case .week:
            return "stats.period.week"
        case .month:
            return "stats.period.month"
        case .year:
            return "stats.period.year"
        }
    }
}

// MARK: - Heatmap Grid

struct HeatmapGrid: View {
    let points: [HeatmapPoint]
    let differentiateWithoutColor: Bool

    var body: some View {
        ScrollView(.horizontal) {
            if #available(iOS 26, macOS 16.0, *) {
                GlassEffectContainer(spacing: 4) {
                    heatmapHStack
                }
            } else {
                heatmapHStack
            }
        }
        .scrollIndicators(.hidden)
    }

    private let rows = Array(repeating: GridItem(.fixed(14), spacing: 4), count: 7)

    private var heatmapHStack: some View {
        LazyHGrid(rows: rows, spacing: 4) {
            ForEach(points) { point in
                heatmapCell(for: point)
            }
        }
    }

    @ViewBuilder
    private func heatmapCell(for point: HeatmapPoint) -> some View {
        let colorLevel = color(for: point.count)
        
        if #available(iOS 26, macOS 16.0, *) {
            Color.clear
                .frame(width: 14, height: 14)
                .glassEffect(.regular.tint(colorLevel), in: .rect(cornerRadius: 3))
                .overlay {
                    if differentiateWithoutColor, point.count > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.sonMidnight.opacity(0.65), lineWidth: 0.6)
                    }
                }
        } else {
            RoundedRectangle(cornerRadius: 3)
                .fill(colorLevel)
                .frame(width: 14, height: 14)
                .overlay {
                    if differentiateWithoutColor, point.count > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.sonMidnight.opacity(0.65), lineWidth: 0.6)
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

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView()
    }
}
