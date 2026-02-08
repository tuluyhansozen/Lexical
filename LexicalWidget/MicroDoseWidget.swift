import WidgetKit
import SwiftUI
import SwiftData
import LexicalCore

struct MicroDoseProvider: TimelineProvider {
    func placeholder(in context: Context) -> MicroDoseEntry {
        MicroDoseEntry(date: Date(), word: "Ineffable", definition: "Too great to be expressed in words.", learnedCount: 3, totalGoal: 5)
    }

    func getSnapshot(in context: Context, completion: @escaping (MicroDoseEntry) -> ()) {
        let entry = MicroDoseEntry(date: Date(), word: "Ineffable", definition: "Too great to be expressed in words.", learnedCount: 3, totalGoal: 5)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MicroDoseEntry>) -> ()) {
        Task {
            // Fetch data from Shared Persistence
            let modelContext = ModelContext(Persistence.sharedModelContainer)
            var nextWord = "No Reviews"
            var definition = "You are all caught up!"
            var learned = 0
            
            do {
                let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
                let activeUserId = defaults.string(forKey: UserProfile.activeUserDefaultsKey) ?? UserProfile.fallbackLocalUserID
                let now = Date()
                let states = try modelContext.fetch(FetchDescriptor<UserWordState>())
                    .filter { $0.userId == activeUserId && $0.status != .ignored }

                if let firstDue = states
                    .filter({ ($0.nextReviewDate ?? now) <= now })
                    .sorted(by: { ($0.nextReviewDate ?? now) < ($1.nextReviewDate ?? now) })
                    .first {
                    let dueLemma = firstDue.lemma
                    nextWord = dueLemma

                    let lexemeDescriptor = FetchDescriptor<LexemeDefinition>(
                        predicate: #Predicate { $0.lemma == dueLemma }
                    )
                    let lexeme = try modelContext.fetch(lexemeDescriptor).first
                    definition = lexeme?.basicMeaning ?? "Tap to review this card."
                }

                learned = states.filter { $0.reviewCount > 0 || $0.status == .known }.count
            } catch {
                print("Widget fetch failed: \(error)")
            }
            
            let entry = MicroDoseEntry(
                date: Date(),
                word: nextWord,
                definition: definition,
                learnedCount: learned,
                totalGoal: 10
            )
            
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))) // Refresh every hour
            completion(timeline)
        }
    }
}

// MicroDoseEntry is defined in LexicalCore

struct MicroDoseWidgetEntryView : View {
    var entry: MicroDoseProvider.Entry

    var body: some View {
        // Reuse the public view from LexicalCore
        MicroDoseWidgetView(entry: entry)
        .containerBackground(for: .widget) {
            Color.adaptiveSurface
        }
    }
}

struct MicroDoseWidget: Widget {
    let kind: String = "MicroDoseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MicroDoseProvider()) { entry in
            MicroDoseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Micro-Dose")
        .description("Track your daily progress and see up-next reviews.")
        .supportedFamilies([.systemMedium])
    }
}
