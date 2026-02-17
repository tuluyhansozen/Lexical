import SwiftUI
import SwiftData
import LexicalCore

/// Main reading view with vocabulary highlighting and capture
struct ReaderView: View {
    let title: String
    let content: String
    let focusLemmas: [String]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.dismiss) private var dismiss

    @State private var tokenHighlights: [TokenHighlight] = []
    @State private var lemmaStates: [String: VocabularyState] = [:]
    @State private var isLoading = true
    @State private var selectedWord: SelectedWord?
    @State private var infoData: WordDetailData?

    private let tokenizationActor = TokenizationActor()
    private let lexemePromotionService = LexemePromotionService()

    private var normalizedFocusLemmaSet: Set<String> {
        Set(
            focusLemmas
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
    }
    
    struct SelectedWord: Identifiable {
        let id = UUID()
        let word: String
        let lemma: String
        let definition: String?
        let sentence: String
        let range: Range<String.Index>
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.adaptiveBackground
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView("Analyzing text...")
                    .progressViewStyle(.circular)
                    .foregroundStyle(Color.adaptiveTextSecondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Article Header
                        Text(title)
                            .font(.display(.largeTitle, weight: .bold))
                            .foregroundStyle(Color.adaptiveText)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("reader.title")

                        // Stats Bar
                        HStack(spacing: 16) {
                            StatBadge(
                                icon: "book.fill",
                                value: "\(countWords()) words",
                                color: .blue,
                                includeBorder: differentiateWithoutColor
                            )
                            StatBadge(
                                icon: "star.fill",
                                value: "\(countNewWords()) new",
                                color: .orange,
                                includeBorder: differentiateWithoutColor
                            )
                            StatBadge(
                                icon: "graduationcap.fill",
                                value: "\(countLearningWords()) learning",
                                color: .green,
                                includeBorder: differentiateWithoutColor
                            )
                        }
                        .padding(.horizontal, 20)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(countWords()) words, \(countNewWords()) new words, \(countLearningWords()) learning words")

                        Divider()
                            .padding(.horizontal, 20)

                        // Text Content with Highlighting
                        ReaderTextView(
                            text: content,
                            tokenHighlights: tokenHighlights
                        ) { word, sentence, range in
                            handleWordTap(word: word, sentence: sentence, range: range)
                        }
                        .frame(minHeight: 400)
                        .accessibilityIdentifier("reader.text")
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Settings or share
                } label: {
                    Image(systemName: "textformat.size")
                }
                .accessibilityLabel("Reading options")
                .accessibilityHint("Adjusts reader options.")
            }
        }
        .sheet(item: $infoData) { detail in
            WordDetailSheet(
                data: detail,
                onAddToDeck: {
                    handleCapture(lemma: detail.lemma, sentence: selectedWord?.sentence ?? "")
                    infoData = nil
                }
            )
            .presentationDetents([.medium, .large])
        }
        .task {
            await analyzeText()
        }
    }
    
    // MARK: - Analysis
    
    private func analyzeText() async {
        isLoading = true
        
        // Tokenize in background
        let tokens = await tokenizationActor.tokenize(content)
        
        // Extract unique lemmas
        let lemmas = Set(tokens.map { $0.lemma })
        
        // Resolve states on main thread
        let resolver = LemmaResolver(modelContext: modelContext)
        let rawStates = resolver.resolveStates(for: lemmas)
        let states = applyRankFiltering(to: rawStates)
        lemmaStates = states
        
        // Map tokens to highlights using their ORIGINAL RANGES
        // This fixes the lemma-to-surface mismatch bug!
        let focusSet = normalizedFocusLemmaSet
        tokenHighlights = tokens.compactMap { token in
            if !focusSet.isEmpty, !focusSet.contains(token.lemma) {
                return nil
            }
            guard let state = states[token.lemma], state != .known else { return nil }
            return TokenHighlight(range: token.range, state: state)
        }
        
        isLoading = false
    }
    
    // MARK: - Word Tap Handling
    
    private func handleWordTap(word: String, sentence: String, range: Range<String.Index>) {
        Task {
            let tokens = await tokenizationActor.tokenize(word)
            let lemma = tokens.first?.lemma ?? word.lowercased()

            selectedWord = SelectedWord(
                word: word,
                lemma: lemma,
                definition: fetchDefinition(
                    for: lemma,
                    userId: UserProfile.resolveActiveProfile(modelContext: modelContext).userId
                ),
                sentence: sentence,
                range: range
            )

            guard isHighlightedTap(lemma: lemma, range: range) else {
                return
            }

            infoData = WordDetailDataBuilder.build(
                for: makeReviewCardForDetail(lemma: lemma, originalWord: word, sentence: sentence),
                modelContext: modelContext
            )
        }
    }
    
    private func handleCapture(lemma: String, sentence: String) {
        let normalizedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedLemma.isEmpty else { return }

        let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let fallbackDefinition = fetchDefinition(
            for: normalizedLemma,
            userId: activeProfile.userId
        )

        do {
            let lexeme = try lexemePromotionService.upsertCanonicalLexeme(
                lemma: normalizedLemma,
                userId: activeProfile.userId,
                fallbackDefinition: fallbackDefinition,
                fallbackSentence: sentence,
                modelContext: modelContext
            )
            if lexeme.sampleSentence?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                lexeme.sampleSentence = sentence
            }
        } catch {
            print("ReaderView: failed canonical lexeme upsert for '\(normalizedLemma)': \(error)")
        }
        let stateKey = UserWordState.makeKey(userId: activeProfile.userId, lemma: normalizedLemma)
        let stateDescriptor = FetchDescriptor<UserWordState>(
            predicate: #Predicate { $0.userLemmaKey == stateKey }
        )
        let userState = (try? modelContext.fetch(stateDescriptor).first) ?? {
            let newState = UserWordState(userId: activeProfile.userId, lemma: normalizedLemma, status: .learning)
            modelContext.insert(newState)
            return newState
        }()

        userState.status = .learning
        if userState.nextReviewDate == nil || userState.nextReviewDate ?? .distantFuture > Date() {
            userState.nextReviewDate = Date()
        }
        userState.touch()

        do {
            try modelContext.save()
        } catch {
            print("ReaderView: failed to save captured word: \(error)")
        }

        lemmaStates[normalizedLemma] = .learning
    }

    private func isHighlightedTap(
        lemma: String,
        range: Range<String.Index>
    ) -> Bool {
        let normalizedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let state = lemmaStates[normalizedLemma], state != .known else {
            return false
        }

        guard tokenHighlights.contains(where: { $0.range.overlaps(range) }) else {
            return false
        }

        if !normalizedFocusLemmaSet.isEmpty {
            return normalizedFocusLemmaSet.contains(normalizedLemma)
        }
        return true
    }

    private func makeReviewCardForDetail(
        lemma: String,
        originalWord: String,
        sentence: String
    ) -> ReviewCard {
        let normalizedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let stateKey = UserWordState.makeKey(userId: activeProfile.userId, lemma: normalizedLemma)
        let stateDescriptor = FetchDescriptor<UserWordState>(
            predicate: #Predicate { $0.userLemmaKey == stateKey }
        )
        let state = try? modelContext.fetch(stateDescriptor).first

        return ReviewCard(
            lemma: normalizedLemma,
            originalWord: originalWord,
            contextSentence: sentence,
            definition: fetchDefinition(for: normalizedLemma, userId: activeProfile.userId),
            stability: state?.stability ?? 0.0,
            difficulty: state?.difficulty ?? 0.3,
            retrievability: state?.retrievability ?? 1.0,
            nextReviewDate: state?.nextReviewDate,
            lastReviewDate: state?.lastReviewDate,
            reviewCount: state?.reviewCount ?? 0,
            createdAt: state?.createdAt ?? Date(),
            status: state?.status ?? .learning
        )
    }

    private func applyRankFiltering(
        to baseStates: [String: VocabularyState]
    ) -> [String: VocabularyState] {
        guard !baseStates.isEmpty else { return baseStates }
        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let ignored = Set(profile.ignoredWords.map { $0.lowercased() })
        let range = LexicalCalibrationEngine().proximalRange(for: profile.lexicalRank)

        let candidateLemmas = Array(baseStates.keys)
        let lexemeDescriptor = FetchDescriptor<LexemeDefinition>(
            predicate: #Predicate { lexeme in
                candidateLemmas.contains(lexeme.lemma)
            }
        )
        let lexemes = (try? modelContext.fetch(lexemeDescriptor)) ?? []
        var rankByLemma: [String: Int] = [:]
        rankByLemma.reserveCapacity(lexemes.count)
        for lexeme in lexemes {
            if let rank = lexeme.rank {
                rankByLemma[lexeme.lemma] = rank
            }
        }

        var filtered = baseStates
        for (lemma, state) in baseStates {
            if ignored.contains(lemma) {
                filtered[lemma] = .known
                continue
            }

            guard let rank = rankByLemma[lemma] else {
                filtered[lemma] = state
                continue
            }

            if rank < range.lowerBound {
                filtered[lemma] = .known
            } else if rank > range.upperBound {
                filtered[lemma] = .unknown
            } else {
                filtered[lemma] = state
            }
        }

        return filtered
    }

    private func fetchDefinition(for lemma: String, userId: String) -> String? {
        let descriptor = FetchDescriptor<LexemeDefinition>(
            predicate: #Predicate { $0.lemma == lemma }
        )
        if let definition = (try? modelContext.fetch(descriptor).first)?.basicMeaning,
           !definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return definition
        }

        let discovered = try? lexemePromotionService.discoveredLexeme(
            lemma: lemma,
            userId: userId,
            modelContext: modelContext
        )
        return discovered?.definition
    }
    
    // MARK: - Stats
    
    private func countWords() -> Int {
        content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
    
    private func countNewWords() -> Int {
        let focusSet = normalizedFocusLemmaSet
        if focusSet.isEmpty {
            return lemmaStates.values.filter { $0 == .new }.count
        }
        return focusSet.filter { lemmaStates[$0] == .new }.count
    }
    
    private func countLearningWords() -> Int {
        let focusSet = normalizedFocusLemmaSet
        if focusSet.isEmpty {
            return lemmaStates.values.filter { $0 == .learning }.count
        }
        return focusSet.filter { lemmaStates[$0] == .learning }.count
    }
}

// MARK: - Supporting Views

struct StatBadge: View {
    let icon: String
    let value: String
    let color: Color
    var includeBorder: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.adaptiveText.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .overlay {
            if includeBorder {
                Capsule()
                    .stroke(color.opacity(0.45), lineWidth: 1)
            }
        }
        .clipShape(Capsule())
    }
}

/// Wrapper to integrate existing WordCaptureSheet with capture callback
struct WordCaptureSheetWrapper: View {
    let word: String
    let lemma: String
    let definition: String?
    let sentence: String
    let onCapture: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NEW WORD")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        
                        Text(word.capitalized)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(lemma)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()

                    if let definition,
                       !definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("DEFINITION", systemImage: "text.book.closed")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)

                            Text(definition)
                                .font(.body)
                        }
                        .padding()
                        .background(Color.adaptiveBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Context
                    VStack(alignment: .leading, spacing: 8) {
                        Label("CONTEXT", systemImage: "quote.opening")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        
                        Text(sentence)
                            .font(.body)
                            .italic()
                    }
                    .padding()
                    .background(Color.adaptiveBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
            }
            
            // Capture Button
            Button(action: {
                onCapture()
                dismiss()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to Learning Queue")
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.sonPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(24)
        }
        .background(Color.adaptiveSurface.ignoresSafeArea())
    }
}

#Preview {
    NavigationStack {
        ReaderView(
            title: "The Art of Learning",
            content: """
            Learning a new language is one of the most rewarding experiences a person can undertake. \
            The journey begins with simple vocabulary and gradually expands to encompass complex grammar \
            and nuanced expressions. Many learners find that immersion is the key to rapid progress.
            
            Serendipity often plays a role in language acquisition. Unexpected encounters with native \
            speakers or stumbling upon compelling content can accelerate the learning process dramatically.
            """,
            focusLemmas: ["serendipity", "nuanced", "immersion"]
        )
    }
}
