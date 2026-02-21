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

    static let grayChannel: Double = 102.0 / 255.0
    static let leafLayerOneBurnOpacity: Double = 0.57
    static let leafLayerOneTopFadeStop: CGFloat = 0.32692
    static let rootInsetHighlightOpacity: Double = 0.5
    static let rootInsetLowlightOpacity: Double = 0.6
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
        .shadow(
            color: style == .leaf
                ? .black.opacity(colorScheme == .dark ? 0.24 : 0.16)
                : .clear,
            radius: style == .leaf ? (isPressed ? 6 : 10) : 0,
            x: 0,
            y: style == .leaf ? 5 : 0
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
                            Color(hex: "FFC6D0"),
                            Color(hex: "FF8FA1"),
                            Color(hex: "FF6E82")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color(hex: LiquidGlassFigmaTokens.rootBaseHex))
                .opacity(0.06)
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
                .opacity(colorScheme == .dark ? 0.08 : 0.05)
                .blendMode(.colorBurn)

            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(
                                color: Color(
                                    red: LiquidGlassFigmaTokens.grayChannel,
                                    green: LiquidGlassFigmaTokens.grayChannel,
                                    blue: LiquidGlassFigmaTokens.grayChannel,
                                    opacity: 0
                                ),
                                location: LiquidGlassFigmaTokens.rootGradientStartLocation
                            ),
                            .init(
                                color: Color(
                                    red: LiquidGlassFigmaTokens.grayChannel,
                                    green: LiquidGlassFigmaTokens.grayChannel,
                                    blue: LiquidGlassFigmaTokens.grayChannel,
                                    opacity: LiquidGlassFigmaTokens.rootGradientEndOpacity * 0.85
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
                .fill(.ultraThinMaterial)
                .blur(radius: LiquidGlassFigmaTokens.rootBackdropBlur)
                .opacity(colorScheme == .dark ? 0.46 : 0.32)
                .blendMode(.plusLighter)

            Circle()
                .fill(
                    Color.white
                        .opacity(colorScheme == .dark ? 0.16 : 0.15)
                )
                .blur(radius: 6)
                .blendMode(.screen)

            Circle()
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.86 : 0.78), lineWidth: 1.05)
                .blur(radius: 0.2)

            Circle()
                .strokeBorder(Color(hex: "B3B3B3").opacity(colorScheme == .dark ? 0.52 : 0.42), lineWidth: 0.75)
                .blendMode(.overlay)
        }
        .shadow(
            color: Color(hex: "FF6A77").opacity(colorScheme == .dark ? 0.56 : 0.44),
            radius: colorScheme == .dark ? 24 : 22,
            x: 0,
            y: colorScheme == .dark ? 1 : 4
        )
        .shadow(
            color: Color(hex: "67101D").opacity(colorScheme == .dark ? 0.42 : 0.18),
            radius: 8,
            x: 0,
            y: 4
        )
    }

    private var leafTopLeftBorder: some View {
        ZStack {
            Circle()
                .trim(from: 0.5, to: 1.0)
                .stroke(
                    Color.white.opacity(colorScheme == .dark ? 0.88 : 0.66),
                    style: StrokeStyle(lineWidth: LiquidGlassFigmaTokens.leafBorderWidth, lineCap: .round, lineJoin: .round)
                )

            Circle()
                .trim(from: 0.25, to: 0.75)
                .stroke(
                    Color.white.opacity(colorScheme == .dark ? 0.88 : 0.66),
                    style: StrokeStyle(lineWidth: LiquidGlassFigmaTokens.leafBorderWidth, lineCap: .round, lineJoin: .round)
                )
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
                        opacity: colorScheme == .dark ? 0.68 : LiquidGlassFigmaTokens.leafColorBurnOpacity
                    )
                )
                .blendMode(.colorBurn)

            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(
                                color: Color(
                                    red: LiquidGlassFigmaTokens.grayChannel,
                                    green: LiquidGlassFigmaTokens.grayChannel,
                                    blue: LiquidGlassFigmaTokens.grayChannel,
                                    opacity: 0
                                ),
                                location: LiquidGlassFigmaTokens.leafGradientStartLocation
                            ),
                            .init(
                                color: Color(
                                    red: LiquidGlassFigmaTokens.grayChannel,
                                    green: LiquidGlassFigmaTokens.grayChannel,
                                    blue: LiquidGlassFigmaTokens.grayChannel,
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
                .strokeBorder(Color(hex: "B3B3B3").opacity(colorScheme == .dark ? 0.58 : 0.52), lineWidth: 0.75)
                .blendMode(.overlay)
        }
        .compositingGroup()
    }

    private func insetStroke(
        color: Color,
        lineWidth: CGFloat,
        blurRadius: CGFloat,
        x: CGFloat,
        y: CGFloat,
        blendMode: BlendMode
    ) -> some View {
        Circle()
            .stroke(color, lineWidth: lineWidth)
            .blur(radius: blurRadius)
            .offset(x: x, y: y)
            .blendMode(blendMode)
            .mask(Circle())
    }
}
