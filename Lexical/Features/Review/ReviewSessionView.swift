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
            guard !hasStartedSession else { return }
            hasStartedSession = true
            startDueSession()
        }
        .onChange(of: startSignal) { _, _ in
            startDueSession()
        }
        .onChange(of: manager.currentCard?.lemma) { _, newLemma in
            guard newLemma != activeCardLemma else { return }
            activeCardLemma = newLemma
            withAnimation(.easeInOut(duration: spec.advanceDuration)) {
                revealAnswer = false
            }
        }
        .sheet(item: $infoData) { detail in
            WordDetailSheet(data: detail)
                .presentationDetents([.medium, .large])
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

        case .question:
            if let card = manager.currentCard {
                Spacer(minLength: 8 * scale)
                RecallQuestionCardView(
                    spec: spec,
                    colorScheme: colorScheme,
                    scale: scale,
                    card: card
                )
                .padding(.horizontal, spec.horizontalPadding * scale)

                Spacer(minLength: 22 * scale)
                RecallPrimaryActionButton(
                    spec: spec,
                    colorScheme: colorScheme,
                    scale: scale,
                    title: "Reveal Answer"
                ) {
                    withAnimation(.easeInOut(duration: spec.revealDuration)) {
                        revealAnswer = true
                    }
                }
                .accessibilityIdentifier("review.revealButton")
                .padding(.horizontal, spec.horizontalPadding * scale)
                Spacer(minLength: 12 * scale)
            }

        case .answer:
            if let card = manager.currentCard {
                Spacer(minLength: 8 * scale)
                RecallAnswerCardView(
                    spec: spec,
                    colorScheme: colorScheme,
                    scale: scale,
                    card: card
                )
                .padding(.horizontal, spec.horizontalPadding * scale)

                Spacer(minLength: 16 * scale)
                answerActions(card: card, scale: scale)
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
        VStack(spacing: 12 * scale) {
            HStack(spacing: 12 * scale) {
                RecallNeutralActionButton(
                    spec: spec,
                    colorScheme: colorScheme,
                    scale: scale,
                    title: "Info"
                ) {
                    infoData = WordDetailDataBuilder.build(for: card, modelContext: modelContext)
                }
                .accessibilityIdentifier("review.infoButton")
                .accessibilityLabel("Word info")
                .accessibilityHint("Shows definition, synonyms, and examples.")

                RecallNeutralActionButton(
                    spec: spec,
                    colorScheme: colorScheme,
                    scale: scale,
                    title: "Remove From Deck"
                ) {
                    withAnimation(.easeInOut(duration: spec.advanceDuration)) {
                        manager.removeCurrentCardFromDeck()
                        revealAnswer = false
                    }
                }
                .accessibilityIdentifier("review.removeButton")
                .disabled(manager.isSubmittingGrade)
                .accessibilityHint("Removes this word from your learning deck.")
            }

            HStack(spacing: 10 * scale) {
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
        withAnimation(.easeInOut(duration: spec.advanceDuration)) {
            manager.submitGrade(grade)
            revealAnswer = false
        }
    }

    private func startDueSession() {
        withAnimation(.easeInOut(duration: spec.advanceDuration)) {
            revealAnswer = false
        }
        manager.startSession(mode: .dueOnly)
        activeCardLemma = manager.currentCard?.lemma
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
