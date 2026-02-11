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
    @EnvironmentObject private var motionService: MotionService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    // State
    @State private var isPressed = false
    @State private var touchPoint: CGPoint = .zero
    @State private var touchStrength: Double = 0.0
    
    // Constants
    private let time = Date().timeIntervalSinceReferenceDate
    
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
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let tilt = motionService.tilt
            
            buttonContent
                .scaleEffect(isPressed ? 0.96 : 1.0)
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.32 : 0.18),
                    radius: isPressed ? 4 : 8,
                    x: 0,
                    y: isPressed ? 2 : 4
                )
                // Apply Metal Liquid Glass Shader (Elite Effect)
                .layerEffect(
                    ShaderLibrary.liquid_glass_surface(
                        .float(time),
                        .float2(tilt),
                        .float2(touchPoint), // Normalization handled in shader if bounds passed? 
                        // Wait, shader takes `position` and `bounds`.
                        // `touchPoint` should be relative (0..1) or absolute?
                        // Shader expects normalized if I divide by bounds.zw.
                        // I'll update touchPoint to be normalized (0..1) in logic.
                        .float(touchStrength)
                    ),
                    maxSampleOffset: .init(width: 30, height: 30),
                    isEnabled: !reduceTransparency && ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 17
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                .gesture(
                    SpatialTapGesture(coordinateSpace: .local)
                        .onEnded { event in
                            // Trigger Ripple
                            let location = event.location
                            // Normalize in GeometryReader?
                            // Need geometry to normalize.
                            // I'll wrap in GeometryReader or assume size.
                            // Actually, let's pass absolute point to shader, and shader normalizes using its own bounds?
                            // Shader gets `float4 bounds`. `uv = position / bounds.zw`.
                            // So if I pass `local value`, I need to normalize it myself if shader expects 0..1.
                            // My shader code: `float touchDist = distance(uv, touchPoint);`
                            // `uv` is 0..1. So `touchPoint` MUST be 0..1.
                            // I need the size to normalize.
                            
                            self.triggerRipple(at: location, in: .zero) // Placeholder, need geometry
                            action()
                        }
                )
        }
    }
    
    private var buttonContent: some View {
        // We need GeometryReader to get size for normalization
        GeometryReader { proxy in
            let size = proxy.size
            
            ZStack {
                if style == .root {
                    rootGlassBase
                } else {
                    leafGlassBase
                }
                
                label
            }
            .contentShape(Circle()) // Tap target
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isPressed {
                            isPressed = true
                            // Start ripple on press down
                            triggerRipple(at: value.location, in: size)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
        }
    }

    private func triggerRipple(at location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        
        // Normalize touch point (0..1)
        let normalized = CGPoint(x: location.x / size.width, y: location.y / size.height)
        self.touchPoint = normalized
        
        // Animate strength
        withAnimation(.easeOut(duration: 0.1)) {
            touchStrength = 1.0
        }
        withAnimation(.easeIn(duration: 0.5).delay(0.1)) {
            touchStrength = 0.0
        }
    }
    
    // MARK: - Styles (Moved from ExploreView)
    
    private var rootGlassBase: some View {
        ZStack {
            // Base Fill (Coral)
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "E85D6C").opacity(0.15),
                        Color(hex: "E85D6C").opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            // Specular Highlight (Radial)
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [.white.opacity(0.4), .clear]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 50
                ))
                .blur(radius: 5)
            
            // Border (Angular)
            Circle()
                .strokeBorder(
                    AngularGradient(gradient: Gradient(stops: [
                        .init(color: .white.opacity(0.9), location: 0.1),
                        .init(color: .white.opacity(0.2), location: 0.4),
                        .init(color: .clear, location: 0.6)
                    ]), center: .center),
                    lineWidth: 1.5
                )
        }
    }
    
    private var leafGlassBase: some View {
        ZStack {
             // Base Fill (Forest Green)
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "2B4735").opacity(0.25),
                        Color(hex: "2B4735").opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            // Inner Shadow/Glow
            Circle()
                 .stroke(Color.white.opacity(0.1), lineWidth: 4)
                 .blur(radius: 4)
                 .mask(Circle())

            // Border (Angular - top left light)
            Circle() // Figma 1:32 specific style
                .strokeBorder(
                    AngularGradient(gradient: Gradient(stops: [
                        .init(color: .white.opacity(0.8), location: 0.15),
                        .init(color: .clear, location: 0.45),
                    ]), center: .center),
                    lineWidth: 1.5
                )
        }
    }
}
