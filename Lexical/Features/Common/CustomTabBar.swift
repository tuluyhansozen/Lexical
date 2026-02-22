import SwiftUI
import LexicalCore
#if canImport(UIKit)
import UIKit
#endif

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) private var colorScheme

    private let spec = TabBarFigmaSpec()
    private let tabs: [TabIconItem] = [
        .init(id: 0, iconAsset: "tab-learn", fallbackSymbol: "bag", label: "Learn", testID: "tab.learn"),
        .init(id: 1, iconAsset: "tab-explore", fallbackSymbol: "safari", label: "Explore", testID: "tab.explore"),
        .init(id: 2, iconAsset: "tab-practice", fallbackSymbol: "menucard", label: "Practice", testID: "tab.review"),
        .init(id: 3, iconAsset: "tab-stats", fallbackSymbol: "chart.bar.xaxis", label: "Stats", testID: "tab.stats"),
        .init(id: 4, iconAsset: "tab-profile", fallbackSymbol: "person", label: "Profile", testID: "tab.profile")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(.easeInOut(duration: spec.selectionDuration)) {
                        selectedTab = tab.id
                    }
                } label: {
                    ZStack {
                        if selectedTab == tab.id {
                            Circle()
                                .stroke(spec.selectedRingColor(for: colorScheme), lineWidth: spec.selectedRingLineWidth)
                                .frame(width: spec.selectionRingSize, height: spec.selectionRingSize)
                        }

                        tabIcon(tab)
                            .foregroundStyle(
                                selectedTab == tab.id
                                ? spec.selectedIconColor(for: colorScheme)
                                : spec.unselectedIconColor(for: colorScheme)
                            )
                    }
                    .frame(maxWidth: .infinity, minHeight: 31)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
                .accessibilityValue(selectedTab == tab.id ? "Selected" : "Not selected")
                .accessibilityIdentifier(tab.testID)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: spec.height)
        .background(spec.backgroundColor(for: colorScheme))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: spec.topCornerRadius, topTrailingRadius: spec.topCornerRadius))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(spec.topBorderColor(for: colorScheme))
                .frame(height: 1)
        }
        .background(spec.backgroundColor(for: colorScheme).ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder
    private func tabIcon(_ tab: TabIconItem) -> some View {
        let useBundledIcons = false

        #if canImport(UIKit)
        let iconBundle: Bundle? = {
            #if SWIFT_PACKAGE
            return .module
            #else
            return .main
            #endif
        }()

        if useBundledIcons, let iconBundle, UIImage(named: tab.iconAsset, in: iconBundle, with: nil) != nil {
            Image(tab.iconAsset, bundle: iconBundle)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: spec.iconSize, height: spec.iconSize)
        } else {
            Image(systemName: tab.fallbackSymbol)
                .font(.system(size: spec.iconSize, weight: .regular))
        }
        #else
        Image(systemName: tab.fallbackSymbol)
            .font(.system(size: spec.iconSize, weight: .regular))
        #endif
    }
}

struct TabBarFigmaSpec {
    let height: CGFloat = 61
    let topCornerRadius: CGFloat = 15
    let iconSize: CGFloat = 18
    let selectionRingSize: CGFloat = 24
    let selectedRingLineWidth: CGFloat = 1.3
    let selectionDuration: Double = 0.16

    let lightBackgroundHex = "F9F9FA"
    let darkBackgroundHex = "F9F9FA"
    let lightTopBorderHex = "D1D5DC"
    let darkTopBorderHex = "D1D5DC"
    let selectedIconHex = "181C21"
    let unselectedIconHex = "70757E"

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

    func selectedRingColor(for colorScheme: ColorScheme) -> Color {
        Color(hex: selectedIconHex).opacity(colorScheme == .dark ? 0.92 : 0.88)
    }
}

private struct TabIconItem: Identifiable {
    let id: Int
    let iconAsset: String
    let fallbackSymbol: String
    let label: String
    let testID: String
}
