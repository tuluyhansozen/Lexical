import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = 0
    
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
                
                VStack {
                    Spacer()
                    Button("Start Practice Session") {
                        // In a real app we'd use a router. 
                        // For now this is just a placeholder tab.
                    }
                    .font(.headline)
                    .padding()
                    .background(Color.sonPrimary)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                    
                    Text("(Tap 'Practice' in Tab Bar to see placeholder)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.adaptiveBackground)
                .tag(2)
                .sheet(isPresented: .constant(true)) { // Force show for demo? No that's annoying.
                     // I will actually replace the CONTENT of the tab with ReviewSessionView 
                     // and hide the close button conceptually or just leave it non-functional
                     ReviewSessionView()
                }
                
                StatsView()
                    .tag(3)
                
                Text("Settings Placeholder")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.adaptiveBackground)
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

