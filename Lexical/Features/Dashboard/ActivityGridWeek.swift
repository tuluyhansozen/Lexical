import SwiftUI
import LexicalCore

struct ActivityGridWeek: View {
    let points: [HeatmapPoint]
    let differentiateWithoutColor: Bool

    // Map counts to relative heights or predefined levels (0...4)
    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(0..<max(7, points.count), id: \.self) { index in
                if index < points.count {
                    let point = points[index]
                    let level = countToLevel(point.count)
                    
                    VStack(spacing: 6) {
                        Text(dayLabel(from: point.date))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.adaptiveTextSecondary)
                            .accessibilityHidden(true)

                        ZStack {
                            if #available(iOS 26, macOS 16, *) {
                                Color.clear
                                    .glassEffect(.regular.tint(color(for: level)), in: .rect(cornerRadius: 14))
                                    .overlay {
                                        if differentiateWithoutColor, level > 0 {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(Color.sonMidnight.opacity(0.65), lineWidth: 0.6)
                                        }
                                    }
                            } else {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(color(for: level))
                                    .overlay {
                                        if differentiateWithoutColor, level > 0 {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(Color.sonMidnight.opacity(0.65), lineWidth: 0.6)
                                        }
                                    }
                            }
                            
                            if point.count > 0 {
                                Text("\(point.count)")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(textColor(for: level))
                            }
                        }
                        .frame(width: 39, height: 39)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement()
                    .accessibilityLabel("\(dayFullName(from: point.date))")
                    .accessibilityValue("\(point.count) reviews")
                } else {
                    Spacer().frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // Convert count to 0-4 level
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
    
    private func textColor(for level: Int) -> Color {
        switch level {
        case 3, 4: return .white
        case 1, 2: return Color.adaptiveText
        default: return .clear
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
    
    private func dayLabel(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1)).uppercased()
    }
    
    private func dayFullName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}
