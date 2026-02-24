import SwiftUI
import SwiftData
import LexicalCore

struct HomeFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = ArticlesViewModel()
    @Query private var interestProfiles: [InterestProfile]
    @AppStorage(OnboardingStorageKeys.articleStylePreference) private var articleStylePreferenceRaw: String = ArticleStylePreference.balanced.rawValue
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true

    @State private var articleQuotaLabel: String?
    @State private var generationLimitMessage: String?
    @State private var generationUnavailableMessage: String?
    @State private var isPremium = false
    @State private var canGenerateAnotherArticle = false
    @State private var showingPremiumOffer = false

    private let featureGateService = FeatureGateService()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(hex: "F5F5F7").ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    headerView

                    if viewModel.articles.isEmpty {
                        emptyStateCard
                    } else {
                        ForEach(viewModel.articles) { article in
                            ArticleCardView(article: article)
                        }
                    }

                    // Upgrade pill (only when quota exhausted)
                    if !canGenerateAnotherArticle {
                        upgradePillButton
                            .padding(.top, 8)
                    }

                    if let articleQuotaLabel {
                        Text(articleQuotaLabel)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color(hex: "4A5565"))
                            .multilineTextAlignment(.leading)
                            .padding(.top, 2)
                            .accessibilityLabel(articleQuotaLabel)
                            .accessibilityIdentifier("reading.quotaLabel")
                    }

                    Color.clear.frame(height: 104)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 10)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                viewModel.loadArticles()
                refreshArticleQuotaLabel()
            }

            // Floating round FAB for generate
            if canGenerateAnotherArticle || viewModel.isGenerating {
                generateFAB
                    .padding(.trailing, 24)
                    .padding(.bottom, 90) // Clear the 61pt CustomTabBar
            }
        }
        .onAppear {
            viewModel.loadArticles()
            refreshArticleQuotaLabel()
        }
        .alert(
            "Weekly Article Limit Reached",
            isPresented: Binding(
                get: { generationLimitMessage != nil },
                set: { presented in
                    if !presented {
                        generationLimitMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(generationLimitMessage ?? "Free plan limit reached.")
        }
        .alert(
            "Article Generation Unavailable",
            isPresented: Binding(
                get: { generationUnavailableMessage != nil },
                set: { presented in
                    if !presented {
                        generationUnavailableMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(generationUnavailableMessage ?? "")
        }
        .sheet(isPresented: $showingPremiumOffer, onDismiss: {
            refreshArticleQuotaLabel()
        }) {
            PremiumOfferView(
                productIDs: SubscriptionEntitlementService.configuredProductIDs(),
                onEntitlementChanged: {
                    refreshArticleQuotaLabel()
                }
            )
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Reading")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color(hex: "0A0A0A"))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("reading.headerTitle")

            Text("Daily curated articles for you")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Color(hex: "4A4A4A"))
                .padding(.top, 4)
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    // MARK: - Round FAB for Generate
    @ViewBuilder
    private var generateFAB: some View {
        if viewModel.isGenerating {
            LiquidGlassButton(style: .root) {} label: {
                VStack(spacing: 4) {
                    ProgressView().tint(.white)
                    Text("Gen")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 80, height: 80)
            .disabled(true)
            .accessibilityIdentifier("reading.generatingButton")
        } else {
            LiquidGlassButton(style: .root) {
                Task { @MainActor in
                    await triggerGeneration()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .bold))
                    Text("New")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.white)
            }
            .frame(width: 80, height: 80)
            .accessibilityLabel(viewModel.articles.isEmpty ? "Generate first article" : "Generate new article")
            .accessibilityHint("Creates a new reading article based on your current plan.")
            .accessibilityIdentifier("reading.generateButton")
        }
    }

    // MARK: - Horizontal Pill for Upgrade
    private var upgradePillButton: some View {
        Button {
            showingPremiumOffer = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("Upgrade for more articles")
                    .font(.system(size: 12, weight: .regular))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "FF8FA1").opacity(0.85),
                                    Color(hex: "7B0002").opacity(0.75)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.15)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: Color(hex: "FF6A77").opacity(0.44), radius: 22, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upgrade for more articles")
        .accessibilityHint("Opens premium plans with unlimited generation.")
        .accessibilityIdentifier("reading.upgradeButton")
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PSYCHOLOGY")
                .font(.system(size: 12, weight: .regular))
                .tracking(0.617)
                .foregroundStyle(Color(hex: "4A5565"))
                .padding(.top, 16)

            Text("Your feed is ready")
                .font(.system(size: 18, weight: .semibold))
                .tracking(-0.44)
                .foregroundStyle(Color(hex: "0A0A0A"))
                .padding(.top, 7)
                .accessibilityAddTraits(.isHeader)

            Text("Generate your first personalized article to start your daily reading loop.")
                .font(.system(size: 14, weight: .regular))
                .tracking(-0.15)
                .lineSpacing(22.75 - 14)
                .foregroundStyle(Color(hex: "364153"))
                .padding(.top, 12)
                .lineLimit(4)

            Spacer(minLength: 8)

            Text("Tap ✨ below to begin")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(hex: "4A5565").opacity(0.7))
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 4)
    }

    @MainActor
    private func triggerGeneration() async {
        let profile = interestProfiles.first ?? InterestProfile(selectedTags: ["Technology"])
        let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let articleStylePreference = ArticleStylePreference(rawValue: articleStylePreferenceRaw) ?? .balanced
        let quotaSnapshot: ArticleGenerationQuotaSnapshot

        do {
            quotaSnapshot = try featureGateService.articleQuotaSnapshot(
                for: activeProfile,
                modelContext: modelContext
            )
            let canGenerate = quotaSnapshot.isUnlimited || quotaSnapshot.remaining > 0
            guard canGenerate else {
                generationLimitMessage = articleLimitMessage(from: quotaSnapshot)
                refreshArticleQuotaLabel()
                return
            }
        } catch {
            print("HomeFeedView: failed to evaluate article quota: \(error).")
            generationUnavailableMessage = "Article generation is temporarily unavailable. Please try again."
            refreshArticleQuotaLabel()
            return
        }

        let targetService = LexicalTargetingService()
        let isPremiumTier = quotaSnapshot.isUnlimited
        let plan = targetService.articleWordPlan(
            modelContext: modelContext,
            reinforcementCount: isPremiumTier ? 5 : 3,
            stretchCount: isPremiumTier ? 3 : 1
        )
        let targets = plan.allWords
        guard !targets.isEmpty else {
            generationUnavailableMessage = "No eligible lexemes with rank and definition are ready yet. Please try again after vocabulary data finishes loading."
            return
        }
        let adaptiveContext = AdaptivePromptContext(
            lexicalRank: activeProfile.lexicalRank,
            easyRatingVelocity: activeProfile.easyRatingVelocity
        )

        let generatedArticle = await viewModel.generateNewArticle(
            profile: profile,
            targetWords: targets,
            reinforcementWords: plan.reinforcementWords,
            stretchWords: plan.stretchWords,
            adaptiveContext: adaptiveContext,
            userId: activeProfile.userId,
            articleStylePreference: articleStylePreference.rawValue
        )

        guard let generatedArticle else { return }

        BanditScheduler.shared.scheduleArticleReadyNotificationIfNeeded(
            articleId: generatedArticle.id.uuidString,
            title: generatedArticle.title,
            notificationsEnabled: notificationsEnabled,
            appIsActive: scenePhase == .active
        )

        do {
            _ = try featureGateService.recordArticleGeneration(
                for: activeProfile,
                modelContext: modelContext
            )
        } catch {
            print("HomeFeedView: failed to record article usage: \(error)")
        }

        refreshArticleQuotaLabel()
    }

    @MainActor
    private func refreshArticleQuotaLabel() {
        let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)

        do {
            let snapshot = try featureGateService.articleQuotaSnapshot(
                for: activeProfile,
                modelContext: modelContext
            )
            isPremium = snapshot.isUnlimited
            canGenerateAnotherArticle = snapshot.isUnlimited || snapshot.remaining > 0

            if snapshot.isUnlimited {
                articleQuotaLabel = "Premium: Unlimited article generation."
            } else {
                let limit = snapshot.limit ?? FeatureGateService.freeArticleLimitPerWindow
                if let windowEnd = snapshot.windowEnd {
                    articleQuotaLabel = "Free: \(snapshot.remaining)/\(limit) weekly article left. Resets \(windowEnd.formatted(date: .abbreviated, time: .omitted))."
                } else {
                    articleQuotaLabel = "Free: \(snapshot.remaining)/\(limit) weekly article left."
                }
            }
        } catch {
            isPremium = false
            canGenerateAnotherArticle = false
            articleQuotaLabel = nil
        }
    }

    private func articleLimitMessage(from snapshot: ArticleGenerationQuotaSnapshot) -> String {
        guard !snapshot.isUnlimited else {
            return "Your premium plan has unlimited article generation."
        }

        if let windowEnd = snapshot.windowEnd {
            return "Free plan limit reached: 1 article per 7 days. Next reset: \(windowEnd.formatted(date: .abbreviated, time: .omitted))."
        }

        return "Free plan limit reached: 1 article per 7 days."
    }
}

#Preview("Feed with Articles") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: UserProfile.self,
             UserWordState.self,
             ReviewEvent.self,
             UsageLedger.self,
             LexemeDefinition.self,
             InterestProfile.self,
             GeneratedContent.self,
             MorphologicalRoot.self,
             DiscoveredLexeme.self,
        configurations: config
    )

    let profile = InterestProfile()
    container.mainContext.insert(profile)

    let userProfile = UserProfile(userId: UserProfile.fallbackLocalUserID)
    container.mainContext.insert(userProfile)

    // Seed 4 mock articles
    let articles: [GeneratedArticle] = [
        GeneratedArticle(
            id: UUID(),
            title: "The Art of Serendipity",
            content: "Many of history's greatest discoveries were not the result of rigorous planning, but rather pure serendipity. From penicillin to the microwave oven, chance encounters have shaped our world in profound ways. The cacophony of modern life often drowns out these quiet moments of discovery.",
            targetWords: ["serendipity", "rigorous", "cacophony"],
            category: "psychology",
            generatedDate: Date(),
            difficultyScore: 0.55,
            targetRank: 450,
            isSaved: false
        ),
        GeneratedArticle(
            id: UUID(),
            title: "The Physics of Sound",
            content: "A sonorous voice can captivate a room instantly. But what gives sound its depth and resonance? It begins with vibrations. Voice can captivate a room instantly. But what gives sound its depth and resonance? It begins with vibrations that travel through the air.",
            targetWords: ["sonorous", "captivate", "resonance"],
            category: "music",
            generatedDate: Date().addingTimeInterval(-3600),
            difficultyScore: 0.62,
            targetRank: 520,
            isSaved: false
        ),
        GeneratedArticle(
            id: UUID(),
            title: "The Language of Dreams",
            content: "Dreams have long been a source of fascination and mystery. The ephemeral nature of dreams makes them difficult to study, yet their vivid imagery and emotional intensity suggest they play a crucial role in our cognitive and emotional well-being.",
            targetWords: ["ephemeral", "fascination", "vivid"],
            category: "science",
            generatedDate: Date().addingTimeInterval(-7200),
            difficultyScore: 0.48,
            targetRank: 380,
            isSaved: true
        ),
        GeneratedArticle(
            id: UUID(),
            title: "Urban Architecture Today",
            content: "Modern cities are a testament to human ingenuity. The juxtaposition of ancient structures alongside sleek skyscrapers creates a compelling visual narrative. Architects today must reconcile aesthetic ambition with sustainable design principles.",
            targetWords: ["juxtaposition", "compelling", "reconcile"],
            category: "architecture",
            generatedDate: Date().addingTimeInterval(-14400),
            difficultyScore: 0.71,
            targetRank: 600,
            isSaved: false
        )
    ]

    // Seed word states for colored highlights
    let wordStates: [(String, UserWordStatus)] = [
        ("serendipity", .known),
        ("rigorous", .learning),
        ("cacophony", .new),
        ("sonorous", .new),
        ("captivate", .learning),
        ("resonance", .known),
        ("ephemeral", .new),
        ("fascination", .learning),
        ("vivid", .known),
        ("juxtaposition", .new),
        ("compelling", .known),
        ("reconcile", .learning)
    ]
    for (lemma, status) in wordStates {
        let state = UserWordState(
            userId: UserProfile.fallbackLocalUserID,
            lemma: lemma,
            status: status
        )
        container.mainContext.insert(state)
    }

    return ZStack(alignment: .bottom) {
        ZStack(alignment: .bottomTrailing) {
            Color(hex: "F5F5F7").ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Reading")
                            .font(.system(size: 32, weight: .semibold))
                            .tracking(-0.41)
                            .foregroundStyle(Color(hex: "0A0A0A"))
                        Text("Daily curated articles for you")
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(Color(hex: "4A4A4A"))
                            .padding(.top, 4)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                    // 4 Article Cards
                    ForEach(articles) { article in
                        ArticleCardView(article: article)
                    }

                    Color.clear.frame(height: 104)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
            .scrollIndicators(.hidden)

            // FAB
            LiquidGlassButton(style: .root) {} label: {
                VStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .bold))
                    Text("New")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.white)
            }
            .frame(width: 80, height: 80)
            .padding(.trailing, 24)
            .padding(.bottom, 90)
        }
        CustomTabBar(selectedTab: .constant(0))
    }
    .modelContainer(container)
}

#Preview("Empty State") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: UserProfile.self,
             UserWordState.self,
             ReviewEvent.self,
             UsageLedger.self,
             LexemeDefinition.self,
             InterestProfile.self,
             GeneratedContent.self,
             MorphologicalRoot.self,
             DiscoveredLexeme.self,
        configurations: config
    )

    let profile = InterestProfile()
    container.mainContext.insert(profile)

    let userProfile = UserProfile(userId: UserProfile.fallbackLocalUserID)
    container.mainContext.insert(userProfile)

    return ZStack(alignment: .bottom) {
        NavigationStack {
            HomeFeedView()
        }
        CustomTabBar(selectedTab: .constant(0))
    }
    .modelContainer(container)
}
