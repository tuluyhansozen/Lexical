import SwiftUI
import LexicalCore

struct ArticleCardView: View {
    let article: Article
    @State private var selectedWord: HighlightedWord?
    @State private var showReader = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Section (only if exists)
            if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                ZStack(alignment: .topLeading) {
                    // In a real app, use AsyncImage with caching.
                    // Using Color placeholder for now if URL loading fails or for preview speed.
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(height: 192)
                    .clipped()
                    
                    // Category Badge on Image
                    Text(article.category)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.sonMidnight)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.9))
                        .clipShape(Capsule())
                        .padding(16)
                }
            }
            
            // Content Section
            VStack(alignment: .leading, spacing: 16) {
                // Meta info (if no image, category shown here nicely)
                if article.imageUrl == nil {
                     HStack {
                         Text(article.category)
                             .font(.caption)
                             .fontWeight(.bold)
                             .foregroundStyle(article.categoryTextColor)
                             .padding(.horizontal, 12)
                             .padding(.vertical, 6)
                             .background(article.categoryColor)
                             .clipShape(Capsule())
                         
                         Spacer()
                         
                         Button {
                             // Bookmark action
                         } label: {
                             Image(systemName: "bookmark")
                                 .foregroundStyle(.gray)
                         }
                     }
                }
                
                // Metadata Row
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(article.readTime)
                    }
                    Text("•")
                    Text(article.difficulty)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(0.8)
                
                // Title
                Text(article.title)
                    .font(.cardTitle)
                    .foregroundStyle(Color.adaptiveText)
                
                // Content Snippet (Rich Text Simulation)
                // In a real app we'd parse the markdown/HTML.
                // Here we just display text.
                Text(article.content)
                    .font(.bodyText)
                    .foregroundStyle(Color.adaptiveText.opacity(0.9))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                // Interactive Words (Demo Feature)
                if !article.highlightedWords.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(article.highlightedWords) { word in
                                Button {
                                    selectedWord = word
                                } label: {
                                    Text(word.word)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.sonPrimary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.sonPrimary.opacity(0.1))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Color.sonPrimary.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                
                // Continue Reading / Tags
                if article.imageUrl != nil {
                    Divider()
                        .padding(.top, 8)
                    
                    HStack {
                        // User avatars placeholder
                        HStack(spacing: -8) {
                            Circle().fill(Color.sonPrimary.opacity(0.2)).frame(width: 32, height: 32)
                                .overlay(Text("S").font(.caption).bold().foregroundStyle(Color.sonPrimary))
                                .overlay(Circle().stroke(Color.sonCloud, lineWidth: 2))
                            Circle().fill(Color.sonPrimary.opacity(0.2)).frame(width: 32, height: 32)
                                .overlay(Text("E").font(.caption).bold().foregroundStyle(Color.sonPrimary))
                                .overlay(Circle().stroke(Color.sonCloud, lineWidth: 2))
                        }
                        
                        Spacer()
                        
                        Button {
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
                } else {
                    // Unlock Button for text only card (as per design) or Tags
                    if article.category == "music" { // Hack based on design specific
                         Button {
                            // Unlock
                         } label: {
                             HStack {
                                 Image(systemName: "lock")
                                 Text("Unlock Full Article")
                             }
                             .frame(maxWidth: .infinity)
                             .padding()
                             .background(Color.sonMidnight)
                             .foregroundStyle(Color.sonCloud)
                             .clipShape(RoundedRectangle(cornerRadius: 12))
                         }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(article.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color.adaptiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
        .sheet(item: $selectedWord) { word in
            WordCaptureSheet(word: word.word, definition: word.definition)
                .presentationDetents([.fraction(0.75), .large])
                .presentationDragIndicator(.visible)
        }
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
}
