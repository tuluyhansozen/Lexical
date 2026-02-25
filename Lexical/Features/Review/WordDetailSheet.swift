import AVFoundation
import SwiftData
import SwiftUI
import LexicalCore

struct WordDetailData: Identifiable, Equatable {
    let lemma: String
    let partOfSpeech: String?
    let definition: String?
    let synonyms: [String]
    let sentences: [String]

    var id: String { lemma }
}

enum WordDetailDataBuilder {
    @MainActor
    static func build(
        for card: ReviewCard,
        modelContext: ModelContext,
        seedLookup: (String) -> SeedLexemeIndex.Snapshot? = SeedLexemeIndex.lookup
    ) -> WordDetailData {
        let normalizedLemma = card.lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lexeme = fetchLexeme(lemma: normalizedLemma, modelContext: modelContext)
        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        let activeUserId = defaults.string(forKey: UserProfile.activeUserDefaultsKey) ?? UserProfile.fallbackLocalUserID
        let discovered = fetchDiscovered(
            lemma: normalizedLemma,
            userId: activeUserId,
            modelContext: modelContext
        )
        let seed = seedLookup(normalizedLemma)

        let definition = firstNonEmpty(
            card.definition,
            lexeme?.basicMeaning,
            discovered?.definition,
            seed?.definition
        )

        var sentenceSet = Set<String>()
        var sentences: [String] = []

        let discoveredSentences = discovered?.exampleSentences ?? []
        let seededSentences = seed?.sentences ?? []
        let candidates = [card.contextSentence, lexeme?.sampleSentence].compactMap { $0 }
            + discoveredSentences
            + seededSentences

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
            definition: definition,
            synonyms: synonyms,
            sentences: sentences
        )
    }

    @MainActor
    static func buildEnsuringSeedData(
        for card: ReviewCard,
        modelContext: ModelContext,
        seedLookup: @escaping (String) -> SeedLexemeIndex.Snapshot? = SeedLexemeIndex.lookup,
        ensureSeedLoaded: @escaping () async -> Void = SeedLexemeIndex.ensureLoaded
    ) async -> WordDetailData {
        let initial = build(
            for: card,
            modelContext: modelContext,
            seedLookup: seedLookup
        )
        guard shouldHydrateFromSeed(initial) else {
            return initial
        }

        await ensureSeedLoaded()
        return build(
            for: card,
            modelContext: modelContext,
            seedLookup: seedLookup
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
        result.reserveCapacity(raw.count)

        for value in raw {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, ContentSafetyService.isSafeText(normalized) else { continue }
            let key = normalized.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(normalized)
        }
        return result
    }

    private static func shouldHydrateFromSeed(_ data: WordDetailData) -> Bool {
        let definitionMissing = (data.definition?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let synonymsMissing = data.synonyms.isEmpty
        let examplesMissing = data.sentences.isEmpty
        return definitionMissing || synonymsMissing || examplesMissing
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

    static func ensureLoaded() async {
        await cache.ensureLoaded()
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
            let synonyms = ContentSafetyService.sanitizeTerms(entry.synonym ?? [])
            let sentences = ContentSafetyService.sanitizeSentences(
                (entry.sentences ?? []).map(\.text)
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
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "seed_data", withExtension: "json", subdirectory: "Resources/Seeds") {
            return url
        }
        if let url = Bundle.module.url(forResource: "seed_data", withExtension: "json", subdirectory: "Seeds") {
            return url
        }
        if let url = Bundle.module.url(forResource: "seed_data", withExtension: "json") {
            return url
        }
        #endif

        for bundle in candidateBundles() {
            if let url = bundle.url(forResource: "seed_data", withExtension: "json", subdirectory: "Seeds") {
                return url
            }
            if let url = bundle.url(forResource: "seed_data", withExtension: "json", subdirectory: "Resources/Seeds") {
                return url
            }
            if let url = bundle.url(forResource: "seed_data", withExtension: "json") {
                return url
            }
        }

        #if DEBUG
        if let sourceURL = debugSourceSeedURL(),
           FileManager.default.fileExists(atPath: sourceURL.path) {
            return sourceURL
        }
        #endif
        return nil
    }

    private static func candidateBundles() -> [Bundle] {
        var bundles: [Bundle] = [Bundle.main, Bundle(for: SeedLexemeBundleLocator.self)]
        bundles.append(contentsOf: Bundle.allBundles)
        bundles.append(contentsOf: Bundle.allFrameworks)

        var seen = Set<String>()
        var unique: [Bundle] = []
        unique.reserveCapacity(bundles.count)

        for bundle in bundles {
            let key = bundle.bundleURL.path
            if seen.insert(key).inserted {
                unique.append(bundle)
            }
        }
        return unique
    }

    #if DEBUG
    private static func debugSourceSeedURL() -> URL? {
        let fileURL = URL(fileURLWithPath: #filePath)
        let lexicalDir = fileURL
            .deletingLastPathComponent() // Review
            .deletingLastPathComponent() // Features
        return lexicalDir
            .appendingPathComponent("Resources")
            .appendingPathComponent("Seeds")
            .appendingPathComponent("seed_data.json")
    }
    #endif
}

private final class SeedLexemeBundleLocator {}

private final class SeedLexemeIndexCache {
    private enum State {
        case idle
        case loading
        case loaded
    }

    private let lock = NSLock()
    private var state: State = .idle
    private var byLemma: [String: SeedLexemeIndex.Snapshot] = [:]
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func startLoadingIfNeeded() {
        guard transitionToLoadingIfNeeded() else { return }
        loadInBackground()
    }

    func ensureLoaded() async {
        await withCheckedContinuation { continuation in
            var shouldStartLoading = false
            var shouldResumeImmediately = false

            lock.withLock {
                switch state {
                case .loaded:
                    if byLemma.isEmpty {
                        state = .loading
                        waiters.append(continuation)
                        shouldStartLoading = true
                    } else {
                        shouldResumeImmediately = true
                    }
                case .idle:
                    state = .loading
                    waiters.append(continuation)
                    shouldStartLoading = true
                case .loading:
                    waiters.append(continuation)
                }
            }

            if shouldResumeImmediately {
                continuation.resume()
                return
            }

            if shouldStartLoading {
                loadInBackground()
            }
        }
    }

    func lookup(lemma: String) -> SeedLexemeIndex.Snapshot? {
        startLoadingIfNeeded()
        let normalized = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lock.withLock { byLemma[normalized] }
    }

    private func transitionToLoadingIfNeeded() -> Bool {
        lock.withLock {
            switch state {
            case .idle:
                state = .loading
                return true
            case .loaded where byLemma.isEmpty:
                state = .loading
                return true
            default:
                return false
            }
        }
    }

    private func loadInBackground() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let loaded = SeedLexemeIndex.loadFromDisk()
            self?.finishLoading(with: loaded)
        }
    }

    private func finishLoading(with loaded: [String: SeedLexemeIndex.Snapshot]) {
        let continuations = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
            byLemma = loaded
            state = .loaded
            let pending = waiters
            waiters.removeAll(keepingCapacity: false)
            return pending
        }
        continuations.forEach { $0.resume() }
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

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @StateObject private var pronunciationPlayer = PronunciationPlayer()

    private var visibleSentences: [String] {
        data.sentences
    }

    private var visibleSynonyms: [String] {
        data.synonyms
    }

    private var displayLemma: String {
        let trimmed = data.lemma.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return trimmed }
        return first.uppercased() + trimmed.dropFirst()
    }

    private var normalizedPartOfSpeech: String {
        let raw = data.partOfSpeech?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "noun" : raw.lowercased()
    }

    private var scrollBottomPadding: CGFloat {
        onAddToDeck == nil ? 22 : WordInfoSheetSpec.footerReservedSpace
    }

    var body: some View {
        ZStack(alignment: .top) {
            sheetBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(WordInfoSheetSpec.handleColor)
                    .frame(width: 36, height: 5)
                    .padding(.top, 9)
                    .padding(.bottom, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Word Info")
                            .font(.display(.subheadline, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(WordInfoSheetSpec.titleColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 2)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("wordinfo.title")

                        wordHeaderCard
                        definitionCard
                        examplesCard

                        if !visibleSynonyms.isEmpty {
                            synonymsCard
                        }
                    }
                    .padding(.horizontal, WordInfoSheetSpec.horizontalPadding)
                    .padding(.top, 6)
                    .padding(.bottom, scrollBottomPadding)
                }
                .scrollIndicators(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let onAddToDeck {
                fixedFooter(action: onAddToDeck)
            }
        }
    }

    @ViewBuilder
    private var sheetBackground: some View {
        if reduceTransparency {
            WordInfoSheetSpec.background
        } else {
            LinearGradient(
                colors: [
                    WordInfoSheetSpec.background,
                    Color.white.opacity(colorScheme == .dark ? 0.02 : 0.35),
                    WordInfoSheetSpec.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var wordHeaderCard: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(displayLemma)
                    .font(.display(.title2, weight: .bold))
                    .foregroundStyle(WordInfoSheetSpec.bodyColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(normalizedPartOfSpeech)
                    .font(.display(.footnote, weight: .medium))
                    .italic()
                    .foregroundStyle(WordInfoSheetSpec.partOfSpeechColor)
                    .offset(y: -1)
            }

            Spacer(minLength: 0)

            Button {
                pronunciationPlayer.speak(data.lemma)
            } label: {
                ZStack {
                    Circle()
                        .fill(WordInfoSheetSpec.ctaGreen.opacity(0.50))

                    Circle()
                        .fill(Color.black.opacity(0.38))
                        .frame(width: 26, height: 26)

                    Circle()
                        .stroke(Color.white.opacity(0.55), lineWidth: 0.7)
                        .frame(width: 26, height: 26)

                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                }
                .frame(width: 43, height: 43)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play pronunciation")
            .accessibilityHint("Speaks the word aloud.")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(minHeight: 78)
        .modifier(WordInfoCardStyle())
    }

    private var definitionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("Definition")

            Text(data.definition?.isEmpty == false ? data.definition! : "No definition available")
                .font(.bodyText)
                .lineSpacing(2)
                .foregroundStyle(WordInfoSheetSpec.bodyColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(minHeight: 75)
        .modifier(WordInfoCardStyle())
    }

    private var examplesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(WordInfoSheetSpec.headingColor.opacity(0.82))
                sectionHeading("Examples")
            }

            if visibleSentences.isEmpty {
                Text("No sentence examples available.")
                    .font(.bodyText)
                    .foregroundStyle(WordInfoSheetSpec.bodyColor.opacity(0.85))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(visibleSentences.enumerated()), id: \.offset) { index, sentence in
                        Text(highlightedSentence(sentence))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, index == visibleSentences.count - 1 ? 0 : 8)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(minHeight: 146)
        .modifier(WordInfoCardStyle())
    }

    private var synonymsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(WordInfoSheetSpec.headingColor.opacity(0.82))
                sectionHeading("Synonyms")
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(visibleSynonyms, id: \.self) { synonym in
                    Text("• \(synonym)")
                        .font(.bodyText)
                        .foregroundStyle(WordInfoSheetSpec.bodyColor)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(minHeight: 86, alignment: .top)
        .modifier(WordInfoCardStyle())
    }

    private func addToDeckFooter(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "bookmark")
                    .font(.display(.headline, weight: .semibold))
                Text("Add to Deck")
                    .font(.display(.headline, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: 281)
            .frame(height: 46)
            .background(addToDeckBackground)
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.34), lineWidth: 1)
            )
            .clipShape(Capsule())
            .shadow(color: WordInfoSheetSpec.ctaGreen.opacity(0.34), radius: 12, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add to deck")
        .accessibilityHint("Adds this word to your learning queue.")
        .accessibilityIdentifier("wordinfo.addToDeckButton")
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func fixedFooter(action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color.clear,
                    WordInfoSheetSpec.footerBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 18)
            .allowsHitTesting(false)

            addToDeckFooter(action: action)
                .padding(.horizontal, WordInfoSheetSpec.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(WordInfoSheetSpec.footerBackground.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1)
        }
    }

    private var addToDeckBackground: some View {
        ZStack {
            Capsule()
                .fill(WordInfoSheetSpec.ctaGreen)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            WordInfoSheetSpec.ctaGreen.opacity(0.85),
                            WordInfoSheetSpec.ctaGreen,
                            WordInfoSheetSpec.ctaGreen.opacity(0.84)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Capsule()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "1E4B14").opacity(0.72),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 160
                    )
                )
                .blur(radius: 5)
        }
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.display(.subheadline, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(WordInfoSheetSpec.headingColor.opacity(0.80))
    }

    private func highlightedSentence(_ sentence: String) -> AttributedString {
        var value = AttributedString(sentence)
        value.foregroundColor = WordInfoSheetSpec.bodyColor
        value.font = .serif(.body, weight: .regular).italic()

        let target = data.lemma.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return value }

        if let range = value.range(of: target, options: .caseInsensitive) {
            value[range].foregroundColor = .black
            value[range].font = .serif(.body, weight: .semibold)
        }

        return value
    }
}

enum WordInfoSheetPresentation {
    static let minimumFraction: CGFloat = 0.60
    static let maximumFraction: CGFloat = 0.94
    private static let comfortPaddingFraction: CGFloat = 0.04
    private static let primaryActionPaddingFraction: CGFloat = 0.10

    static func detents(
        for data: WordDetailData,
        includesPrimaryAction: Bool = false
    ) -> Set<PresentationDetent> {
        [.fraction(initialFraction(for: data, includesPrimaryAction: includesPrimaryAction))]
    }

    static func initialFraction(
        for data: WordDetailData,
        includesPrimaryAction: Bool = false
    ) -> CGFloat {
        let definitionLines = estimatedLineCount(in: data.definition ?? "", charsPerLine: 54, minimum: 1)
        let exampleLines = max(
            1,
            data.sentences.reduce(0) { partial, sentence in
                partial + estimatedLineCount(in: sentence, charsPerLine: 50, minimum: 1)
            }
        )
        let synonymLines = data.synonyms.reduce(0) { partial, synonym in
            partial + estimatedLineCount(in: synonym, charsPerLine: 26, minimum: 1)
        }

        let rawFraction =
            minimumFraction
            + CGFloat(definitionLines) * 0.011
            + CGFloat(min(exampleLines, 18)) * 0.010
            + CGFloat(min(synonymLines, 14)) * 0.008
            + (data.synonyms.isEmpty ? 0 : 0.028)
            + (includesPrimaryAction ? primaryActionPaddingFraction : 0)
            + comfortPaddingFraction

        return max(minimumFraction, min(maximumFraction, rawFraction))
    }

    private static func estimatedLineCount(in text: String, charsPerLine: Int, minimum: Int) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return minimum }
        let width = max(charsPerLine, 1)
        let count = (trimmed.count + width - 1) / width
        return max(minimum, count)
    }
}

private enum WordInfoSheetSpec {
    static let horizontalPadding: CGFloat = 24
    static let footerReservedSpace: CGFloat = 108
    static let cardCornerRadius: CGFloat = 14
    static let cardBorderWidth: CGFloat = 0.68

    static let background = Color(hex: "F5F5F7")
    static let footerBackground = Color.white
    static let handleColor = Color(hex: "D8DEDC")
    static let titleColor = Color.black
    static let headingColor = Color.black
    static let bodyColor = Color(hex: "131615")
    static let partOfSpeechColor = Color(hex: "4E7366")
    static let ctaGreen = Color(hex: "233F18")
    static let cardFill = Color.white.opacity(0.60)
    static let cardBorder = Color.white.opacity(0.50)
    static let cardShadow = Color.black.opacity(0.10)
}

private struct WordInfoCardStyle: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: WordInfoSheetSpec.cardCornerRadius, style: .continuous)
                        .fill(WordInfoSheetSpec.cardFill)

                    if !reduceTransparency {
                        RoundedRectangle(cornerRadius: WordInfoSheetSpec.cardCornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.22)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: WordInfoSheetSpec.cardCornerRadius, style: .continuous)
                    .stroke(WordInfoSheetSpec.cardBorder, lineWidth: WordInfoSheetSpec.cardBorderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: WordInfoSheetSpec.cardCornerRadius, style: .continuous))
            .shadow(color: WordInfoSheetSpec.cardShadow, radius: 3, x: 0, y: 1)
    }
}

#Preview("WordDetailSheet - Canvas") {
    WordDetailSheet(
        data: WordDetailData(
            lemma: "serendipity",
            partOfSpeech: "noun",
            definition: "The occurrence of events by chance in a happy way.",
            synonyms: ["fortune", "luck", "chance", "fluke"],
            sentences: [
                "The discovery of penicillin was a stroke of serendipity.",
                "Finding that cafe was pure serendipity.",
                "Life is full of happy serendipity."
            ]
        ),
        onAddToDeck: {}
    )
}
