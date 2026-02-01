import SwiftUI
import SwiftData
import LexicalCore

struct ContentView: View {
    @EnvironmentObject var banditScheduler: BanditScheduler
    @State private var selectedTab: Int = 0
    @State private var showSession: Bool = false
#if DEBUG
    @State private var didAutoCycle: Bool = false
    @Query private var debugVocabularyItems: [VocabularyItem]
    @Query private var debugRoots: [MorphologicalRoot]
#endif
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content Area
            TabView(selection: $selectedTab) {
                HomeFeedView()
                    .tag(0)
                
                ExploreView()
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
                    
                    #if DEBUG
                    Button("Trigger Notification (Bandit)") {
                        banditScheduler.scheduleTestNotification()
                    }
                    .font(.caption)
                    .foregroundStyle(Color.sonPrimary)
                    .padding(.top)
                    #endif
                    
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
                
                SettingsView()
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never)) // We build our own custom tab bar logic if needed, or use standard
            .ignoresSafeArea()
            
            // Custom Tab Bar Overlay (matches design: "Feed", "Search", "Practice", "Stats", "Settings")
            CustomTabBar(selectedTab: $selectedTab)
        }
        .preferredColorScheme(.light) // Force light mode default to match initial view, but better to handle both
#if DEBUG
        .overlay(alignment: .topTrailing) {
            DebugSeedOverlay(
                wordCount: debugVocabularyItems.count,
                rootCount: debugRoots.count
            )
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
#endif
        .onOpenURL { url in
             // Handle deep link (future)
        }
#if DEBUG
        .onAppear {
            guard !didAutoCycle else { return }
            guard ProcessInfo.processInfo.arguments.contains("--lexical-debug-autocycle") else { return }
            didAutoCycle = true
            startDebugAutoCycle()
        }
#endif
    }
#if DEBUG
    private func startDebugAutoCycle() {
        Task { @MainActor in
            let tabs = [0, 1, 2, 3, 4]
            for tab in tabs {
                selectedTab = tab
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }
        }
    }
#endif
}

#if DEBUG
private struct DebugSeedOverlay: View {
    let wordCount: Int
    let rootCount: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Seed Count")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            Text("\(wordCount) words")
                .font(.caption2)
                .foregroundStyle(.white)
            Text("\(rootCount) roots")
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .padding(8)
        .background(Color.black.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
#endif
