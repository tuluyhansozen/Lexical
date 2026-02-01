import Foundation
import UserNotifications
import CoreMotion

/// Time slots for notification scheduling
public enum TimeSlot: String, CaseIterable, Codable {
    case morning = "morning"     // 8 AM
    case afternoon = "afternoon" // 2 PM
    case evening = "evening"     // 6 PM
    case night = "night"         // 9 PM
    
    /// Returns the target hour for this time slot
    var hour: Int {
        switch self {
        case .morning: return 8
        case .afternoon: return 14
        case .evening: return 18
        case .night: return 21
        }
    }
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .morning: return "Morning (8 AM)"
        case .afternoon: return "Afternoon (2 PM)"
        case .evening: return "Evening (6 PM)"
        case .night: return "Night (9 PM)"
        }
    }
}

/// Notification templates strategies (Bandit Arms)
public enum NotificationTemplate: String, CaseIterable, Codable {
    case curious = "curious"   // "Ready to learn?"
    case streak = "streak"     // "Don't lose your streak!"
    case value = "value"       // "Expand your mind."
    case quick = "quick"       // "Quick 2-min review?"
    
    var title: String {
        switch self {
        case .curious: return "Time for a challenge?"
        case .streak: return "Streak at risk! 🔥"
        case .value: return "Word of the day waiting..."
        case .quick: return "Got 2 minutes?"
        }
    }
    
    var body: String {
        switch self {
        case .curious: return "See if you remember these words."
        case .streak: return "Keep your momentum going!"
        case .value: return "Invest in your vocabulary today."
        case .quick: return "Perfect time for a quick session."
        }
    }
}

/// Epsilon-Greedy Multi-Armed Bandit for notification timing and content optimization
/// 
/// This scheduler learns the optimal time to send vocabulary review reminders
/// by tracking user engagement across different time slots.
public final class BanditScheduler: NSObject, ObservableObject {
    
    // MARK: - Configuration
    
    /// Exploration rate (probability of choosing random arm)
    private let epsilon: Double = 0.2 // Increased exploration
    
    /// UserDefaults keys for persistence
    private let successCountsKey = "bandit_success_counts_v2"
    private let totalCountsKey = "bandit_total_counts_v2"
    private let lastEngagedKey = "bandit_last_engaged_date"
    private let ignoreStreakKey = "bandit_ignore_streak"
    
    // MARK: - State
    
    /// Success counts per (TimeSlot + Template) key
    @Published private(set) var successCounts: [String: Int]
    
    /// Total counts per (TimeSlot + Template) key
    @Published private(set) var totalCounts: [String: Int]
    
    public override init() {
        // Load persisted state or initialize with zeros
         if let successData = UserDefaults.standard.data(forKey: successCountsKey),
           let totalData = UserDefaults.standard.data(forKey: totalCountsKey),
           let success = try? JSONDecoder().decode([String: Int].self, from: successData),
           let total = try? JSONDecoder().decode([String: Int].self, from: totalData) {
            self.successCounts = success
            self.totalCounts = total
        } else {
            self.successCounts = [:]
            self.totalCounts = [:]
        }
        
        super.init()
        setupNotifications()
    }
    
    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("🔔 Notifications authorized")
            } else {
                print("🔕 Notifications denied")
            }
        }
    }
    
    // MARK: - Selection Logic
    
    /// Schedule the next optimal notification
    public func scheduleNextNotification() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            // Don't over-schedule
            if requests.count > 0 { return }
            
            self.performSchedule()
        }
    }
    
    // MARK: - Debug
    
    public func scheduleTestNotification() {
        let (slot, template) = selectArm()
        
        let content = UNMutableNotificationContent()
        content.title = "[TEST] " + template.title
        content.body = template.body
        content.sound = .default
        content.userInfo = [
            "bandit_slot": slot.rawValue,
            "bandit_template": template.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Trigger in 2 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule test notification: \(error)")
            } else {
                print("🧪 Scheduled test notification (in 2s)")
            }
        }
    }
    
    // MARK: - Core Motion
    
    private let motionActivityManager = CMMotionActivityManager()
    
    /// Check if user is interruptible (not driving/running)
    private func checkInterruptibility(completion: @escaping (Bool) -> Void) {
        guard CMMotionActivityManager.isActivityAvailable() else {
            completion(true) // Assume yes if no sensor
            return
        }
        
        // Check current activity
        motionActivityManager.queryActivityStarting(from: Date().addingTimeInterval(-60), to: Date(), to: .main) { activities, error in
            guard let activity = activities?.last else {
                completion(true)
                return
            }
            
            // Don't interrupt if running or automotive
            if activity.running || activity.automotive {
                print("🚫 User is active/driving. Skipping notification.")
                completion(false)
            } else {
                completion(true)
            }
        }
    }

    private func performSchedule() {
        // 1. Check Cooldown (48 hours after "ignored streak" threshold)
        let ignoreStreak = UserDefaults.standard.integer(forKey: ignoreStreakKey)
        if ignoreStreak > 3 { // Threshold: 3 ignores
            let lastEngaged = UserDefaults.standard.object(forKey: lastEngagedKey) as? Date ?? Date.distantPast
            // If last engagement was < 48 hours ago? No, wait. 
            // If we are in "ignore streak", we want to cooldown for 48 hours from the LAST ATTEMPT?
            // Simplified: If streak > 3, we only allow scheduling if it's been 48h since the *last attempt* (which we don't track easily here without a "lastScheduled")
            // Let's rely on "lastEngaged". If not engaged in 48h AND streak is high, maybe back off?
            // Audit requirement: "cooldown logic after ignored notifications".
            // Let's stick to: If streak > 5, wait 48h.
             
            // We need to store "lastScheduledDate"
            let lastScheduled = UserDefaults.standard.object(forKey: "bandit_last_scheduled") as? Date ?? Date.distantPast
            if Date().timeIntervalSince(lastScheduled) < 48 * 3600 {
                 print("💤 Bandit in 48h cooldown (streak \(ignoreStreak))")
                 return
            }
        }
        
        // Check interruptibility before proceeding
        checkInterruptibility { [weak self] isInterruptible in
            guard let self = self, isInterruptible else { return }
            
            // 2. Select Arm (Time + Content)
            let (slot, template) = self.selectArm()
            
            // 3. Create Content
            let content = UNMutableNotificationContent()
            content.title = template.title
            content.body = template.body
            content.sound = .default
            content.userInfo = [
                "bandit_slot": slot.rawValue,
                "bandit_template": template.rawValue,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            // 4. Create Trigger
            var dateComponents = DateComponents()
            dateComponents.hour = slot.hour
            // Random minute to avoid collisions
            dateComponents.minute = Int.random(in: 0...30)
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            // 5. Schedule
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Failed to schedule notification: \(error)")
                } else {
                    print("📅 Scheduled '\(template.rawValue)' for \(slot.displayName)")
                    UserDefaults.standard.set(Date(), forKey: "bandit_last_scheduled")
                }
            }
            
            // Record 'send' opportunity
            let key = self.makeKey(slot, template)
            DispatchQueue.main.async {
                self.totalCounts[key, default: 0] += 1
                self.persist()
            }
        }
    }
    
    /// Select the best arm using epsilon-greedy
    private func selectArm() -> (TimeSlot, NotificationTemplate) {
        // Flat list of all combinations
        let arms = product(TimeSlot.allCases, NotificationTemplate.allCases)
        
        // Epsilon-greedy
        if Double.random(in: 0...1) < epsilon {
            // Explore
            return arms.randomElement()!
        }
        
        // Exploit
        return bestArm(from: arms)
    }
    
    private func bestArm(from arms: [(TimeSlot, NotificationTemplate)]) -> (TimeSlot, NotificationTemplate) {
        var best = arms[0] // Default
        var bestRate = -1.0
        
        for arm in arms {
            let key = makeKey(arm.0, arm.1)
            let total = totalCounts[key] ?? 0
            
            // Optimistic Initialization: If untried, treat as high potential
            if total == 0 { return arm }
            
            let success = successCounts[key] ?? 0
            let rate = Double(success) / Double(total)
            
            if rate > bestRate {
                bestRate = rate
                best = arm
            }
        }
        
        return best
    }
    
    // MARK: - Reward Recording
    
    /// Call this when app is opened via notification
    public func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        
        guard let slotRaw = userInfo["bandit_slot"] as? String,
              let templateRaw = userInfo["bandit_template"] as? String,
              let slot = TimeSlot(rawValue: slotRaw),
              let template = NotificationTemplate(rawValue: templateRaw) else {
            return
        }
        
        print("🎰 Bandit Reward! User tapped '\(template.rawValue)' at \(slot.rawValue)")
        
        // Record Success
        let key = makeKey(slot, template)
        DispatchQueue.main.async {
            self.successCounts[key, default: 0] += 1
            
            // Reset ignore streak
            UserDefaults.standard.set(0, forKey: self.ignoreStreakKey)
            
            self.persist()
        }
    }
    
    // MARK: - Helpers
    
    private func makeKey(_ slot: TimeSlot, _ template: NotificationTemplate) -> String {
        return "\(slot.rawValue)_\(template.rawValue)"
    }
    
    // Cartesian product helper
    private func product<A, B>(_ a: [A], _ b: [B]) -> [(A, B)] {
        var result: [(A, B)] = []
        for elementA in a {
            for elementB in b {
                result.append((elementA, elementB))
            }
        }
        return result
    }
    
    private func persist() {
        if let successData = try? JSONEncoder().encode(successCounts),
           let totalData = try? JSONEncoder().encode(totalCounts) {
            UserDefaults.standard.set(successData, forKey: successCountsKey)
            UserDefaults.standard.set(totalData, forKey: totalCountsKey)
        }
    }

    /// Reset all statistics (for testing)
    public func reset() {
        successCounts = [:]
        totalCounts = [:]
        UserDefaults.standard.removeObject(forKey: successCountsKey)
        UserDefaults.standard.removeObject(forKey: totalCountsKey)
    }
    
    /// Print current arm statistics
    public func printStats() {
        print("🎰 Bandit Stats:")
        let arms = product(TimeSlot.allCases, NotificationTemplate.allCases)
        for arm in arms {
            let key = makeKey(arm.0, arm.1)
            let total = totalCounts[key] ?? 0
            if total > 0 {
                let success = successCounts[key] ?? 0
                let rate = Int((Double(success) / Double(total)) * 100)
                print("   \(arm.0.displayName) - \(arm.1.rawValue): \(success)/\(total) (\(rate)%)")
            }
        }
    }
}
