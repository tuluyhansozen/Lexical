import SwiftUI
import SwiftData
import LexicalCore

/// Main reading view with vocabulary highlighting and capture
struct ReaderView: View {
    let title: String
    let content: String
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var tokenHighlights: [TokenHighlight] = []
    @State private var lemmaStates: [String: VocabularyState] = [:]
    @State private var isLoading = true
    @State private var selectedWord: SelectedWord?
    @State private var showCaptureSheet = false
    
    private let tokenizationActor = TokenizationActor()
    
    struct SelectedWord: Identifiable {
        let id = UUID()
        let word: String
        let lemma: String
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
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Article Header
                        Text(title)
                            .font(.display(size: 28, weight: .bold))
                            .foregroundStyle(Color.adaptiveText)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        
                        // Stats Bar
                        HStack(spacing: 16) {
                            StatBadge(
                                icon: "book.fill",
                                value: "\(countWords()) words",
                                color: .blue
                            )
                            StatBadge(
                                icon: "star.fill",
                                value: "\(countNewWords()) new",
                                color: .orange
                            )
                            StatBadge(
                                icon: "graduationcap.fill",
                                value: "\(countLearningWords()) learning",
                                color: .green
                            )
                        }
                        .padding(.horizontal, 20)
                        
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
            }
        }
        .sheet(isPresented: $showCaptureSheet) {
            if let selected = selectedWord {
                WordCaptureSheetWrapper(
                    word: selected.word,
                    lemma: selected.lemma,
                    sentence: selected.sentence,
                    onCapture: { handleCapture(lemma: selected.lemma, sentence: selected.sentence) }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
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
        let states = resolver.resolveStates(for: lemmas)
        lemmaStates = states
        
        // Map tokens to highlights using their ORIGINAL RANGES
        // This fixes the lemma-to-surface mismatch bug!
        tokenHighlights = tokens.compactMap { token in
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
                sentence: sentence,
                range: range
            )
            showCaptureSheet = true
        }
    }
    
    private func handleCapture(lemma: String, sentence: String) {
        // Resolve Root
        var rootObj: MorphologicalRoot? = nil
        if let rootStr = EtymologyService.resolveRoot(for: lemma) {
            // Check if root already exists
            let descriptor = FetchDescriptor<MorphologicalRoot>(predicate: #Predicate<MorphologicalRoot> { $0.root == rootStr })
            if let existing = try? modelContext.fetch(descriptor).first {
                rootObj = existing
            } else {
                // Create new root (placeholder metadata for now)
                let newRoot = MorphologicalRoot(
                    root: rootStr,
                    meaning: "Root of \(lemma)", // Placeholder
                    origin: "Unknown"
                )
                modelContext.insert(newRoot)
                rootObj = newRoot
            }
        }
    
        // Create new VocabularyItem
        let item = VocabularyItem(
            lemma: lemma,
            contextSentence: sentence,
            root: rootObj
        )
        modelContext.insert(item)
        
        // Update local state
        lemmaStates[lemma] = .learning
        
        // Update highlights for this lemma
        tokenHighlights = tokenHighlights.map { highlight in
            // We need to re-analyze to update the highlights properly
            highlight
        }
        
        // Dismiss sheet
        showCaptureSheet = false
    }
    
    // MARK: - Stats
    
    private func countWords() -> Int {
        content.split(separator: " ").count
    }
    
    private func countNewWords() -> Int {
        lemmaStates.values.filter { $0 == .new }.count
    }
    
    private func countLearningWords() -> Int {
        lemmaStates.values.filter { $0 == .learning }.count
    }
}

// MARK: - Supporting Views

struct StatBadge: View {
    let icon: String
    let value: String
    let color: Color
    
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
        .clipShape(Capsule())
    }
}

/// Wrapper to integrate existing WordCaptureSheet with capture callback
struct WordCaptureSheetWrapper: View {
    let word: String
    let lemma: String
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
            """
        )
    }
}
