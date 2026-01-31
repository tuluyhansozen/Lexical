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
                let descriptor = FetchDescriptor<VocabularyItem>(sortBy: [SortDescriptor(\.nextReviewDate)])
                let items = try modelContext.fetch(descriptor)
                
                if let first = items.first(where: { ($0.nextReviewDate ?? Date()) <= Date() }) {
                    nextWord = first.lemma
                    definition = "Tap to review this card."
                }
                
                learned = items.filter { $0.reviewCount > 0 }.count
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
