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

    private let fsrs = FSRSV4Engine()

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
                        Spacer()
                        Button("Ignore Word") {
                            ignoreCard(card)
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
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
                        HStack(spacing: 12) {
                            GradeButton(title: "Again", color: .red) { submit(1) }
                            GradeButton(title: "Hard", color: .orange) { submit(2) }
                            GradeButton(title: "Good", color: .blue) { submit(3) }
                            GradeButton(title: "Easy", color: .green) { submit(4) }
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
        guard var card else { return }

        Task { @MainActor in
            let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
            let lastReview = card.lastReviewDate ?? card.createdAt
            let elapsedSeconds = Date().timeIntervalSince(lastReview)
            let daysElapsed = max(0, elapsedSeconds / 86_400.0)

            let newState = await fsrs.nextState(
                currentStability: card.stability,
                currentDifficulty: card.difficulty,
                recalled: grade >= 3,
                grade: grade,
                daysElapsed: daysElapsed
            )

            let interval = await fsrs.nextInterval(stability: max(newState.stability, 0.1))

            card.stability = max(newState.stability, 0.1)
            card.difficulty = newState.difficulty
            card.retrievability = newState.retrievability
            card.lastReviewDate = Date()
            card.nextReviewDate = Date().addingTimeInterval(interval * 86_400)
            card.reviewCount += 1
            card.status = card.stability >= 90 ? .known : .learning

            let event = ReviewEvent(
                userId: activeProfile.userId,
                lemma: card.lemma,
                grade: grade,
                durationMs: 0,
                scheduledDays: interval,
                reviewState: ReviewEvent.reviewState(for: grade)
            )
            modelContext.insert(event)

            upsertUserWordState(for: card, userId: activeProfile.userId, grade: grade)

            do {
                try modelContext.save()
                self.card = card
                completionText = "Saved '\(card.lemma)'"
            } catch {
                print("SingleCardPromptView: failed to save grade: \(error)")
            }
        }
    }

    @MainActor
    private func ignoreCard(_ card: ReviewCard) {
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
            completionText = "'\(card.lemma)' ignored"
        } catch {
            print("SingleCardPromptView: failed to ignore card: \(error)")
        }
    }

    private func upsertUserWordState(for card: ReviewCard, userId: String, grade: Int) {
        let key = UserWordState.makeKey(userId: userId, lemma: card.lemma)
        let descriptor = FetchDescriptor<UserWordState>(
            predicate: #Predicate { $0.userLemmaKey == key }
        )

        let state: UserWordState
        if let existing = try? modelContext.fetch(descriptor).first {
            state = existing
        } else {
            state = UserWordState(userId: userId, lemma: card.lemma)
            modelContext.insert(state)
        }

        state.stability = card.stability
        state.difficulty = card.difficulty
        state.retrievability = card.retrievability
        state.nextReviewDate = card.nextReviewDate
        state.lastReviewDate = card.lastReviewDate
        state.reviewCount = card.reviewCount
        if grade == 1 {
            state.lapseCount += 1
        }
        state.status = card.status
        state.touch()
    }
}
