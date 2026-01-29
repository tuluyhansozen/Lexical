import SwiftUI

// These views are designed to be used within a WidgetExtension
// but are placed here for the project structure.

struct WordOfDayWidgetView: View {
    // Small Widget Layout
    var body: some View {
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

struct MicroDoseWidgetView: View {
    // Medium Widget Layout
    var body: some View {
        HStack(spacing: 0) {
            // Left: Progress
            VStack(alignment: .leading) {
                Text("Daily Dose")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("3/5")
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
                
                Text("Ineffable")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptiveText)
                
                Text("Too great to be expressed in words.")
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

struct WidgetPreviews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            WordOfDayWidgetView()
                .frame(width: 155, height: 155)
                .cornerRadius(22)
            
            MicroDoseWidgetView()
                .frame(width: 329, height: 155)
                .cornerRadius(22)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}
