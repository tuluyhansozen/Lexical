import SwiftUI
import SwiftData
import LexicalCore
import Foundation

struct ContentView: View {
    @EnvironmentObject var banditScheduler: BanditScheduler
    @State private var selectedTab: Int = 0
    @State private var showSession: Bool = false
    @State private var promptRoute: PromptCardRoute?
#if DEBUG
    @State private var didAutoCycle: Bool = false
    @Query private var debugLexemeItems: [LexemeDefinition]
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
        .fullScreenCover(item: $promptRoute) { route in
            NavigationStack {
                SingleCardPromptView(
                    lemma: route.lemma,
                    presetDefinition: route.definition
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            promptRoute = nil
                        }
                    }
                }
            }
        }
#if DEBUG
        .overlay(alignment: .topTrailing) {
            if ProcessInfo.processInfo.arguments.contains("--lexical-debug-seed-overlay") {
                DebugSeedOverlay(
                    wordCount: debugLexemeItems.count
                )
                .padding(.top, 12)
                .padding(.trailing, 12)
            }
        }
#endif
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .lexicalOpenPromptCard)) { notification in
            guard let lemma = notification.userInfo?["lemma"] as? String else { return }
            let definition = notification.userInfo?["definition"] as? String
            openPromptCard(lemma: lemma, definition: definition)
        }
        .onAppear {
            consumePendingPromptRouteIfNeeded()
        }
#if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--lexical-debug-open-explore") {
                selectedTab = 1
            }
            guard !didAutoCycle else { return }
            guard ProcessInfo.processInfo.arguments.contains("--lexical-debug-autocycle") else { return }
            didAutoCycle = true
            startDebugAutoCycle()
        }
#endif
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "lexical" else { return }
        let host = url.host?.lowercased()
        let path = url.path.lowercased()
        guard host == "card" || path.contains("card") else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let lemma = components?.queryItems?.first(where: { $0.name == "lemma" })?.value
        let definition = components?.queryItems?.first(where: { $0.name == "definition" })?.value
        guard let lemma, !lemma.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        openPromptCard(lemma: lemma, definition: definition)
    }

    private func openPromptCard(lemma: String, definition: String?) {
        selectedTab = 2
        promptRoute = PromptCardRoute(lemma: lemma, definition: definition)
    }

    private func consumePendingPromptRouteIfNeeded() {
        let defaults = UserDefaults.standard
        guard let lemma = defaults.string(forKey: "lexical.pending_prompt_lemma"),
              !lemma.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let definition = defaults.string(forKey: "lexical.pending_prompt_definition")
        defaults.removeObject(forKey: "lexical.pending_prompt_lemma")
        defaults.removeObject(forKey: "lexical.pending_prompt_definition")
        openPromptCard(lemma: lemma, definition: definition)
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

private struct PromptCardRoute: Identifiable {
    let lemma: String
    let definition: String?
    var id: String { lemma.lowercased() }
}

#if DEBUG
private struct DebugSeedOverlay: View {
    let wordCount: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Seed Count")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            Text("\(wordCount) words")
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .padding(8)
        .background(Color.black.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
#endif
