import SwiftUI
import LexicalCore

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let tabs: [(id: Int, icon: String, label: String)] = [
        (id: 0, icon: "clipboard", label: "Learn"),
        (id: 1, icon: "safari", label: "Explore"),
        (id: 2, icon: "menucard", label: "Practice"),
        (id: 3, icon: "chart.bar.xaxis", label: "Stats"),
        (id: 4, icon: "person", label: "Profile")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.id) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedTab = tab.id
                    }
                } label: {
                    ZStack {
                        if selectedTab == tab.id {
                            selectedGlassCircle
                                .frame(width: 24, height: 24)
                        }

                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(
                                selectedTab == tab.id
                                ? Color(hex: "0A0A0A")
                                : Color(hex: "6F747B")
                            )
                            .offset(y: -0.5)
                    }
                    .frame(maxWidth: .infinity, minHeight: 31)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 61)
        .background(Color.white)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 15, topTrailingRadius: 15))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(hex: "D1D5DC"))
                .frame(height: 1)
        }
        .background(Color.white.ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder
    private var selectedGlassCircle: some View {
        if reduceTransparency {
            Circle()
                .fill(Color.white.opacity(0.94))
                .overlay(
                    Circle()
                        .stroke(Color(hex: "0A0A0A").opacity(0.85), lineWidth: 1)
                )
        } else if #available(iOS 26.0, *) {
            Circle()
                .fill(.clear)
                .glassEffect(.regular.tint(Color.white.opacity(0.06)).interactive(), in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color(hex: "0A0A0A").opacity(0.88), lineWidth: 1)
                )
        } else {
            GlassEffectContainer(material: .regular) {
                Circle()
                    .fill(Color.white.opacity(0.22))
            }
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color(hex: "0A0A0A").opacity(0.88), lineWidth: 1)
            )
        }
    }
}
