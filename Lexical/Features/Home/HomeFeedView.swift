import SwiftUI

struct HomeFeedView: View {
    // Sample Data
    let articles = Article.samples
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.adaptiveBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Spacer for fixed header
                    Color.clear.frame(height: 140) 
                    
                    VStack(spacing: 24) {
                        ForEach(articles) { article in
                            ArticleCardView(article: article)
                        }
                        
                        // Loading Indicator
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 20)
                        
                        // Bottom spacer for Tab Bar
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .scrollIndicators(.hidden)
            
            // Sticky Header
            VStack(spacing: 0) {
                // Fake Status Bar Background (optional, usually system handles this)
                Color.clear.frame(height: 44) // approximate top safe area
                
                // App Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("OCT 24, THURSDAY")
                            .font(.caption)
                            .fontWeight(.bold)
                            .tracking(1)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Profile Button
                        Button {
                            // Profile Action
                        } label: {
                            Image(systemName: "person.circle")
                                .font(.system(size: 24))
                                .padding(8)
                                .background(Color.adaptiveSurface)
                                .clipShape(Circle())
                                .foregroundStyle(Color.sonPrimary)
                                .overlay(
                                    Circle().stroke(Color.gray.opacity(0.1), lineWidth: 1)
                                )
                        }
                    }
                    
                    Text("Immersive Reader")
                        .font(.articleTitle) // Using our custom font extension
                        .foregroundStyle(Color.adaptiveText)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .background(
                    Color.adaptiveBackground
                        .opacity(0.95)
                        .blur(radius: 5)
                )
                .overlay(alignment: .bottom) {
                    Divider().opacity(0.5)
                }
            }
        }
    }
}
