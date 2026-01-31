import SwiftUI
import WidgetKit

// Moved MicroDoseEntry here to share between Widget and App Preview
public struct MicroDoseEntry: Equatable, TimelineEntry {
    public let date: Date
    public let word: String
    public let definition: String
    public let learnedCount: Int
    public let totalGoal: Int
    
    public init(date: Date, word: String, definition: String, learnedCount: Int, totalGoal: Int) {
        self.date = date
        self.word = word
        self.definition = definition
        self.learnedCount = learnedCount
        self.totalGoal = totalGoal
    }
}

public struct WordOfDayWidgetView: View {
    public init() {}
    
    // Small Widget Layout
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(Color.orange)
                    .font(.caption2)
                Text("Word of the Day")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
            
            Text("Serendipity")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(Color.sonPrimary)
                .minimumScaleFactor(0.8)
                .padding(.bottom, 4)
            
            Text("noun")
                .font(.caption2)
                .italic()
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            
            Text("Finding something good without looking for it.")
                .font(.caption)
                .foregroundStyle(Color.adaptiveText)
                .lineLimit(3)
        }
        .padding()
        .background(Color.adaptiveSurface)
    }
}

public struct MicroDoseWidgetView: View {
    public var entry: MicroDoseEntry
    
    public init(entry: MicroDoseEntry) {
        self.entry = entry
    }

    // Medium Widget Layout
    public var body: some View {
        HStack(spacing: 0) {
            // Left: Progress
            VStack(alignment: .leading) {
                Text("Daily Dose")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(entry.learnedCount)/\(entry.totalGoal)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.sonPrimary)
                
                Text("Words Learned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.sonPrimary.opacity(0.1))
            
            // Right: Next Word
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("NEXT UP")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(Color.sonPrimary)
                }
                
                Spacer()
                
                Text(entry.word)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText)
                
                Text(entry.definition)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.adaptiveSurface)
        }
    }
}
