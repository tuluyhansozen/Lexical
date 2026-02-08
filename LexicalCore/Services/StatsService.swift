import Foundation
import SwiftData

public enum StatsPeriod: Int, CaseIterable {
    case last30
    case last90
    case year

    public var days: Int {
        switch self {
        case .last30: return 30
        case .last90: return 90
        case .year: return 365
        }
    }

    public var label: String {
        switch self {
        case .last30: return "Last 30 Days"
        case .last90: return "Last 90 Days"
        case .year: return "This Year"
        }
    }

    public var shortLabel: String {
        switch self {
        case .last30: return "30d"
        case .last90: return "90d"
        case .year: return "1y"
        }
    }
}

public struct HeatmapPoint: Identifiable {
    public let date: Date
    public let count: Int

    public var id: Date {
        Calendar.current.startOfDay(for: date)
    }

    public init(date: Date, count: Int) {
        self.date = date
        self.count = count
    }
}

public struct StatsSnapshot {
    public let acquiredCount: Int
    public let retentionRate: Double
    public let streak: Int
    public let curvePoints: [(Double, Double)]
    public let heatmap: [HeatmapPoint]

    public init(
        acquiredCount: Int,
        retentionRate: Double,
        streak: Int,
        curvePoints: [(Double, Double)],
        heatmap: [HeatmapPoint]
    ) {
        self.acquiredCount = acquiredCount
        self.retentionRate = retentionRate
        self.streak = streak
        self.curvePoints = curvePoints
        self.heatmap = heatmap
    }
}

/// Service to calculate user learning statistics.
@MainActor
public class StatsService {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func loadSnapshot(period: StatsPeriod) -> StatsSnapshot {
        StatsSnapshot(
            acquiredCount: fetchAcquired(period: period),
            retentionRate: calculateRetentionRate(period: period),
            streak: calculateStreak(),
            curvePoints: projectedForgettingCurve(),
            heatmap: activityHeatmap(period: period)
        )
    }

    /// Returns total number of words with state other than `.new`.
    public func fetchTotalAcquired() -> Int {
        let userId = activeUserID()

        do {
            let states = try modelContext.fetch(FetchDescriptor<UserWordState>())
            let userStates = states.filter { $0.userId == userId && $0.status != .ignored }
            return userStates.filter { $0.reviewCount > 0 || $0.status == .known }.count
        } catch {
            return 0
        }
    }

    /// Returns words acquired within the selected period.
    public func fetchAcquired(period: StatsPeriod) -> Int {
        let cutoff = periodCutoff(period)
        let userId = activeUserID()

        do {
            let events = try modelContext.fetch(FetchDescriptor<ReviewEvent>())
            let recent = events.filter { $0.userId == userId && $0.reviewDate >= cutoff && $0.grade >= 3 }
            return Set(recent.map(\.lemma)).count
        } catch {
            return 0
        }
    }

    public func calculateRetentionRate(period: StatsPeriod) -> Double {
        let cutoff = periodCutoff(period)
        let userId = activeUserID()

        do {
            let events = try modelContext.fetch(FetchDescriptor<ReviewEvent>())
            let userEvents = events.filter { $0.userId == userId && $0.reviewDate >= cutoff }
            guard !userEvents.isEmpty else { return 0.0 }
            let successful = userEvents.filter { $0.grade > 2 }.count
            return Double(successful) / Double(userEvents.count)
        } catch {
            return 0.0
        }
    }

    public func calculateStreak() -> Int {
        let userId = activeUserID()

        do {
            let events = try modelContext.fetch(FetchDescriptor<ReviewEvent>())
            let userEvents = events.filter { $0.userId == userId }
            return streak(from: userEvents.map(\.reviewDate))
        } catch {
            return 0
        }
    }

    /// Returns projected forgetting-curve points as `(day, retention%)`.
    public func projectedForgettingCurve() -> [(Double, Double)] {
        let avgStability: Double
        let userId = activeUserID()

        do {
            let states = try modelContext.fetch(FetchDescriptor<UserWordState>())
            let reviewedStates = states.filter { $0.userId == userId && $0.reviewCount > 0 }
            if reviewedStates.isEmpty { return defaultCurve() }
            let total = reviewedStates.reduce(0.0) { $0 + $1.stability }
            avgStability = total / Double(reviewedStates.count)
        } catch {
            return defaultCurve()
        }

        var points: [(Double, Double)] = []
        for i in 0...9 {
            let t = Double(i)
            let sNorm = max(1.0, avgStability)
            let retention = 100.0 * exp(-0.5 * t / sNorm)
            points.append((t, retention))
        }
        return points
    }

    public func activityHeatmap(period: StatsPeriod) -> [HeatmapPoint] {
        let cutoff = periodCutoff(period)
        let calendar = Calendar.current
        let userId = activeUserID()
        let today = calendar.startOfDay(for: Date())
        let days = period.days

        var dailyCounts: [Date: Int] = [:]

        if let events = try? modelContext.fetch(FetchDescriptor<ReviewEvent>()) {
            let filteredEvents = events.filter { $0.userId == userId && $0.reviewDate >= cutoff }
            for event in filteredEvents {
                let day = calendar.startOfDay(for: event.reviewDate)
                dailyCounts[day, default: 0] += 1
            }
        }

        var points: [HeatmapPoint] = []
        points.reserveCapacity(days)

        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            points.append(HeatmapPoint(date: day, count: dailyCounts[day, default: 0]))
        }
        return points
    }

    private func activeUserID() -> String {
        UserProfile.resolveActiveProfile(modelContext: modelContext).userId
    }

    private func periodCutoff(_ period: StatsPeriod) -> Date {
        Calendar.current.date(byAdding: .day, value: -period.days, to: Date()) ?? Date()
    }

    private func streak(from reviewDates: [Date]) -> Int {
        guard !reviewDates.isEmpty else { return 0 }
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        let reviewedToday = reviewDates.contains { calendar.isDate($0, inSameDayAs: Date()) }
        if !reviewedToday {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                return 0
            }
            checkDate = yesterday
        }

        let uniqueDays = Set(reviewDates.map { calendar.startOfDay(for: $0) })
        while uniqueDays.contains(checkDate) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previous
        }
        return streak
    }

    private func defaultCurve() -> [(Double, Double)] {
        (0...9).map { (Double($0), 100.0 * exp(-0.3 * Double($0))) }
    }
}
