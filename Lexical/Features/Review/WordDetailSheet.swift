import AVFoundation
import SwiftData
import SwiftUI
import LexicalCore

struct WordDetailData: Identifiable, Equatable {
    let lemma: String
    let partOfSpeech: String?
    let ipa: String?
    let definition: String?
    let synonyms: [String]
    let sentences: [String]

    var id: String { lemma }
}

enum WordDetailDataBuilder {
    static func build(for card: ReviewCard, modelContext: ModelContext) -> WordDetailData {
        let normalizedLemma = card.lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lexeme = fetchLexeme(lemma: normalizedLemma, modelContext: modelContext)
        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        let activeUserId = defaults.string(forKey: UserProfile.activeUserDefaultsKey) ?? UserProfile.fallbackLocalUserID
        let discovered = fetchDiscovered(
            lemma: normalizedLemma,
            userId: activeUserId,
            modelContext: modelContext
        )
        let seed = SeedLexemeIndex.lookup(lemma: normalizedLemma)

        let definition = firstNonEmpty(
            card.definition,
            lexeme?.basicMeaning,
            discovered?.definition,
            seed?.definition
        )

        var sentenceSet = Set<String>()
        var sentences: [String] = []

        let discoveredSentence = discovered?.exampleSentences.first
        let seededSentences = seed?.sentences ?? []
        let candidates = [card.contextSentence, lexeme?.sampleSentence, discoveredSentence].compactMap { $0 } + seededSentences

        for candidate in candidates {
            guard let normalized = normalizedSentence(candidate) else { continue }
            if sentenceSet.insert(normalized.lowercased()).inserted {
                sentences.append(normalized)
            }
        }

        let synonyms = sanitizeSynonyms((discovered?.synonyms ?? []) + (seed?.synonyms ?? []))

        return WordDetailData(
            lemma: normalizedLemma,
            partOfSpeech: normalizedPartOfSpeech(firstNonEmpty(lexeme?.partOfSpeech, discovered?.partOfSpeech)),
            ipa: firstNonEmpty(lexeme?.ipa, discovered?.ipa, seed?.ipa),
            definition: definition,
            synonyms: synonyms,
            sentences: sentences
        )
    }

    private static func fetchLexeme(
        lemma: String,
        modelContext: ModelContext
    ) -> LexemeDefinition? {
        let descriptor = FetchDescriptor<LexemeDefinition>(
            predicate: #Predicate { $0.lemma == lemma }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private static func fetchDiscovered(
        lemma: String,
        userId: String,
        modelContext: ModelContext
    ) -> DiscoveredLexeme? {
        let key = DiscoveredLexeme.makeKey(userId: userId, lemma: lemma)
        let descriptor = FetchDescriptor<DiscoveredLexeme>(
            predicate: #Predicate { $0.userLemmaKey == key }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private static func normalizedSentence(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, ContentSafetyService.isSafeText(trimmed) else { return nil }
        return trimmed
    }

    private static func normalizedPartOfSpeech(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }

    private static func sanitizeSynonyms(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(min(raw.count, 8))

        for value in raw {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, ContentSafetyService.isSafeText(normalized) else { continue }
            let key = normalized.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(normalized)
            if result.count >= 8 { break }
        }
        return result
    }
}

enum SeedLexemeIndex {
    struct Snapshot {
        let ipa: String?
        let definition: String?
        let synonyms: [String]
        let sentences: [String]
    }

    private struct Entry: Decodable {
        let lemma: String
        let ipa: String?
        let definition: String?
        let synonym: [String]?
        let sentences: [Sentence]?
    }

    private struct Sentence: Decodable {
        let text: String
    }

    private static let cache = SeedLexemeIndexCache()

    static func lookup(lemma: String) -> Snapshot? {
        cache.lookup(lemma: lemma)
    }

    static func prewarm() {
        cache.startLoadingIfNeeded()
    }

    fileprivate static func loadFromDisk() -> [String: Snapshot] {
        guard let url = seedURL() else { return [:] }
        guard let data = try? Data(contentsOf: url) else { return [:] }
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [:] }

        var map: [String: Snapshot] = [:]
        map.reserveCapacity(entries.count)

        for entry in entries {
            let lemma = entry.lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !lemma.isEmpty else { continue }
            let synonyms = ContentSafetyService.sanitizeTerms(entry.synonym ?? [], maxCount: 8)
            let sentences = ContentSafetyService.sanitizeSentences(
                (entry.sentences ?? []).map(\.text),
                maxCount: 3
            )
            map[lemma] = Snapshot(
                ipa: entry.ipa,
                definition: entry.definition,
                synonyms: synonyms,
                sentences: sentences
            )
        }
        return map
    }

    private static func seedURL() -> URL? {
        if let url = Bundle.main.url(forResource: "seed_data", withExtension: "json", subdirectory: "Seeds") {
            return url
        }
        if let url = Bundle.main.url(forResource: "seed_data", withExtension: "json") {
            return url
        }
        return nil
    }
}

private final class SeedLexemeIndexCache {
    private enum State {
        case idle
        case loading
        case loaded
    }

    private let lock = NSLock()
    private var state: State = .idle
    private var byLemma: [String: SeedLexemeIndex.Snapshot] = [:]

    func startLoadingIfNeeded() {
        let shouldStartLoad: Bool = lock.withLock {
            guard state == .idle else { return false }
            state = .loading
            return true
        }

        guard shouldStartLoad else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let loaded = SeedLexemeIndex.loadFromDisk()
            self?.lock.withLock {
                self?.byLemma = loaded
                self?.state = .loaded
            }
        }
    }

    func lookup(lemma: String) -> SeedLexemeIndex.Snapshot? {
        startLoadingIfNeeded()
        let normalized = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lock.withLock { byLemma[normalized] }
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}

@MainActor
final class PronunciationPlayer: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        synthesizer.speak(utterance)
    }
}

struct WordDetailSheet: View {
    let data: WordDetailData
    var onAddToDeck: (() -> Void)? = nil

    @StateObject private var pronunciationPlayer = PronunciationPlayer()

    private var visibleSentences: [String] {
        Array(data.sentences.prefix(3))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "F5F5F7")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color(hex: "D8DEDC"))
                    .frame(width: 36, height: 5)
                    .padding(.top, 9)
                    .padding(.bottom, 13)

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Word Info")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(0.6)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 2)

                        wordHeaderCard
                        definitionCard
                        examplesCard

                        if !data.synonyms.isEmpty {
                            synonymsCard
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                    .padding(.bottom, onAddToDeck == nil ? 24 : 116)
                }
                .scrollIndicators(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let onAddToDeck {
                addToDeckFooter(action: onAddToDeck)
            }
        }
    }

    private var wordHeaderCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(data.lemma.capitalized)
                        .font(.system(size: 35, weight: .bold))
                        .foregroundStyle(Color(hex: "131615"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text((data.partOfSpeech?.isEmpty == false ? data.partOfSpeech! : "noun"))
                        .font(.system(size: 10, weight: .medium))
                        .italic()
                        .foregroundStyle(Color(hex: "4E7366"))
                        .offset(y: -2)
                }

                Spacer(minLength: 0)

                Button {
                    pronunciationPlayer.speak(data.lemma)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "4E7366"))
                        .frame(width: 26, height: 26)
                        .background(Color(hex: "4E7366").opacity(0.22))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play pronunciation")
            }
            .padding(.horizontal, 21)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .modifier(WordInfoCardStyle())
    }

    private var definitionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("Definition")

            Text(data.definition?.isEmpty == false ? data.definition! : "No definition available")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color(hex: "131615"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 21)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .modifier(WordInfoCardStyle())
    }

    private var examplesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: "6A7C76"))
                sectionHeading("Examples")
            }

            if visibleSentences.isEmpty {
                Text("No sentence examples available")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color(hex: "131615"))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(visibleSentences.enumerated()), id: \.offset) { index, sentence in
                        Text("\(index + 1). ")
                            .font(.system(size: 12, weight: .light))
                            .italic()
                            .foregroundStyle(Color(hex: "131615"))
                        + Text(highlightedSentence(sentence))
                    }
                }
            }
        }
        .padding(.horizontal, 21)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .modifier(WordInfoCardStyle())
    }

    private var synonymsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Synonyms")

            Text(data.synonyms.joined(separator: ", "))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color(hex: "131615"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 21)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .modifier(WordInfoCardStyle())
    }

    private func addToDeckFooter(action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Add to Deck")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color(hex: "021105").opacity(0.72))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.vertical, 11)
        }
        .background(Color(hex: "F5F5F7"))
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(Color(hex: "6A7C76"))
            .opacity(0.9)
    }

    private func highlightedSentence(_ sentence: String) -> AttributedString {
        var value = AttributedString(sentence)
        value.foregroundColor = Color(hex: "131615")
        value.font = .system(size: 12, weight: .light)

        let target = data.lemma.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return value }

        if let range = value.range(of: target, options: .caseInsensitive) {
            value[range].foregroundColor = Color(hex: "4E7366")
            value[range].font = .system(size: 12, weight: .semibold)
        }

        return value
    }
}

private struct WordInfoCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 2.5, x: 0, y: 1)
    }
}
