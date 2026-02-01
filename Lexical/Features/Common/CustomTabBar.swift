import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    let tabs = [
        (icon: "book.fill", label: "Feed"),
        (icon: "network", label: "Explore"),
        (icon: "graduationcap.fill", label: "Practice"),
        (icon: "chart.bar.fill", label: "Stats"),
        (icon: "person.circle", label: "Profile")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 24))
                            .symbolEffect(.bounce, value: selectedTab == index) // iOS 17+ Symbol Effect
                        
                        Text(tabs[index].label)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .fontDesign(.rounded)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(selectedTab == index ? .sonPrimary : .gray.opacity(0.8))
                    .scaleEffect(selectedTab == index ? 1.05 : 1.0)
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 34) // Bottom safe area
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: -5)
        }
        // Border top
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
        }
    }
}
