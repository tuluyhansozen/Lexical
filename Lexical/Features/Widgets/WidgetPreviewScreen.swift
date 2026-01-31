import SwiftUI
import WidgetKit
import LexicalCore

struct WidgetPreviewScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Widget Preview Studio")
                    .font(.display(size: 28, weight: .bold))
                    .foregroundStyle(Color.adaptiveText)
                    .padding(.top, 60)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Micro-Dose (Medium)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    // Simulating the Widget Environment
                    MicroDoseWidgetView(entry: MicroDoseEntry(
                        date: Date(),
                        word: "Serendipity",
                        definition: "Finding something good without looking for it.",
                        learnedCount: 5,
                        totalGoal: 10
                    ))
                    // Approximation of System Medium size
                    .frame(width: 338, height: 158)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(radius: 10)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Word of the Day (Small)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    WordOfDayWidgetView()
                        .frame(width: 158, height: 158)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .shadow(radius: 10)
                }
                
                Text("(Note: These are native SwiftUI views running in-app)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.adaptiveBackground)
        }
    }
}
