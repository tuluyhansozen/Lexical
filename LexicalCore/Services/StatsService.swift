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
            let events = try fetchUserEvents(userId: userId)
                .sorted { $0.reviewDate < $1.reviewDate }

            var firstSuccessfulAcquisitionByLemma: [String: Date] = [:]
            firstSuccessfulAcquisitionByLemma.reserveCapacity(events.count / 4)

            for event in events where isDurableAcquisitionSignal(event) {
                if firstSuccessfulAcquisitionByLemma[event.lemma] == nil {
                    firstSuccessfulAcquisitionByLemma[event.lemma] = event.reviewDate
                }
            }

            return firstSuccessfulAcquisitionByLemma.values.filter { $0 >= cutoff }.count
        } catch {
            return 0
        }
    }

    public func calculateRetentionRate(period: StatsPeriod) -> Double {
        let cutoff = periodCutoff(period)
        let userId = activeUserID()

        do {
            let interactiveEvents = try fetchUserEvents(userId: userId, cutoff: cutoff)
                .filter(isInteractivePerformanceSignal)
                .sorted { $0.reviewDate < $1.reviewDate }
            guard !interactiveEvents.isEmpty else { return 0.0 }

            // Approximate "true retention" with first attempt per lemma/day.
            let calendar = Calendar.current
            var firstAttemptByLemmaDay: [String: ReviewEvent] = [:]
            firstAttemptByLemmaDay.reserveCapacity(interactiveEvents.count)

            for event in interactiveEvents {
                let day = calendar.startOfDay(for: event.reviewDate).timeIntervalSince1970
                let key = "\(event.lemma)|\(Int(day))"
                if firstAttemptByLemmaDay[key] == nil {
                    firstAttemptByLemmaDay[key] = event
                }
            }

            let attempts = Array(firstAttemptByLemmaDay.values)
            guard !attempts.isEmpty else { return 0.0 }
            let successful = attempts.filter { $0.grade > 2 }.count
            return Double(successful) / Double(attempts.count)
        } catch {
            return 0.0
        }
    }

    public func calculateStreak() -> Int {
        let userId = activeUserID()

        do {
            let events = try fetchUserEvents(userId: userId)
            let userEvents = events.filter(isInteractivePerformanceSignal)
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
            let descriptor = FetchDescriptor<UserWordState>(
                predicate: #Predicate { state in
                    state.userId == userId
                }
            )
            let states = try modelContext.fetch(descriptor)
            let reviewedStates = states.filter { $0.reviewCount > 0 && $0.status != .ignored }
            if reviewedStates.isEmpty { return defaultCurve() }
            avgStability = reviewedStates.reduce(0.0) { $0 + max($1.stability, 0.1) } / Double(reviewedStates.count)
        } catch {
            return defaultCurve()
        }

        var points: [(Double, Double)] = []
        for i in 0...9 {
            let t = Double(i)
            let retention = 100.0 * fsrsForgettingCurve(daysElapsed: t, stability: avgStability)
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

        if let events = try? fetchUserEvents(userId: userId, cutoff: cutoff) {
            let filteredEvents = events.filter(isInteractivePerformanceSignal)
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

    private func fetchUserEvents(userId: String, cutoff: Date? = nil) throws -> [ReviewEvent] {
        if let cutoff {
            let descriptor = FetchDescriptor<ReviewEvent>(
                predicate: #Predicate { event in
                    event.userId == userId && event.reviewDate >= cutoff
                }
            )
            return try modelContext.fetch(descriptor)
        }

        let descriptor = FetchDescriptor<ReviewEvent>(
            predicate: #Predicate { event in
                event.userId == userId
            }
        )
        return try modelContext.fetch(descriptor)
    }

    private func isInteractivePerformanceSignal(_ event: ReviewEvent) -> Bool {
        ReviewEvent.isInteractiveReviewState(event.reviewState) && !ReviewEvent.isImplicitExposureState(event.reviewState)
    }

    private func isDurableAcquisitionSignal(_ event: ReviewEvent) -> Bool {
        ReviewEvent.isExplicitReviewState(event.reviewState) && event.grade >= 3
    }

    private func fsrsForgettingCurve(daysElapsed: Double, stability: Double) -> Double {
        pow(1 + 19 * daysElapsed / max(stability, 0.1), -1)
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
        (0...9).map { day in
            let t = Double(day)
            return (t, 100.0 * fsrsForgettingCurve(daysElapsed: t, stability: 5.0))
        }
    }
}
