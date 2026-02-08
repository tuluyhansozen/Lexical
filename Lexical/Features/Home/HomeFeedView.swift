import SwiftUI
import SwiftData
import LexicalCore

struct HomeFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ArticlesViewModel()
    @Query private var interestProfiles: [InterestProfile]
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.adaptiveBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Spacer for fixed header
                    Color.clear.frame(height: 140) 
                    
                    VStack(spacing: 24) {
                        
                        // Generation Trigger (Temporary for Debugging/Demo)
                        if viewModel.articles.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(viewModel.articles) { article in
                                ArticleCardView(article: article)
                            }
                        }
                        
                        // Loading Indicator
                        if viewModel.isGenerating {
                            HStack {
                                Spacer()
                                ProgressView("Generating personalized content...")
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        } else {
                            // "Load More" / Generate trigger at bottom
                            Button {
                                triggerGeneration()
                            } label: {
                                Text("Generate New Article")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.sonPrimary)
                                    .padding()
                                    .background(Color.sonPrimary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .padding(.vertical, 20)
                        }
                        
                        // Bottom spacer for Tab Bar
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .scrollIndicators(.hidden)
            .refreshable {
                viewModel.loadArticles()
            }
            
            // Sticky Header
            VStack(spacing: 0) {
                // Fake Status Bar Background (optional, usually system handles this)
                Color.clear.frame(height: 44) // approximate top safe area
                
                // App Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(Date().formatted(date: .abbreviated, time: .omitted).uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .tracking(1)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Profile Button (Navigates to Settings tab via TabView, but here just visual)
                        NavigationLink(destination: SettingsView()) {
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
        .onAppear {
            viewModel.loadArticles()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Articles Yet")
                .font(.title3)
                .fontWeight(.bold)
            Text("Complete your interest profile and generate your first personalized article.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Button {
                triggerGeneration()
            } label: {
                Text("Generate First Article")
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.sonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
        }
        .padding(40)
        .background(Color.adaptiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private func triggerGeneration() {
        // Create a temporary profile if one doesn't exist (though SettingsView ensures it does)
        let profile = interestProfiles.first ?? InterestProfile(selectedTags: ["Technology"])

        let targetService = LexicalTargetingService()
        let targets = targetService.articleTargets(modelContext: modelContext, maxCount: 6)
        let fallbackTargets = ["context", "insight", "derive"]

        viewModel.generateNewArticle(
            profile: profile,
            targetWords: targets.isEmpty ? fallbackTargets : targets
        )
    }
}
