import SwiftUI
import LexicalCore

struct ActivityGridMonth: View {
    let points: [HeatmapPoint]
    let differentiateWithoutColor: Bool
    
    private let columns = Array(repeating: GridItem(.flexible(minimum: 36, maximum: 50), spacing: 8), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<max(points.count, 28), id: \.self) { index in
                if index < points.count {
                    let point = points[index]
                    let level = countToLevel(point.count)
                    
                    VStack(spacing: 2) {
                        Text(dayNumber(from: point.date))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(textColor(for: level, isTitle: true))
                        
                        Text("\(point.count)")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(textColor(for: level, isTitle: false))
                            .opacity(level >= 4 ? 1.0 : 0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 46, maxHeight: 54)
                    .aspectRatio(1, contentMode: .fit)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(color(for: level))
                    }
                    .overlay {
                        if differentiateWithoutColor, level > 0 {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.sonMidnight.opacity(0.65), lineWidth: 0.6)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(fullDateLabel(from: point.date))")
                    .accessibilityValue("\(point.count) reviews")
                } else {
                    Spacer()
                }
            }
        }
    }
    
    private func countToLevel(_ count: Int) -> Int {
        if count == 0 { return 0 }
        let maxCount = max(points.map(\.count).max() ?? 1, 1)
        let normalized = Double(count) / Double(maxCount)
        switch normalized {
        case ..<0.25: return 1
        case ..<0.5: return 2
        case ..<0.75: return 3
        default: return 4
        }
    }
    
    private func color(for level: Int) -> Color {
        switch level {
        case 0: return Color.gray.opacity(0.10)
        case 1: return Color.sonPrimary.opacity(0.25)
        case 2: return Color.sonPrimary.opacity(0.45)
        case 3: return Color.sonPrimary.opacity(0.70)
        case 4: return Color.sonPrimary
        default: return Color.gray.opacity(0.10)
        }
    }
    
    private func textColor(for level: Int, isTitle: Bool) -> Color {
        if level >= 3 {
            return isTitle ? Color.white.opacity(0.92) : Color.white.opacity(0.8)
        } else if level >= 1 {
            return isTitle ? Color.adaptiveText.opacity(0.9) : Color.adaptiveText.opacity(0.7)
        } else {
            return isTitle ? Color.adaptiveTextSecondary : Color.adaptiveTextSecondary.opacity(0.7)
        }
    }
    
    private func dayNumber(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func fullDateLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
