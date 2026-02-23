import SwiftUI
import SwiftData
import LexicalCore

/// Prompt-mode single card flow used by notification deep links.
struct SingleCardPromptView: View {
    let lemma: String
    let presetDefinition: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var card: ReviewCard?
    @State private var revealAnswer = false
    @State private var isLoading = true
    @State private var completionText: String?
    @State private var infoData: WordDetailData?

    private let spec = RecallFigmaSpec()

    var body: some View {
        GeometryReader { geometry in
            let scale = spec.scale(for: geometry.size.width)

            ZStack {
                spec.backgroundColor(for: colorScheme).ignoresSafeArea()

                if let completionText {
                    completionView(message: completionText, scale: scale)
                } else if isLoading {
                    ProgressView("Loading card...")
                } else if let card {
                    VStack(spacing: 0) {
                        RecallHeaderView(
                            spec: spec,
                            colorScheme: colorScheme,
                            scale: scale,
                            title: "Prompt Card",
                            subtitle: "Single-card recall check"
                        )
                        .accessibilityIdentifier("prompt.title")
                        .padding(.top, spec.headerTopPadding * scale)
                        .padding(.bottom, spec.headerBottomPadding * scale)
                        .padding(.horizontal, spec.horizontalPadding * scale)

                        RecallProgressTrackView(
                            spec: spec,
                            colorScheme: colorScheme,
                            value: revealAnswer ? 1 : 0,
                            total: 1
                        )
                        .padding(.horizontal, spec.horizontalPadding * scale)
                        .padding(.bottom, spec.contentTopSpacing * scale)

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

                        Spacer(minLength: 16 * scale)

                        if revealAnswer {
                            answerActions(card: card, scale: scale)
                            Spacer(minLength: 8 * scale)
                        } else {
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
                            .accessibilityIdentifier("prompt.revealButton")
                            .padding(.horizontal, spec.horizontalPadding * scale)
                            Spacer(minLength: 12 * scale)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("Unable to load card.")
                            .font(.headline)
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .task {
            loadOrCreateCard()
        }
        .sheet(item: $infoData) { detail in
            WordDetailSheet(data: detail)
                .presentationDetents([.medium, .large])
        }
    }

    private func completionView(message: String, scale: CGFloat) -> some View {
        VStack(spacing: 16 * scale) {
            RecallCardSurface(spec: spec, colorScheme: colorScheme, scale: scale) {
                VStack(alignment: .leading, spacing: 12 * scale) {
                    Text("Saved")
                        .font(.system(size: 30 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(spec.titleColor(for: colorScheme))
                    Text(message)
                        .font(.system(size: 16 * scale, weight: .regular))
                        .foregroundStyle(spec.subtitleColor(for: colorScheme))
                }
            }

            RecallPrimaryActionButton(
                spec: spec,
                colorScheme: colorScheme,
                scale: scale,
                title: "Done"
            ) {
                dismiss()
            }
            .accessibilityIdentifier("prompt.doneButton")
        }
        .padding(.horizontal, spec.horizontalPadding * scale)
    }

    private func answerActions(card: ReviewCard, scale: CGFloat) -> some View {
        VStack(spacing: 24 * scale) {
            // Contextual Actions
            HStack(spacing: 12 * scale) {
                Button {
                    infoData = WordDetailDataBuilder.build(for: card, modelContext: modelContext)
                } label: {
                    Text("Info")
                        .font(.system(size: 13 * scale, weight: .medium))
                        .foregroundStyle(spec.titleColor(for: colorScheme))
                        .frame(maxWidth: .infinity, minHeight: spec.figmaActionButtonHeight * scale)
                        .background(spec.figmaInfoButtonBackground)
                        .clipShape(RoundedRectangle(cornerRadius: spec.figmaActionButtonRadius * scale, style: .continuous))
                }
                .accessibilityIdentifier("prompt.infoButton")
                .accessibilityLabel("Word info")
                
                Button {
                    removeFromDeck(card)
                } label: {
                    Text("Remove")
                        .font(.system(size: 13 * scale, weight: .medium))
                        .foregroundStyle(spec.figmaRemoveButtonText)
                        .frame(maxWidth: .infinity, minHeight: spec.figmaActionButtonHeight * scale)
                        .background(spec.figmaRemoveButtonBackground)
                        .clipShape(RoundedRectangle(cornerRadius: spec.figmaActionButtonRadius * scale, style: .continuous))
                }
                .accessibilityIdentifier("prompt.removeButton")
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
                .accessibilityIdentifier("prompt.gradeAgain")

                RecallGradeActionButton(
                    spec: spec,
                    colorScheme: colorScheme,
                    scale: scale,
                    grade: 2,
                    title: "Hard"
                ) { submit(2) }
                .accessibilityIdentifier("prompt.gradeHard")

                RecallGradeActionButton(
                    spec: spec,
                    colorScheme: colorScheme,
                    scale: scale,
                    grade: 3,
                    title: "Good"
                ) { submit(3) }
                .accessibilityIdentifier("prompt.gradeGood")

                RecallGradeActionButton(
                    spec: spec,
                    colorScheme: colorScheme,
                    scale: scale,
                    grade: 4,
                    title: "Easy"
                ) { submit(4) }
                .accessibilityIdentifier("prompt.gradeEasy")
            }
            .padding(.horizontal, 8 * scale)
        }
        .padding(.horizontal, spec.horizontalPadding * scale)
    }

    @MainActor
    private func loadOrCreateCard() {
        isLoading = true
        defer { isLoading = false }

        let normalizedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedLemma.isEmpty else { return }

        let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let stateKey = UserWordState.makeKey(userId: activeProfile.userId, lemma: normalizedLemma)

        let lexemeDescriptor = FetchDescriptor<LexemeDefinition>(
            predicate: #Predicate { $0.lemma == normalizedLemma }
        )
        var lexeme = try? modelContext.fetch(lexemeDescriptor).first

        if lexeme == nil, let presetDefinition, !presetDefinition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let createdLexeme = LexemeDefinition(
                lemma: normalizedLemma,
                basicMeaning: presetDefinition,
                sampleSentence: "Use '\(normalizedLemma)' in a sentence."
            )
            modelContext.insert(createdLexeme)
            lexeme = createdLexeme
        }

        let stateDescriptor = FetchDescriptor<UserWordState>(
            predicate: #Predicate { $0.userLemmaKey == stateKey }
        )

        let state = (try? modelContext.fetch(stateDescriptor).first) ?? {
            let created = UserWordState(
                userId: activeProfile.userId,
                lemma: normalizedLemma,
                status: .learning,
                nextReviewDate: Date()
            )
            modelContext.insert(created)
            return created
        }()

        do {
            try modelContext.save()
        } catch {
            print("SingleCardPromptView: failed to save card bootstrap: \(error)")
        }

        card = ReviewCard(
            lemma: normalizedLemma,
            originalWord: normalizedLemma,
            contextSentence: lexeme?.sampleSentence ?? "Use '\(normalizedLemma)' in a sentence.",
            definition: presetDefinition ?? lexeme?.basicMeaning,
            stability: state.stability,
            difficulty: state.difficulty,
            retrievability: state.retrievability,
            nextReviewDate: state.nextReviewDate,
            lastReviewDate: state.lastReviewDate,
            reviewCount: state.reviewCount,
            createdAt: state.createdAt,
            status: state.status
        )
    }

    private func submit(_ grade: Int) {
        guard let card else { return }

        Task { @MainActor in
            do {
                _ = try await ReviewWriteCoordinator.submitExplicitReview(
                    grade: grade,
                    lemma: card.lemma,
                    durationMs: 0,
                    modelContext: modelContext
                )

                if let refreshed = fetchCardSnapshot(for: card.lemma) {
                    self.card = refreshed
                }
                completionText = "Saved '\(card.lemma)'"
            } catch {
                print("SingleCardPromptView: failed to submit grade: \(error)")
            }
        }
    }

    @MainActor
    private func removeFromDeck(_ card: ReviewCard) {
        let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        activeProfile.markIgnored(card.lemma)

        let key = UserWordState.makeKey(userId: activeProfile.userId, lemma: card.lemma)
        let descriptor = FetchDescriptor<UserWordState>(
            predicate: #Predicate { $0.userLemmaKey == key }
        )
        let state = (try? modelContext.fetch(descriptor).first) ?? {
            let created = UserWordState(userId: activeProfile.userId, lemma: card.lemma, status: .ignored)
            modelContext.insert(created)
            return created
        }()

        state.status = .ignored
        state.touch()

        do {
            try modelContext.save()
            completionText = "'\(card.lemma)' removed from deck"
        } catch {
            print("SingleCardPromptView: failed to ignore card: \(error)")
        }
    }

    @MainActor
    private func fetchCardSnapshot(for lemma: String) -> ReviewCard? {
        let normalizedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let key = UserWordState.makeKey(userId: activeProfile.userId, lemma: normalizedLemma)

        let descriptor = FetchDescriptor<UserWordState>(
            predicate: #Predicate { $0.userLemmaKey == key }
        )
        guard let state = try? modelContext.fetch(descriptor).first else { return nil }

        let lexemeDescriptor = FetchDescriptor<LexemeDefinition>(
            predicate: #Predicate { $0.lemma == normalizedLemma }
        )
        let lexeme = try? modelContext.fetch(lexemeDescriptor).first

        return ReviewCard(
            lemma: normalizedLemma,
            originalWord: normalizedLemma,
            contextSentence: lexeme?.sampleSentence ?? "Use '\(normalizedLemma)' in a sentence.",
            definition: lexeme?.basicMeaning,
            stability: state.stability,
            difficulty: state.difficulty,
            retrievability: state.retrievability,
            nextReviewDate: state.nextReviewDate,
            lastReviewDate: state.lastReviewDate,
            reviewCount: state.reviewCount,
            createdAt: state.createdAt,
            status: state.status
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

    return SingleCardPromptView(
        lemma: "ephemeral",
        presetDefinition: "Lasting for a very short time."
    )
    .modelContainer(container)
}

