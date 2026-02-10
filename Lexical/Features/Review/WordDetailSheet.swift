import AVFoundation
import SwiftData
import SwiftUI
import LexicalCore

struct WordDetailData: Identifiable, Equatable {
    let lemma: String
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
        let seed = SeedLexemeIndex.lookup(lemma: normalizedLemma)

        let definition = firstNonEmpty(
            card.definition,
            lexeme?.basicMeaning,
            seed?.definition
        )

        var sentenceSet = Set<String>()
        var sentences: [String] = []

        let candidates = [
            card.contextSentence,
            lexeme?.sampleSentence
        ] + (seed?.sentences ?? [])

        for candidate in candidates {
            guard let normalized = normalizedSentence(candidate) else { continue }
            if sentenceSet.insert(normalized.lowercased()).inserted {
                sentences.append(normalized)
            }
        }

        let synonyms = sanitizeSynonyms(seed?.synonyms ?? [])

        return WordDetailData(
            lemma: normalizedLemma,
            ipa: firstNonEmpty(lexeme?.ipa, seed?.ipa),
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
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func sanitizeSynonyms(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(min(raw.count, 8))

        for value in raw {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            let key = normalized.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(normalized)
            if result.count >= 8 { break }
        }
        return result
    }
}

private struct SeedLexemeIndex {
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

    private static let byLemma: [String: Snapshot] = load()

    static func lookup(lemma: String) -> Snapshot? {
        byLemma[lemma]
    }

    private static func load() -> [String: Snapshot] {
        guard let url = seedURL() else { return [:] }
        guard let data = try? Data(contentsOf: url) else { return [:] }
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [:] }

        var map: [String: Snapshot] = [:]
        map.reserveCapacity(entries.count)

        for entry in entries {
            let lemma = entry.lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !lemma.isEmpty else { continue }
            let sentences = (entry.sentences ?? []).map(\.text)
            map[lemma] = Snapshot(
                ipa: entry.ipa,
                definition: entry.definition,
                synonyms: entry.synonym ?? [],
                sentences: sentences
            )
        }
        return map
    }

    private static func seedURL() -> URL? {
        // Try Seeds subdirectory first (main app bundle layout)
        if let url = Bundle.main.url(forResource: "seed_data", withExtension: "json", subdirectory: "Seeds") {
            return url
        }
        // Fallback to root of bundle
        if let url = Bundle.main.url(forResource: "seed_data", withExtension: "json") {
            return url
        }
        return nil
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

    @Environment(\.dismiss) private var dismiss
    @StateObject private var pronunciationPlayer = PronunciationPlayer()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    definitionSection
                    sentencesSection
                    synonymsSection
                    addToDeckSection
                }
                .padding(20)
            }
            .background(Color.adaptiveBackground.ignoresSafeArea())
            .navigationTitle("Word Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(data.lemma.capitalized)
                    .font(.display(size: 30, weight: .bold))
                    .foregroundStyle(Color.adaptiveText)

                Spacer()

                Button {
                    pronunciationPlayer.speak(data.lemma)
                } label: {
                    Label("Pronounce", systemImage: "speaker.wave.2.fill")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundStyle(Color.sonPrimary)
                        .padding(10)
                        .background(Color.sonPrimary.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Play pronunciation")
            }

            if let ipa = data.ipa, !ipa.isEmpty {
                Text("IPA: \(ipa)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("IPA unavailable")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color.adaptiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var definitionSection: some View {
        detailCard(title: "Definition") {
            if let definition = data.definition, !definition.isEmpty {
                Text(definition)
                    .font(.body)
                    .foregroundStyle(Color.adaptiveText)
            } else {
                Text("No definition available.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sentencesSection: some View {
        detailCard(title: "Examples") {
            if data.sentences.isEmpty {
                Text("No sentence examples available.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(data.sentences.enumerated()), id: \.offset) { index, sentence in
                        Text("\(index + 1). \(sentence)")
                            .font(.body)
                            .foregroundStyle(Color.adaptiveText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var addToDeckSection: some View {
        if let onAddToDeck {
            Button(action: onAddToDeck) {
                Label("Add to Deck", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.sonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var synonymsSection: some View {
        detailCard(title: "Synonyms") {
            if data.synonyms.isEmpty {
                Text("No synonyms available.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                    ForEach(data.synonyms, id: \.self) { synonym in
                        Text(synonym)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.sonPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.sonPrimary.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func detailCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.adaptiveText)
            content()
        }
        .padding(16)
        .background(Color.adaptiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
