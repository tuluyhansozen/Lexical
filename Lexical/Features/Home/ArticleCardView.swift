import SwiftUI
import SwiftData
import LexicalCore

struct ArticleCardView: View {
    let article: GeneratedArticle
    @Environment(\.modelContext) private var modelContext
    @State private var showReader = false
    private let articleStore = ArticleStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text(article.category.uppercased())
                    .font(.system(size: 10, weight: .regular))
                    .tracking(0.62)
                    .foregroundStyle(Color(hex: "4A5565"))

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .regular))
                    Text("3 min read")
                        .font(.system(size: 10, weight: .regular))
                }
                .foregroundStyle(Color(hex: "4A5565"))
            }
            .padding(.top, 14)

            Text(article.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: "0A0A0A"))
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .padding(.top, 8)

            Text(highlightedExcerpt)
                .font(.system(size: 14, weight: .regular))
                .lineSpacing(6)
                .foregroundStyle(Color(hex: "364153"))
                .padding(.top, 12)
                .lineLimit(4)

            Spacer(minLength: 14)

            Button {
                recordArticleExposure()
                showReader = true
            } label: {
                Text("Continue Reading \u{2192}")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "021105").opacity(0.71))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 25)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 253, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.22), radius: 4, x: 0, y: 4)
        .fullScreenCover(isPresented: $showReader) {
            NavigationStack {
                ReaderView(title: article.title, content: article.content)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") {
                                showReader = false
                            }
                        }
                    }
            }
        }
    }

    private var highlightedExcerpt: AttributedString {
        var value = AttributedString(snippet)
        let palette: [Color] = [
            Color(hex: "FFC6F3"),
            Color(red: 182.0 / 255.0, green: 1.0, blue: 148.0 / 255.0).opacity(0.76),
            Color(red: 1.0, green: 179.0 / 255.0, blue: 98.0 / 255.0).opacity(0.64),
            Color(red: 121.0 / 255.0, green: 177.0 / 255.0, blue: 1.0).opacity(0.78)
        ]

        for (index, word) in article.targetWords.prefix(palette.count).enumerated() {
            highlight(word: sanitizedToken(word), color: palette[index], in: &value)
        }

        return value
    }

    private var snippet: String {
        let compact = article.content
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let maxLength = 140
        guard compact.count > maxLength else { return compact }

        let limitIndex = compact.index(compact.startIndex, offsetBy: maxLength)
        let prefix = compact[..<limitIndex]
        if let split = prefix.lastIndex(of: " ") {
            return String(prefix[..<split])
        }
        return String(prefix)
    }

    private func highlight(word: String, color: Color, in text: inout AttributedString) {
        guard !word.isEmpty else { return }
        guard let range = text.range(of: word, options: .caseInsensitive) else { return }
        text[range].backgroundColor = color
    }

    private func sanitizedToken(_ raw: String) -> String {
        raw.lowercased()
            .trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }

    @MainActor
    private func recordArticleExposure() {
        Task {
            await articleStore.markViewed(article.id)
        }

        let uniqueLemmas = Array(
            Set(
                article.targetWords
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
        )

        guard !uniqueLemmas.isEmpty else { return }

        for lemma in uniqueLemmas {
            do {
                _ = try ReviewWriteCoordinator.submitImplicitExposure(
                    lemma: lemma,
                    modelContext: modelContext
                )
            } catch {
                print("ArticleCardView: failed implicit exposure write for '\(lemma)': \(error)")
            }
        }
    }
}
