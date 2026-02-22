import Foundation
import LexicalCore
import SwiftData

@MainActor
func run() async {
    print("Lexical 90-Day Simulation Seeder")
    
    let args = ProcessInfo.processInfo.arguments
    guard args.count > 1 else {
        print("Usage: Seeder <sqlite-file-path>")
        return
    }
    
    let storeURL = URL(fileURLWithPath: args[1])
    print("Targeting store at: \(storeURL.path)")
    
    let schema = Schema(LexicalSchemaV6.models)
    let modelConfiguration = ModelConfiguration(url: storeURL, allowsSave: true)
    
    do {
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let context = ModelContext(container)
        
        let userId = UserProfile.fallbackLocalUserID
        let profile = UserProfile(userId: userId)
        profile.applySubscriptionTier(.premium, source: .localCache)
        context.insert(profile)
        
        let calendar = Calendar.current
        let now = Date()
        
        print("Simulating 90 days of history...")
        
        for dayOffset in (0...90).reversed() {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            let dayStart = calendar.startOfDay(for: date)
            
            // 1. Simulate Article Reading
            let ledgerDescriptor = FetchDescriptor<UsageLedger>(
                predicate: #Predicate { $0.userId == userId }
            )
            let ledger = (try? context.fetch(ledgerDescriptor).first) ?? {
                let newLedger = UsageLedger(userId: userId, articleWindowStart: dayStart)
                context.insert(newLedger)
                return newLedger
            }()
            
            ledger.articlesGeneratedInWindow += 1
            ledger.touch(now: date)
            
            // 2. Simulate Reviews (5-15 words per day)
            let dailyReviewCount = Int.random(in: 5...15)
            for i in 0..<dailyReviewCount {
                let lemma = "sim_word_\(dayOffset)_\(i)"
                
                // Add some recurring words to simulate retention
                let isRecurring = i < 3 && dayOffset % 3 != 0
                let actualLemma = isRecurring ? "recurring_word_\(i)" : lemma
                
                let grade = Int.random(in: 1...4) // Again, Hard, Good, Easy
                let reviewDate = calendar.date(byAdding: .minute, value: Int.random(in: 0...1440), to: dayStart)!
                
                let event = ReviewEvent(
                    userId: userId,
                    lemma: actualLemma,
                    grade: grade,
                    reviewDate: reviewDate,
                    durationMs: Int.random(in: 2000...10000),
                    scheduledDays: Double.random(in: 1...30),
                    reviewState: ReviewEvent.reviewState(for: grade)
                )
                context.insert(event)
                
                // Update UserWordState
                let key = UserWordState.makeKey(userId: userId, lemma: actualLemma)
                let stateDescriptor = FetchDescriptor<UserWordState>(
                    predicate: #Predicate { $0.userLemmaKey == key }
                )
                let state = (try? context.fetch(stateDescriptor).first) ?? {
                    let newState = UserWordState(userId: userId, lemma: actualLemma)
                    context.insert(newState)
                    return newState
                }()
                
                state.reviewCount += 1
                state.lastReviewDate = reviewDate
                state.status = (grade >= 3) ? .known : .learning
                state.stability = Double.random(in: 1...100)
            }
        }
        
        try context.save()
        print("✅ Simulation data saved successfully!")
        
    } catch {
        print("❌ Error: \(error)")
    }
}

await run()
