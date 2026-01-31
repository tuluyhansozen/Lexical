import SwiftUI

/// Animated Mesh Gradient Background
struct LiquidBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color("Background") // Fallback
            
            // Mesh Gradient Emulation using blurred circles
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: geometry.size.width * 0.8)
                        .offset(x: animate ? -30 : 30, y: animate ? -30 : 30)
                        .blur(radius: 60)
                    
                    Circle()
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: geometry.size.width * 0.8)
                        .offset(x: animate ? 50 : -50, y: animate ? 10 : -10)
                        .blur(radius: 60)
                    
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: geometry.size.width * 0.6)
                        .offset(x: animate ? -20 : 20, y: animate ? 100 : -100)
                        .blur(radius: 80)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
        .ignoresSafeArea()
    }
}
