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
            // Base Fill (Coral)
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "E85D6C").opacity(0.15),
                            Color(hex: "E85D6C").opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Specular Highlight (Radial)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [.white.opacity(0.4), .clear]),
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .blur(radius: 5)

            // Border (Angular)
            Circle()
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: .white.opacity(0.9), location: 0.1),
                            .init(color: .white.opacity(0.2), location: 0.4),
                            .init(color: .clear, location: 0.6)
                        ]),
                        center: .center
                    ),
                    lineWidth: 1.5
                )
        }
    }

    private var leafGlassBase: some View {
        ZStack {
            // Background 3: Deep Dark Green (Base)
            Circle()
                .fill(Color(red: 0.01, green: 0.06, blue: 0.02).opacity(0.75))

            // Background 2: Bottom-heavy metallic gradient
            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.4, green: 0.4, blue: 0.4).opacity(0), location: 0.51),
                            .init(color: Color(red: 0.4, green: 0.4, blue: 0.4).opacity(0.4), location: 1.00)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Background 1: Top-heavy subtle gradient
            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.45, green: 0.45, blue: 0.45).opacity(0.3), location: 0.00),
                            .init(color: Color(red: 0.4, green: 0.4, blue: 0.4).opacity(0), location: 0.24)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Overlay Stroke (White, inset)
            Circle()
                .inset(by: 1)
                .stroke(Color.white.opacity(0.85), lineWidth: 2)
                .blur(radius: 0.5)
        }
    }
}
