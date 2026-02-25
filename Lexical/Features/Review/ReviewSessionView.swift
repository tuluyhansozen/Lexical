import SwiftUI
import SwiftData
import LexicalCore

/// Tab-embedded Recall session surface aligned to the Figma review flow.
struct ReviewSessionView: View {
    @Environment(\.modelContext) private var modelContext

    var startSignal: UInt64 = 0
    var onNavigateToReading: (() -> Void)? = nil

    var body: some View {
        SessionContainer(
            modelContext: modelContext,
            startSignal: startSignal,
            onNavigateToReading: onNavigateToReading
        )
    }
}

struct SessionContainer: View {
    @StateObject private var manager: SessionManager
    private let startSignal: UInt64
    private let onNavigateToReading: (() -> Void)?

    init(
        modelContext: ModelContext,
        startSignal: UInt64,
        onNavigateToReading: (() -> Void)?
    ) {
        _manager = StateObject(wrappedValue: SessionManager(modelContext: modelContext))
        self.startSignal = startSignal
        self.onNavigateToReading = onNavigateToReading
    }

    var body: some View {
        SessionContent(
            manager: manager,
            startSignal: startSignal,
            onNavigateToReading: onNavigateToReading
        )
    }
}

struct SessionContent: View {
    @ObservedObject var manager: SessionManager
    let startSignal: UInt64
    let onNavigateToReading: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var revealAnswer = false
    @State private var infoData: WordDetailData?
    @State private var infoCard: ReviewCard?
    @State private var showingPremiumOffer = false
    @State private var hasStartedSession = false
    @State private var activeCardLemma: String?

    private let spec = RecallFigmaSpec()

    var body: some View {
        GeometryReader { geometry in
            let scale = spec.scale(for: geometry.size.width)
            ZStack {
                spec.backgroundColor(for: colorScheme).ignoresSafeArea()

                VStack(spacing: 0) {
                    RecallHeaderView(
                        spec: spec,
                        colorScheme: colorScheme,
                        scale: scale,
                        title: spec.screenTitle,
                        subtitle: spec.screenSubtitle
                    )
                    .accessibilityIdentifier("review.headerTitle")
                    .padding(.top, spec.headerTopPadding * scale)
                    .padding(.bottom, spec.headerBottomPadding * scale)
                    .padding(.horizontal, spec.horizontalPadding * scale)

                    RecallProgressTrackView(
                        spec: spec,
                        colorScheme: colorScheme,
                        value: progressValue,
                        total: progressTotal
                    )
                    .padding(.horizontal, spec.horizontalPadding * scale)
                    .padding(.bottom, spec.contentTopSpacing * scale)

                    progressCaption(scale: scale)
                        .padding(.horizontal, spec.horizontalPadding * scale)

                    contentView(scale: scale)
                }
                .safeAreaPadding(.bottom, 92)
            }
        }
        .onAppear {
            SeedLexemeIndex.prewarm()
            guard !hasStartedSession else { return }
            hasStartedSession = true
            startDueSession()
        }
        .onChange(of: startSignal) { _, _ in
            startDueSession()
        }
        .onChange(of: manager.currentCard?.lemma) { _, newLemma in
            guard newLemma != activeCardLemma else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                activeCardLemma = newLemma
                revealAnswer = false
            }
        }
        .sheet(item: $infoData, onDismiss: {
            infoCard = nil
        }) { detail in
            WordDetailSheet(data: detail)
                .presentationDetents(WordInfoSheetPresentation.detents(for: detail))
                .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showingPremiumOffer, onDismiss: {
            startDueSession()
        }) {
            PremiumOfferView(
                productIDs: SubscriptionEntitlementService.configuredProductIDs(),
                onEntitlementChanged: {
                    startDueSession()
                }
            )
        }
    }

    @ViewBuilder
    private func contentView(scale: CGFloat) -> some View {
        switch viewState {
        case .loading:
            Spacer()
            ProgressView()
            Spacer()

        case .question, .answer:
            if let card = manager.currentCard {
                Spacer(minLength: 8 * scale)
                
                FlashcardView(
                    spec: spec,
                    colorScheme: colorScheme,
                    scale: scale,
                    item: card,
                    onFlip: {
                        revealAnswer = true
                    },
                    isFlipped: Binding(
                        get: { revealAnswer },
                        set: { if $0 { revealAnswer = true } } 
                    )
                )
                .padding(.horizontal, spec.horizontalPadding * scale)
                .id(card.lemma)
                .transition(.liquidGlassSwap)

                Spacer(minLength: 16 * scale)
                
                answerActions(card: card, scale: scale)
                    .opacity(revealAnswer ? 1 : 0)
                    .disabled(!revealAnswer)
                Spacer(minLength: 8 * scale)
            }

        case .completion(let completionState):
            Spacer(minLength: 8 * scale)
            completionView(state: completionState, scale: scale)
            Spacer(minLength: 8 * scale)
        }
    }

    private func progressCaption(scale: CGFloat) -> some View {
        HStack {
            Text("\(Int(progressValue)) / \(Int(progressTotal))")
                .font(.system(size: 12 * scale, weight: .semibold))
                .foregroundStyle(spec.subtitleColor(for: colorScheme))
            Spacer()
        }
        .frame(height: 20 * scale)
    }

    private func answerActions(card: ReviewCard, scale: CGFloat) -> some View {
        VStack(spacing: 24 * scale) {
            // Contextual Actions
            HStack(spacing: 12 * scale) {
                Button {
                    infoCard = card
                    infoData = WordDetailDataBuilder.build(
                        for: card,
                        modelContext: modelContext
                    )
                    let lemma = card.lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                    Task { @MainActor in
                        let hydrated = await WordDetailDataBuilder.buildEnsuringSeedData(
                            for: card,
                            modelContext: modelContext
                        )
                        guard infoData?.lemma == lemma else { return }
                        infoData = hydrated
                    }
                } label: {
                    Text("Info")
                        .font(.system(size: 13 * scale, weight: .medium))
                        .foregroundStyle(spec.titleColor(for: colorScheme))
                        .frame(maxWidth: .infinity, minHeight: spec.figmaActionButtonHeight * scale)
                        .background(spec.figmaInfoButtonBackground)
                        .clipShape(RoundedRectangle(cornerRadius: spec.figmaActionButtonRadius * scale, style: .continuous))
                }
                .accessibilityIdentifier("review.infoButton")
                .accessibilityLabel("Word info")
                
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        manager.removeCurrentCardFromDeck()
                        revealAnswer = false
                    }
                } label: {
                    Text("Remove")
                        .font(.system(size: 13 * scale, weight: .medium))
                        .foregroundStyle(spec.figmaRemoveButtonText)
                        .frame(maxWidth: .infinity, minHeight: spec.figmaActionButtonHeight * scale)
                        .background(spec.figmaRemoveButtonBackground)
                        .clipShape(RoundedRectangle(cornerRadius: spec.figmaActionButtonRadius * scale, style: .continuous))
                }
                .accessibilityIdentifier("review.removeButton")
                .disabled(manager.isSubmittingGrade)
            }
            .buttonStyle(.plain)

            // Grading Toolbar
            HStack(spacing: 16 * scale) {
                RecallGradeActionButton(
                    spec: spec,
                    colorScheme: colorScheme,
                    scale: scale,
                    grade: 1,
                    title: "Again"
                ) { submit(1) }
                .accessibilityIdentifier("review.gradeAgain")

                RecallGradeActionButton(
                    spec: spec,
                    colorScheme: colorScheme,
                    scale: scale,
                    grade: 2,
                    title: "Hard"
                ) { submit(2) }
                .accessibilityIdentifier("review.gradeHard")

                RecallGradeActionButton(
                    spec: spec,
                    colorScheme: colorScheme,
                    scale: scale,
                    grade: 3,
                    title: "Good"
                ) { submit(3) }
                .accessibilityIdentifier("review.gradeGood")

                RecallGradeActionButton(
                    spec: spec,
                    colorScheme: colorScheme,
                    scale: scale,
                    grade: 4,
                    title: "Easy"
                ) { submit(4) }
                .accessibilityIdentifier("review.gradeEasy")
            }
            .disabled(manager.isSubmittingGrade)
            .padding(.horizontal, 8 * scale)
        }
        .padding(.horizontal, spec.horizontalPadding * scale)
    }

    private func completionView(state: RecallCompletionState, scale: CGFloat) -> some View {
        VStack(spacing: 18 * scale) {
            RecallCardSurface(spec: spec, colorScheme: colorScheme, scale: scale) {
                VStack(alignment: .leading, spacing: 10 * scale) {
                    Text(completionTitle(for: state))
                        .font(.system(size: 28 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(spec.titleColor(for: colorScheme))
                        .minimumScaleFactor(0.78)

                    Text(completionMessage(for: state))
                        .font(.system(size: 16 * scale, weight: .regular))
                        .foregroundStyle(spec.subtitleColor(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, spec.horizontalPadding * scale)

            completionActions(for: state, scale: scale)
                .padding(.horizontal, spec.horizontalPadding * scale)
        }
    }

    @ViewBuilder
    private func completionActions(for state: RecallCompletionState, scale: CGFloat) -> some View {
        switch state {
        case .noDue:
            VStack(spacing: 10 * scale) {
                if manager.isPremiumUser, manager.canStartFallbackPractice {
                    RecallPrimaryActionButton(
                        spec: spec,
                        colorScheme: colorScheme,
                        scale: scale,
                        title: "Practice Now"
                    ) {
                        withAnimation(.easeInOut(duration: spec.advanceDuration)) {
                            manager.startFallbackPracticeSession()
                            revealAnswer = false
                        }
                    }
                    .accessibilityIdentifier("review.practiceNowButton")
                    .disabled(!manager.canStartFallbackPractice)
                    .opacity(manager.canStartFallbackPractice ? 1 : 0.55)
                } else if !manager.isPremiumUser {
                    RecallPrimaryActionButton(
                        spec: spec,
                        colorScheme: colorScheme,
                        scale: scale,
                        title: "Upgrade to Premium"
                    ) {
                        showingPremiumOffer = true
                    }
                    .accessibilityIdentifier("review.upgradeButton")
                    .accessibilityHint("Unlocks fallback practice when no cards are due.")
                }

                RecallNeutralActionButton(
                    spec: spec,
                    colorScheme: colorScheme,
                    scale: scale,
                    title: "Go to Reading"
                ) {
                    onNavigateToReading?()
                }
                .accessibilityIdentifier("review.goReadingButton")
            }

        case .dueComplete, .fallbackComplete, .fallbackUnavailable:
            RecallPrimaryActionButton(
                spec: spec,
                colorScheme: colorScheme,
                scale: scale,
                title: "Go to Reading"
            ) {
                onNavigateToReading?()
            }
            .accessibilityIdentifier("review.goReadingButton")
        }
    }

    private var viewState: RecallViewState {
        if manager.isSessionComplete {
            return .completion(completionState)
        }
        guard manager.currentCard != nil else {
            return .loading
        }
        return revealAnswer ? .answer : .question
    }

    private var completionState: RecallCompletionState {
        if manager.sessionMode == .fallbackPractice {
            return manager.initialQueueCount > 0 ? .fallbackComplete : .fallbackUnavailable
        }
        return manager.hadDueCardsAtSessionStart ? .dueComplete : .noDue
    }

    private var progressTotal: Double {
        Double(max(manager.initialQueueCount, 1))
    }

    private var progressValue: Double {
        if manager.isSessionComplete {
            return progressTotal
        }
        return Double(max(manager.completedCount, 0))
    }

    private func submit(_ grade: Int) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            manager.submitGrade(grade)
            revealAnswer = false
        }
    }

    private func startDueSession() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            revealAnswer = false
            manager.startSession(mode: .dueOnly)
            activeCardLemma = manager.currentCard?.lemma
        }
    }

    private func completionTitle(for state: RecallCompletionState) -> String {
        switch state {
        case .dueComplete:
            return "Session complete"
        case .noDue:
            return "No cards due"
        case .fallbackComplete:
            return "Practice complete"
        case .fallbackUnavailable:
            return "No practice cards"
        }
    }

    private func completionMessage(for state: RecallCompletionState) -> String {
        switch state {
        case .dueComplete:
            return "You cleared today's recall queue. Great consistency."
        case .noDue:
            return "You're synced up for now. Start fallback practice or come back later."
        case .fallbackComplete:
            return "Great refresh. Your optional practice set is done."
        case .fallbackUnavailable:
            return "Capture more words from Reading to unlock extra practice."
        }
    }
}

struct LiquidGlassSwapModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 0.92 : 1.0)
            .blur(radius: isActive ? 12 : 0)
            .opacity(isActive ? 0 : 1)
            .overlay(
                Color.white
                    .opacity(isActive ? 0.4 : 0.0)
                    .blendMode(.plusLighter) // Light refraction simulation
            )
    }
}

extension AnyTransition {
    static var liquidGlassSwap: AnyTransition {
        .modifier(
            active: LiquidGlassSwapModifier(isActive: true),
            identity: LiquidGlassSwapModifier(isActive: false)
        )
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

    // Mock UI Data for Canvas
    let words = [
        ("serendipity", "occurrence and development of events by chance in a happy or beneficial way", "The discovery of the new star was a moment of serendipity."),
        ("ephemeral", "lasting for a very short time", "The autumn colors were beautiful but so ephemeral."),
        ("ubiquitous", "present, appearing, or found everywhere", "The smartphones have become ubiquitous in modern society.")
    ]
    
    for (word, definition, sentence) in words {
        let lexeme = LexemeDefinition(lemma: word)
        lexeme.basicMeaning = definition
        lexeme.sampleSentence = sentence
        container.mainContext.insert(lexeme)
        
        let state = UserWordState(userId: userProfile.userId, lemma: word)
        state.status = .learning
        state.nextReviewDate = Date().addingTimeInterval(-86400) // Due yesterday
        container.mainContext.insert(state)
    }

    return ReviewSessionView(startSignal: 0, onNavigateToReading: {})
        .modelContainer(container)
}
