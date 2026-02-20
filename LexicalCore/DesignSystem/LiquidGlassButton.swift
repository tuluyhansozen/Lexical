import SwiftUI

public enum LiquidGlassStyle {
    case root
    case leaf
}

public struct LiquidGlassButton<Content: View>: View {
    let style: LiquidGlassStyle
    let action: () -> Void
    @ViewBuilder let label: Content

    // Environment
    @Environment(\.colorScheme) private var colorScheme
    @GestureState private var isPressed = false
    
    public init(
        style: LiquidGlassStyle = .leaf,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Content
    ) {
        self.style = style
        self.action = action
        self.label = label()
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                if style == .root {
                    rootGlassBase
                } else {
                    leafGlassBase
                }

                label
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.30 : 0.16),
            radius: isPressed ? 5 : 9,
            x: 0,
            y: isPressed ? 2 : 5
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in
                    state = true
                }
        )
        .animation(.spring(response: 0.22, dampingFraction: 0.80), value: isPressed)
    }

    // MARK: - Styles (Moved from ExploreView)

    private var rootGlassBase: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "FF9DA7"),
                            Color(hex: "FF6A77"),
                            Color(hex: "FF5C69")
                        ],
                        startPoint: .top,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.42), .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 58
                    )
                )
                .blur(radius: 8)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottom
                    ),
                )
                .blendMode(.plusLighter)

            Circle()
                .strokeBorder(Color.white.opacity(0.78), lineWidth: 1.6)
                .blur(radius: 0.35)

            Circle()
                .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.8)
                .blendMode(.multiply)
        }
        .shadow(color: Color(hex: "FF5A67").opacity(0.48), radius: 18, x: 0, y: 8)
        .overlay {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.2), .clear],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 26
                    )
                )
                .blur(radius: 1.2)
        }
    }

    private var leafGlassBase: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "193B27").opacity(colorScheme == .dark ? 0.85 : 0.82))

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "9CA79B").opacity(0.27),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(hex: "97A498").opacity(0.38)
                        ],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.18), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 42
                    )
                )
                .blur(radius: 4.5)

            Circle()
                .strokeBorder(Color.white.opacity(0.84), lineWidth: 1.5)
                .blur(radius: 0.28)

            Circle()
                .strokeBorder(Color.black.opacity(0.20), lineWidth: 0.8)
                .blendMode(.multiply)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.18), radius: 10, x: 0, y: 6)
    }
}
