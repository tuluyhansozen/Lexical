import SwiftUI
import SwiftData
import LexicalCore

struct HomeFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ArticlesViewModel()
    @Query private var interestProfiles: [InterestProfile]
    @AppStorage(OnboardingStorageKeys.articleStylePreference) private var articleStylePreferenceRaw: String = ArticleStylePreference.balanced.rawValue

    @State private var articleQuotaLabel: String?
    @State private var generationLimitMessage: String?
    @State private var generationUnavailableMessage: String?
    @State private var isPremium = false
    @State private var canGenerateAnotherArticle = false
    @State private var showingPremiumOffer = false

    private let featureGateService = FeatureGateService()

    var body: some View {
        ZStack {
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

                    primaryActionButton

                    if let articleQuotaLabel {
                        Text(articleQuotaLabel)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color(hex: "4A5565"))
                            .multilineTextAlignment(.leading)
                            .padding(.top, 2)
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
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(Color(hex: "0A0A0A"))
                .accessibilityIdentifier("reading.headerTitle")

            Text("Daily curated articles for you")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Color.black.opacity(0.8))
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
                        .font(.system(size: 14, weight: .regular))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color(hex: "181818"))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .accessibilityIdentifier("reading.generateButton")
        } else {
            Button {
                showingPremiumOffer = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Upgrade for more articles")
                        .font(.system(size: 12, weight: .regular))
                }
                .foregroundStyle(Color(hex: "06071A"))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "F4F4F4"), Color(hex: "FEFEFE")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.95), lineWidth: 1.2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color.black.opacity(0.14), radius: 3, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.top, 2)
            .accessibilityIdentifier("reading.upgradeButton")
        }
    }

    private var generatingButton: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(.white)
            Text("Generating article...")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(Color(hex: "181818"))
        .clipShape(Capsule())
        .padding(.top, 2)
        .accessibilityIdentifier("reading.generatingButton")
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PSYCHOLOGY")
                .font(.system(size: 10, weight: .regular))
                .tracking(0.62)
                .foregroundStyle(Color(hex: "4A5565"))
                .padding(.top, 16)

            Text("Your feed is ready")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: "0A0A0A"))
                .padding(.top, 10)

            Text("Generate your first personalized article to start your daily reading loop.")
                .font(.system(size: 14, weight: .regular))
                .lineSpacing(6)
                .foregroundStyle(Color(hex: "364153"))
                .padding(.top, 14)
                .lineLimit(4)

            Spacer(minLength: 14)

            Button {
                Task { @MainActor in
                    await triggerGeneration()
                }
            } label: {
                Text("Generate First Article \u{2192}")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "021105").opacity(0.71))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 25)
            .accessibilityIdentifier("reading.generateFirstButton")
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 253, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.22), radius: 4, x: 0, y: 4)
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

        let generated = await viewModel.generateNewArticle(
            profile: profile,
            targetWords: targets,
            reinforcementWords: plan.reinforcementWords,
            stretchWords: plan.stretchWords,
            adaptiveContext: adaptiveContext,
            userId: activeProfile.userId,
            articleStylePreference: articleStylePreference.rawValue
        )

        guard generated else { return }

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
