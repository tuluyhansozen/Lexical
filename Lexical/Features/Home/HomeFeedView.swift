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
        ZStack {
            Color.adaptiveBackground.ignoresSafeArea()

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

                    primaryActionButton

                    if let articleQuotaLabel {
                        Text(articleQuotaLabel)
                            .font(.caption)
                            .foregroundStyle(Color.adaptiveTextSecondary)
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
        VStack(alignment: .leading, spacing: 2) {
            Text("Reading")
                .font(.display(.largeTitle, weight: .bold))
                .foregroundStyle(Color.adaptiveText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("reading.headerTitle")

            Text("Daily curated articles for you")
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary)
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        if viewModel.isGenerating {
            generatingButton
        } else if canGenerateAnotherArticle {
            Button {
                Task { @MainActor in
                    await triggerGeneration()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                    Text(viewModel.articles.isEmpty ? "Generate First Article" : "Generate New Article")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.sonPrimary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .accessibilityLabel(viewModel.articles.isEmpty ? "Generate first article" : "Generate new article")
            .accessibilityHint("Creates a new reading article based on your current plan.")
            .accessibilityIdentifier("reading.generateButton")
        } else {
            Button {
                showingPremiumOffer = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Upgrade for more articles")
                        .font(.subheadline)
                }
                .foregroundStyle(Color.adaptiveText)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    LinearGradient(
                        colors: [Color.adaptiveSurfaceElevated, Color.adaptiveSurface],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.adaptiveBorder, lineWidth: 1.2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color.cardShadow, radius: 3, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.top, 2)
            .accessibilityLabel("Upgrade for more articles")
            .accessibilityHint("Opens premium plans with unlimited generation.")
            .accessibilityIdentifier("reading.upgradeButton")
        }
    }

    private var generatingButton: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(.white)
            Text("Generating article...")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(Color.sonPrimary)
        .clipShape(Capsule())
        .padding(.top, 2)
        .accessibilityIdentifier("reading.generatingButton")
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PSYCHOLOGY")
                .font(.caption2)
                .tracking(0.62)
                .foregroundStyle(Color.adaptiveTextSecondary)
                .padding(.top, 16)

            Text("Your feed is ready")
                .font(.cardTitle)
                .foregroundStyle(Color.adaptiveText)
                .padding(.top, 10)
                .accessibilityAddTraits(.isHeader)

            Text("Generate your first personalized article to start your daily reading loop.")
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(Color.adaptiveTextSecondary)
                .padding(.top, 14)
                .lineLimit(4)

            Spacer(minLength: 14)

            Button {
                Task { @MainActor in
                    await triggerGeneration()
                }
            } label: {
                Text("Generate First Article \u{2192}")
                    .font(.headline)
                    .foregroundStyle(Color.sonPrimary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 25)
            .accessibilityLabel("Generate first article")
            .accessibilityHint("Creates your first reading article.")
            .accessibilityIdentifier("reading.generateFirstButton")
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 253, alignment: .topLeading)
        .background(Color.adaptiveSurfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.adaptiveBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.cardShadow, radius: 4, x: 0, y: 4)
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

#Preview {
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

    return HomeFeedView()
        .modelContainer(container)
}

