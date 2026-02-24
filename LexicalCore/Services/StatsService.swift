import Foundation
import SwiftData

public enum StatsPeriod: Int, CaseIterable {
    case week
    case month
    case year

    public var days: Int {
        switch self {
        case .week: return 7
        case .month: return 35
        case .year: return 365
        }
    }

    public var label: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }

    public var shortLabel: String {
        switch self {
        case .week: return "7d"
        case .month: return "30d"
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
    public let todayAcquired: Int
    public let periodAcquired: Int
    public let retentionRate: Double
    public let streak: Int
    public let curvePoints: [(Double, Double)]
    public let heatmap: [HeatmapPoint]

    public var retentionLabel: String {
        switch retentionRate {
        case 0.8...: return "Stable"
        case 0.5..<0.8: return "Rising"
        case 0.0..<0.1: return "New"
        default: return "Declining"
        }
    }

    public init(
        acquiredCount: Int,
        todayAcquired: Int = 0,
        periodAcquired: Int = 0,
        retentionRate: Double,
        streak: Int,
        curvePoints: [(Double, Double)],
        heatmap: [HeatmapPoint]
    ) {
        self.acquiredCount = acquiredCount
        self.todayAcquired = todayAcquired
        self.periodAcquired = periodAcquired
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
            acquiredCount: fetchTotalAcquired(),
            todayAcquired: fetchTodayAcquired(),
            periodAcquired: fetchAcquired(period: period),
            retentionRate: calculateRetentionRate(period: period),
            streak: calculateStreak(),
            curvePoints: historicalRetentionCurve(period: period),
            heatmap: activityHeatmap(period: period)
        )
    }

    /// Returns words acquired today only.
    public func fetchTodayAcquired() -> Int {
        let cutoff = Calendar.current.startOfDay(for: Date())
        let userId = activeUserID()

        do {
            let events = try fetchUserEvents(userId: userId)
                .sorted { $0.reviewDate < $1.reviewDate }

            var firstSuccessfulAcquisitionByLemma: [String: Date] = [:]

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

    /// Returns historical retention curve points for the period as `(dayIndex, retention%)`.
    public func historicalRetentionCurve(period: StatsPeriod) -> [(Double, Double)] {
        let userId = activeUserID()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = period.days
        
        // To calculate trailing retention for up to `days` ago, we need events from `2 * days` ago.
        let fetchCutoff = calendar.date(byAdding: .day, value: -(days * 2), to: today) ?? today
        
        do {
            let interactiveEvents = try fetchUserEvents(userId: userId, cutoff: fetchCutoff)
                .filter(isInteractivePerformanceSignal)
                // Sorting not strictly required but good for correctness
                .sorted { $0.reviewDate < $1.reviewDate }
                
            var points: [(Double, Double)] = []
            let periodSteps = period == .year ? 12 : days
            let stepSize = period == .year ? 30 : 1
            
            for stepIndex in (0..<periodSteps).reversed() { // from oldest to newest
                let offsetDays = stepIndex * stepSize
                guard let evaluationDate = calendar.date(byAdding: .day, value: -offsetDays, to: today) else { continue }
                
                guard let windowStart = calendar.date(byAdding: .day, value: -days, to: evaluationDate) else { continue }
                let windowEnd = calendar.date(byAdding: .day, value: 1, to: evaluationDate)! // Include evaluation day
                let windowCutoff = windowStart
                
                let windowEvents = interactiveEvents.filter { $0.reviewDate >= windowCutoff && $0.reviewDate < windowEnd }
                
                var firstAttemptByLemmaDay: [String: ReviewEvent] = [:]
                for event in windowEvents {
                    let day = calendar.startOfDay(for: event.reviewDate).timeIntervalSince1970
                    let key = "\(event.lemma)|\(Int(day))"
                    if firstAttemptByLemmaDay[key] == nil {
                        firstAttemptByLemmaDay[key] = event
                    }
                }
                
                let attempts = Array(firstAttemptByLemmaDay.values)
                let retention: Double
                if attempts.isEmpty {
                    retention = points.last?.1 ?? 0.0 // Carry over previous retention or 0
                } else {
                    let successful = attempts.filter { $0.grade > 2 }.count
                    retention = (Double(successful) / Double(attempts.count)) * 100.0
                }
                
                let xPosition = Double(periodSteps - 1 - stepIndex)
                points.append((xPosition, retention))
            }
            
            return points

        } catch {
            return defaultHistoricalCurve(steps: period == .year ? 12 : days)
        }
    }

    public func activityHeatmap(period: StatsPeriod) -> [HeatmapPoint] {
        let cutoff = periodCutoff(period)
        let calendar = Calendar.current
        let userId = activeUserID()
        let today = calendar.startOfDay(for: Date())
        let days = period.days

        var points: [HeatmapPoint] = []
        
        if period == .year {
            points.reserveCapacity(12)
            let currentMonth = calendar.component(.month, from: today)
            let currentYear = calendar.component(.year, from: today)
            
            // Start from 11 months ago to include current month
            guard let startMonthDate = calendar.date(byAdding: .month, value: -11, to: calendar.date(from: DateComponents(year: currentYear, month: currentMonth))!) else {
                return []
            }
            
            let fetchCutoff = min(cutoff, startMonthDate)
            var yearDailyCounts: [Date: Int] = [:]
            
            if let events = try? fetchUserEvents(userId: userId, cutoff: fetchCutoff) {
                let filteredEvents = events.filter(isInteractivePerformanceSignal)
                for event in filteredEvents {
                    let day = calendar.startOfDay(for: event.reviewDate)
                    yearDailyCounts[day, default: 0] += 1
                }
            }
            
            var iterMonthStart = startMonthDate
            for _ in 0..<12 {
                let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: iterMonthStart)!
                var monthlyCount = 0
                
                var iterDay = iterMonthStart
                while iterDay < nextMonthStart {
                    monthlyCount += yearDailyCounts[iterDay, default: 0]
                    iterDay = calendar.date(byAdding: .day, value: 1, to: iterDay)!
                }
                
                points.append(HeatmapPoint(date: iterMonthStart, count: monthlyCount))
                iterMonthStart = nextMonthStart
            }
        } else {
            var dailyCounts: [Date: Int] = [:]
            if let events = try? fetchUserEvents(userId: userId, cutoff: cutoff) {
                let filteredEvents = events.filter(isInteractivePerformanceSignal)
                for event in filteredEvents {
                    let day = calendar.startOfDay(for: event.reviewDate)
                    dailyCounts[day, default: 0] += 1
                }
            }

            // For week (7) or month (35)
            points.reserveCapacity(days)
            for offset in stride(from: days - 1, through: 0, by: -1) {
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
                points.append(HeatmapPoint(date: day, count: dailyCounts[day, default: 0]))
            }
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

    private func defaultHistoricalCurve(steps: Int) -> [(Double, Double)] {
        (0..<steps).map { step in
            let t = Double(step)
            return (t, 50.0 + (Double(step) * 2.0)) // Shows a slight upward trend by default
        }
    }
}
