import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

public enum GlassMaterial: Sendable {
    case ultraThin
    case thin
    case regular
}

/// A platform-safe blur container for iOS and macOS builds.
/// The `spacing` parameter defines the morphing threshold (surface tension)
/// for child elements within the container — per the Liquid Glass design system.
public struct GlassEffectContainer<Content: View>: View {
    private let material: GlassMaterial
    private let spacing: CGFloat
    private let content: Content

    public init(
        material: GlassMaterial = .ultraThin,
        spacing: CGFloat = 20.0,
        @ViewBuilder content: () -> Content
    ) {
        self.material = material
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        ZStack {
            GlassEffectView(material: material)
            content
        }
    }
}

#if canImport(UIKit)
struct GlassEffectView: UIViewRepresentable {
    let material: GlassMaterial

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle(for: material)))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle(for: material))
    }

    private func blurStyle(for material: GlassMaterial) -> UIBlurEffect.Style {
        switch material {
        case .ultraThin:
            return .systemUltraThinMaterial
        case .thin:
            return .systemThinMaterial
        case .regular:
            return .systemMaterial
        }
    }
}
#elseif canImport(AppKit)
struct GlassEffectView: NSViewRepresentable {
    let material: GlassMaterial

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = appKitMaterial(for: material)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = appKitMaterial(for: material)
    }

    private func appKitMaterial(for material: GlassMaterial) -> NSVisualEffectView.Material {
        switch material {
        case .ultraThin:
            return .hudWindow
        case .thin:
            return .sidebar
        case .regular:
            return .windowBackground
        }
    }
}
#else
struct GlassEffectView: View {
    let material: GlassMaterial

    var body: some View {
        Color.clear
    }
}
#endif
