import SwiftUI
import SwiftData
import LexicalCore

struct ArticleCardView: View {
    // We now support GeneratedArticle directly
    let article: GeneratedArticle
    @Environment(\.modelContext) private var modelContext
    @State private var showReader = false
    private let articleStore = ArticleStore()
    
    // Derived for UI compatibility
    private var categoryColor: Color {
        switch article.category.lowercased() {
        case "technology": return .blue.opacity(0.1)
        case "science": return .green.opacity(0.1)
        default: return .orange.opacity(0.1)
        }
    }
    
    private var categoryTextColor: Color {
        switch article.category.lowercased() {
        case "technology": return .blue
        case "science": return .green
        default: return .orange
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // Content Section
            VStack(alignment: .leading, spacing: 16) {
                // Meta info
                 HStack {
                     Text(article.category.uppercased())
                         .font(.caption)
                         .fontWeight(.bold)
                         .foregroundStyle(categoryTextColor)
                         .padding(.horizontal, 12)
                         .padding(.vertical, 6)
                         .background(categoryColor)
                         .clipShape(Capsule())
                     
                     Spacer()
                     
                     Button {
                         // Bookmark action
                     } label: {
                         Image(systemName: "bookmark")
                             .foregroundStyle(.gray)
                     }
                 }
                
                // Metadata Row
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("3 min read") // Estimated
                    }
                    Text("•")
                    Text("Generated")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(0.8)
                
                // Title
                Text(article.title)
                    .font(.cardTitle) // Using our custom font extension via DesignSystem
                    .foregroundStyle(Color.adaptiveText)
                
                // Content Snippet
                Text(article.content)
                    .font(.bodyText)
                    .foregroundStyle(Color.adaptiveText.opacity(0.9))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                // Target Words (Interactive)
                if !article.targetWords.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(article.targetWords, id: \.self) { word in
                                Text(word)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.1))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.green.opacity(0.3), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                
                Divider()
                    .padding(.top, 8)
                
                HStack {
                    Spacer()
                    
                    Button {
                        recordArticleExposure()
                        showReader = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Continue Reading")
                            Image(systemName: "arrow.forward")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.sonPrimary)
                    }
                }
            }
            .padding(24)
        }
        .background(Color.adaptiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
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
