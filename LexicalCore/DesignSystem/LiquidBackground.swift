import SwiftUI

/// Animated Mesh Gradient Background
public struct LiquidBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var animate = false

    public init() {}

    public var body: some View {
        ZStack {
            Color.adaptiveBackground

            if reduceTransparency {
                LinearGradient(
                    colors: [
                        Color.sonPrimary.opacity(0.12),
                        Color.sonCloud.opacity(0.26),
                        Color.sonPrimary.opacity(0.08),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                GeometryReader { geometry in
                    ZStack {
                        Circle()
                            .fill(Color.sonPrimary.opacity(0.24))
                            .frame(width: geometry.size.width * 0.84)
                            .offset(
                                x: animate ? -36 : 28,
                                y: animate ? -44 : 26
                            )
                            .blur(radius: 72)

                        Circle()
                            .fill(Color.sonCloud.opacity(0.42))
                            .frame(width: geometry.size.width * 0.76)
                            .offset(
                                x: animate ? 58 : -52,
                                y: animate ? 28 : -16
                            )
                            .blur(radius: 68)

                        Circle()
                            .fill(Color.sonPrimary.opacity(0.14))
                            .frame(width: geometry.size.width * 0.60)
                            .offset(
                                x: animate ? -24 : 18,
                                y: animate ? 110 : -92
                            )
                            .blur(radius: 84)
                    }
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
        .onChange(of: reduceMotion) { _, newValue in
            guard newValue else { return }
            animate = false
        }
        .ignoresSafeArea()
    }
}
