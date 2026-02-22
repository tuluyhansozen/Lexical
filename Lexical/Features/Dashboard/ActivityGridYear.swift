import SwiftUI
import LexicalCore

struct ActivityGridYear: View {
    let points: [HeatmapPoint]
    let differentiateWithoutColor: Bool
    
    // We expect exactly 12 points for the 12 months.
    private let columns = [
        GridItem(.adaptive(minimum: 64, maximum: 72), spacing: 8),
        GridItem(.adaptive(minimum: 64, maximum: 72), spacing: 8),
        GridItem(.adaptive(minimum: 64, maximum: 72), spacing: 8),
        GridItem(.adaptive(minimum: 64, maximum: 72), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<max(12, points.count), id: \.self) { index in
                if index < points.count {
                    let point = points[index]
                    let level = countToLevel(point.count)
                    
                    VStack(spacing: 2) {
                        Text(monthLabel(from: point.date))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(textColor(for: level, isTitle: true))
                        
                        Text("\(point.count)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(textColor(for: level, isTitle: false))
                            .opacity(level >= 4 ? 1.0 : 0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 72)
                    .aspectRatio(1, contentMode: .fit)
                    .background {
                        if #available(iOS 26, macOS 16, *) {
                            Color.clear
                                .glassEffect(.regular.tint(color(for: level)), in: .rect(cornerRadius: 14))
                        } else {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(color(for: level))
                        }
                    }
                    .overlay {
                        if differentiateWithoutColor, level > 0 {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.sonMidnight.opacity(0.65), lineWidth: 0.6)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(fullMonthLabel(from: point.date))")
                    .accessibilityValue("\(point.count) reviews")
                } else {
                    Spacer()
                }
            }
        }
    }
    
    private func countToLevel(_ count: Int) -> Int {
        let maxCount = max(points.map(\.count).max() ?? 1, 1)
        let normalized = Double(count) / Double(maxCount)
        switch normalized {
        case ..<0.01: return 0  // #f0f1f4 in design
        case ..<0.25: return 1  // rgba(79,115,92,0.15)
        case ..<0.5: return 2   // rgba(79,115,92,0.32)
        case ..<0.75: return 3  // rgba(79,115,92,0.58)
        default: return 4       // rgba(79,115,92,1.0) #4f735c
        }
    }
    
    private func color(for level: Int) -> Color {
        switch level {
        case 0: return Color(white: 0.95) // Very light gray (similar to bg-[#f0f1f4])
        case 1: return Color.sonPrimary.opacity(0.15)
        case 2: return Color.sonPrimary.opacity(0.32)
        case 3: return Color.sonPrimary.opacity(0.58)
        case 4: return Color.sonPrimary
        default: return Color(white: 0.95)
        }
    }
    
    private func textColor(for level: Int, isTitle: Bool) -> Color {
        if level >= 4 {
            // Darkest background gets white text
            return isTitle ? Color.white.opacity(0.92) : Color.white.opacity(0.8)
        } else if level >= 1 {
            // Medium background gets tinted dark text
            return isTitle ? Color.sonMidnight.opacity(0.8) : Color.sonMidnight.opacity(0.6)
        } else {
            // Lightest background gets gray text
            return isTitle ? Color.black.opacity(0.5) : Color.black.opacity(0.4)
        }
    }
    
    private func monthLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    private func fullMonthLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
