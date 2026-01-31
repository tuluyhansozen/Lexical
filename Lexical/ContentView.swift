import SwiftUI
import LexicalCore

struct ContentView: View {
    @State private var selectedTab: Int = 0
    @State private var showSession: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content Area
            TabView(selection: $selectedTab) {
                HomeFeedView()
                    .tag(0)
                
                Text("Search Placeholder")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.adaptiveBackground)
                    .tag(1)
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.sonPrimary)
                    
                    Text("Ready to Review?")
                        .font(.display(size: 32, weight: .bold))
                        .foregroundStyle(Color.adaptiveText)
                    
                    Text("Your retention engine is primed.")
                        .font(.bodyText)
                        .foregroundStyle(.secondary)
                    
                    Button("Start Session") {
                        showSession = true
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: 200)
                    .background(Color.sonPrimary)
                    .cornerRadius(16)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.adaptiveBackground)
                .tag(2)
                .fullScreenCover(isPresented: $showSession) {
                    ReviewSessionView()
                }
                
                StatsView()
                    .tag(3)
                
                WidgetPreviewScreen()
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never)) // We build our own custom tab bar logic if needed, or use standard
            .ignoresSafeArea()
            
            // Custom Tab Bar Overlay (matches design: "Feed", "Search", "Practice", "Stats", "Settings")
            CustomTabBar(selectedTab: $selectedTab)
        }
        .preferredColorScheme(.light) // Force light mode default to match initial view, but better to handle both
    }
}

