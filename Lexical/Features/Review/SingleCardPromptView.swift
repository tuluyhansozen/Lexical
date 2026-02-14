import SwiftUI
import SwiftData
import LexicalCore

/// Prompt-mode single card flow used by notification deep links.
struct SingleCardPromptView: View {
    let lemma: String
    let presetDefinition: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var card: ReviewCard?
    @State private var isFlipped: Bool = false
    @State private var isLoading: Bool = true
    @State private var completionText: String?
    @State private var infoData: WordDetailData?

    var body: some View {
        ZStack {
            Color.adaptiveBackground.ignoresSafeArea()

            if let completionText {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.green)
                    Text(completionText)
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText)
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.sonPrimary)
                    .clipShape(Capsule())
                }
                .padding()
            } else if isLoading {
                ProgressView("Loading card...")
            } else if let card {
                VStack {
                    HStack {
                        Text("Prompt Card")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("prompt.title")
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    Spacer()

                    FlashcardView(
                        item: card,
                        onFlip: { },
                        isFlipped: $isFlipped
                    )
                    .id(card.lemma)

                    Spacer()

                    if isFlipped {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Button {
                                    infoData = WordDetailDataBuilder.build(for: card, modelContext: modelContext)
                                } label: {
                                    Label("Info", systemImage: "info.circle")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.sonPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.sonPrimary.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                Button(role: .destructive) {
                                    removeFromDeck(card)
                                } label: {
                                    Label("Remove from Deck", systemImage: "trash")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.red.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }

                            HStack(spacing: 12) {
                                GradeButton(title: "Again", color: .red) { submit(1) }
                                GradeButton(title: "Hard", color: .orange) { submit(2) }
                                GradeButton(title: "Good", color: .blue) { submit(3) }
                                GradeButton(title: "Easy", color: .green) { submit(4) }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                    } else {
                        Text("Tap card to reveal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 28)
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
        .task {
            loadOrCreateCard()
        }
        .sheet(item: $infoData) { detail in
            WordDetailSheet(data: detail)
                .presentationDetents([.medium, .large])
        }
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
