import SwiftUI

// MARK: - Neo-Glass Node Roles

/// Semantic role for glass-styled matrix nodes.
public enum GlassNodeRole {
    case root
    case known
    case learning
    case new
    case unknown

    /// The semantic accent color for this role.
    public var accentColor: Color {
        switch self {
        case .root:     return .rootNode      // #5E5CE6
        case .known:    return .statusKnown   // #34C759
        case .learning: return .statusLearning // #FF9500
        case .new:      return .statusNew     // #FF2D55
        case .unknown:  return Color(hex: "8E8E93")
        }
    }

    /// Lighter tint used for the frosted fill.
    public var tintColor: Color {
        switch self {
        case .root:     return Color(hex: "C7C6FF")
        case .known:    return Color(hex: "B8F0C5")
        case .learning: return Color(hex: "FFD9A8")
        case .new:      return Color(hex: "FFC1CE")
        case .unknown:  return Color(hex: "D1D1D6")
        }
    }

    /// Text color — dark-on-light for WCAG contrast.
    public var textColor: Color {
        switch self {
        case .root:     return .white
        case .known:    return Color(hex: "1B5E2B")
        case .learning: return Color(hex: "6B3A00")
        case .new:      return Color(hex: "7A1230")
        case .unknown:  return Color(hex: "3A3A3C")
        }
    }

    public var textColorDark: Color { .white }

    public var strokeWidth: CGFloat {
        self == .root ? 2.5 : 1.2
    }

    public var glowOpacity: Double {
        self == .root ? 0.45 : 0.15
    }

    public var glowRadius: CGFloat {
        self == .root ? 14 : 5
    }
}

// MARK: - GlassNodeStyle ViewModifier

public struct GlassNodeStyle: ViewModifier {
    let role: GlassNodeRole
    @Environment(\.colorScheme) private var colorScheme

    public init(role: GlassNodeRole) {
        self.role = role
    }

    public func body(content: Content) -> some View {
        content
            .foregroundStyle(colorScheme == .dark ? role.textColorDark : role.textColor)
            .background(frostedFill)
            .overlay(accentStroke)
            .clipShape(Circle())
            .shadow(
                color: role.accentColor.opacity(role.glowOpacity),
                radius: role.glowRadius,
                x: 0, y: role == .root ? 2 : 1
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.06),
                radius: 3,
                x: 0, y: 2
            )
    }

    private var frostedFill: some View {
        ZStack {
            // Base pastel tint
            Circle()
                .fill(role.tintColor.opacity(colorScheme == .dark ? 0.30 : 0.68))

            // Inner highlight: radial gradient for 3D dimensionality
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.10 : 0.45),
                            Color.clear
                        ],
                        center: .init(x: 0.38, y: 0.32),
                        startRadius: 0,
                        endRadius: role == .root ? 60 : 40
                    )
                )

            // Bottom accent wash
            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.clear, location: 0.5),
                            .init(color: role.accentColor.opacity(colorScheme == .dark ? 0.15 : 0.12), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private var accentStroke: some View {
        Circle()
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: role.accentColor.opacity(colorScheme == .dark ? 0.55 : 0.40), location: 0.0),
                        .init(color: role.accentColor.opacity(colorScheme == .dark ? 0.80 : 0.55), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: role.strokeWidth
            )
    }
}

// MARK: - View Extension

public extension View {
    func glassNodeStyle(_ role: GlassNodeRole) -> some View {
        modifier(GlassNodeStyle(role: role))
    }
}

// MARK: - Preview

#Preview("Neo-Glass Nodes — Light") {
    VStack(spacing: 32) {
        HStack(spacing: 24) {
            nodePreview(role: .root, label: "spec\nroot", size: 96)
            nodePreview(role: .new, label: "Inspect", size: 72)
            nodePreview(role: .learning, label: "Prospect", size: 72)
        }
        HStack(spacing: 24) {
            nodePreview(role: .known, label: "Spectacle", size: 80)
            nodePreview(role: .unknown, label: "Spectre", size: 64)
        }
    }
    .padding(32)
    .background(Color(hex: "F5F5F7"))
}

@ViewBuilder
private func nodePreview(role: GlassNodeRole, label: String, size: CGFloat) -> some View {
    Text(label)
        .font(.system(size: role == .root ? 16 : 12, weight: role == .root ? .bold : .medium))
        .multilineTextAlignment(.center)
        .frame(width: size, height: size)
        .glassNodeStyle(role)
}
