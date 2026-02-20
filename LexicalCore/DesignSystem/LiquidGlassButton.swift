import SwiftUI

struct LiquidGlassFigmaTokens {
    static let rootBackdropBlur: CGFloat = 12
    static let rootBaseHex = "7B0002"
    static let rootBurnOpacity: Double = 0.57
    static let rootGradientStartLocation: CGFloat = 0.5
    static let rootGradientEndOpacity: Double = 0.4

    static let leafColorBurnRed: Double = 2.0 / 255.0
    static let leafColorBurnGreen: Double = 17.0 / 255.0
    static let leafColorBurnBlue: Double = 5.0 / 255.0
    static let leafColorBurnOpacity: Double = 0.6
    static let leafBackdropBlur: CGFloat = 12
    static let leafGradientStartLocation: CGFloat = 0.50962
    static let leafGradientEndOpacity: Double = 0.4
    static let leafBorderWidth: CGFloat = 2
}

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
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.14), radius: isPressed ? 4 : 7, x: 0, y: 4)
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
                            Color(hex: "FFD4D9"),
                            Color(hex: "FF9AA4"),
                            Color(hex: "FF6F7B")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.96)

            Circle()
                .fill(Color(hex: LiquidGlassFigmaTokens.rootBaseHex))
                .opacity(0.22)
                .blendMode(.plusLighter)

            Circle()
                .fill(
                    Color(
                        red: 123.0 / 255.0,
                        green: 0.0 / 255.0,
                        blue: 2.0 / 255.0,
                        opacity: LiquidGlassFigmaTokens.rootBurnOpacity
                    )
                )
                .opacity(0.18)
                .blendMode(.colorBurn)

            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(
                                color: Color(red: 102.0 / 255.0, green: 102.0 / 255.0, blue: 102.0 / 255.0, opacity: 0),
                                location: LiquidGlassFigmaTokens.rootGradientStartLocation
                            ),
                            .init(
                                color: Color(
                                    red: 102.0 / 255.0,
                                    green: 102.0 / 255.0,
                                    blue: 102.0 / 255.0,
                                    opacity: LiquidGlassFigmaTokens.rootGradientEndOpacity
                                ),
                                location: 1.0
                            )
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.plusLighter)

            Circle()
                .fill(Color.black)
                .blur(radius: LiquidGlassFigmaTokens.rootBackdropBlur)
                .opacity(0.36)
                .blendMode(.plusLighter)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.34), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 36
                    )
                )
                .blur(radius: 4)

            Circle()
                .strokeBorder(Color.white.opacity(0.92), lineWidth: 1.15)
                .blur(radius: 0.25)

            Circle()
                .strokeBorder(Color(hex: "B3B3B3").opacity(0.6), lineWidth: 0.8)
                .blendMode(.overlay)
        }
        .shadow(color: Color(hex: "FF6A77").opacity(0.58), radius: 20, x: 0, y: 6)
        .overlay {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.3), .clear],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 34
                    )
                )
                .blur(radius: 1.8)
        }
    }

    private var leafGlassBase: some View {
        ZStack {
            Circle()
                .fill(
                    Color(
                        red: LiquidGlassFigmaTokens.leafColorBurnRed,
                        green: LiquidGlassFigmaTokens.leafColorBurnGreen,
                        blue: LiquidGlassFigmaTokens.leafColorBurnBlue,
                        opacity: LiquidGlassFigmaTokens.leafColorBurnOpacity
                    )
                )
                .blendMode(.colorBurn)

            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(
                                color: Color(
                                    red: 102.0 / 255.0,
                                    green: 102.0 / 255.0,
                                    blue: 102.0 / 255.0,
                                    opacity: 0
                                ),
                                location: LiquidGlassFigmaTokens.leafGradientStartLocation
                            ),
                            .init(
                                color: Color(
                                    red: 102.0 / 255.0,
                                    green: 102.0 / 255.0,
                                    blue: 102.0 / 255.0,
                                    opacity: LiquidGlassFigmaTokens.leafGradientEndOpacity
                                ),
                                location: 1
                            )
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blur(radius: LiquidGlassFigmaTokens.leafBackdropBlur)
                .blendMode(.plusLighter)

            Circle()
                .strokeBorder(
                    AngularGradient(
                        stops: [
                            .init(color: .white, location: 0.0),
                            .init(color: .white, location: 0.3),
                            .init(color: .white.opacity(0.12), location: 0.58),
                            .init(color: .clear, location: 0.82),
                            .init(color: .clear, location: 1.0)
                        ],
                        center: .center
                    ),
                    lineWidth: LiquidGlassFigmaTokens.leafBorderWidth
                )
                .rotationEffect(.degrees(-45))

            Circle()
                .strokeBorder(Color(hex: "B3B3B3").opacity(0.52), lineWidth: 0.75)
                .blendMode(.overlay)
        }
        .compositingGroup()
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.16), radius: 9, x: 0, y: 5)
    }
}
