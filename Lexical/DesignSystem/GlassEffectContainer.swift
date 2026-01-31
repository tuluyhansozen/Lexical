import SwiftUI
import UIKit

/// A container that applies a blur effect to its background using UIVisualEffectView
struct GlassEffectContainer<Content: View>: View {
    private let material: UIBlurEffect.Style
    private let content: Content
    
    init(material: UIBlurEffect.Style = .systemUltraThinMaterial, @ViewBuilder content: () -> Content) {
        self.material = material
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            GlassEffectView(material: material)
            content
        }
    }
}

/// UIViewRepresentable for UIVisualEffectView
struct GlassEffectView: UIViewRepresentable {
    var material: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: material))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: material)
    }
}
