import SwiftUI
import LexicalCore

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) private var colorScheme

    private let spec = TabBarFigmaSpec()
    private let tabs: [TabIconItem] = [
        .init(id: 0, symbolName: "house", label: "Learn", testID: "tab.learn"),
        .init(id: 1, symbolName: "safari", label: "Explore", testID: "tab.explore"),
        .init(id: 2, symbolName: "menucard", label: "Practice", testID: "tab.review"),
        .init(id: 3, symbolName: "chart.bar", label: "Stats", testID: "tab.stats"),
        .init(id: 4, symbolName: "person", label: "Profile", testID: "tab.profile")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(.easeInOut(duration: spec.selectionDuration)) {
                        selectedTab = tab.id
                    }
                } label: {
                    tabIcon(tab)
                        .foregroundStyle(
                            selectedTab == tab.id
                            ? spec.selectedIconColor(for: colorScheme)
                            : spec.unselectedIconColor(for: colorScheme)
                        )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minWidth: spec.minimumHitTarget, minHeight: spec.contentHeight)
                .accessibilityLabel(tab.label)
                .accessibilityValue(selectedTab == tab.id ? "Selected" : "Not selected")
                .accessibilityIdentifier(tab.testID)
            }
        }
        .frame(height: spec.contentHeight)
        .frame(maxWidth: .infinity)
        .background(spec.backgroundColor(for: colorScheme))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: spec.topCornerRadius, topTrailingRadius: spec.topCornerRadius))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(spec.topBorderColor(for: colorScheme))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func tabIcon(_ tab: TabIconItem) -> some View {
        Image(systemName: tab.symbolName)
            .font(.system(size: spec.iconSize, weight: .regular))
            .frame(width: spec.minimumHitTarget, height: spec.minimumHitTarget, alignment: .center)
    }
}

struct TabBarFigmaSpec {
    let contentHeight: CGFloat = 49
    let minimumHitTarget: CGFloat = 44
    let topCornerRadius: CGFloat = 15
    let iconSize: CGFloat = 22
    let selectionDuration: Double = 0.16

    let lightBackgroundHex = "FFFFFF"
    let darkBackgroundHex = "FFFFFF"
    let lightTopBorderHex = "D1D5DC"
    let darkTopBorderHex = "D1D5DC"
    let selectedIconHex = "3E4958"
    let unselectedIconHex = "8A96A8"

    func backgroundColor(for colorScheme: ColorScheme) -> Color {
        Color(hex: colorScheme == .dark ? darkBackgroundHex : lightBackgroundHex)
    }

    func topBorderColor(for colorScheme: ColorScheme) -> Color {
        Color(hex: colorScheme == .dark ? darkTopBorderHex : lightTopBorderHex)
    }

    func selectedIconColor(for colorScheme: ColorScheme) -> Color {
        Color(hex: selectedIconHex)
    }

    func unselectedIconColor(for colorScheme: ColorScheme) -> Color {
        Color(hex: unselectedIconHex)
    }

}

private struct TabIconItem: Identifiable {
    let id: Int
    let symbolName: String
    let label: String
    let testID: String
}
