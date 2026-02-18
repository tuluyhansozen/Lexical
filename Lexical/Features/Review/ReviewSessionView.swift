import SwiftUI
import SwiftData
import LexicalCore

/// Main container for the study session
struct ReviewSessionView: View {
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        // We use a wrapper to initialize the StateObject with the modelContext
        SessionContainer(modelContext: modelContext)
    }
}

/// Wrapper to initialize SessionManager with context
struct SessionContainer: View {
    @StateObject private var manager: SessionManager
    
    init(modelContext: ModelContext) {
        // Initialize StateObject with dependency
        _manager = StateObject(wrappedValue: SessionManager(modelContext: modelContext))
    }
    
    var body: some View {
        SessionContent(manager: manager)
    }
}

struct SessionContent: View {
    @ObservedObject var manager: SessionManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var isFlipped = false
    @State private var infoData: WordDetailData?
    
    var body: some View {
        ZStack {
            // Background
            Color.adaptiveBackground
                .ignoresSafeArea()
            
            if manager.isSessionComplete {
                VStack(spacing: 24) {
                    Image(systemName: manager.hadDueCardsAtSessionStart ? "checkmark.seal.fill" : "clock.badge.exclamationmark")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.sonPrimary)
                    
                    Text(manager.hadDueCardsAtSessionStart ? "Session Complete!" : "No Cards Due")
                        .font(.display(.largeTitle, weight: .bold))
                        .foregroundStyle(Color.adaptiveText)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text(manager.hadDueCardsAtSessionStart ? "You've reviewed all due words." : "Your due queue is empty right now. Come back later or read a new article.")
                        .font(.bodyText)
                        .foregroundStyle(Color.adaptiveTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Button(manager.hadDueCardsAtSessionStart ? "Home" : "Go to Reading") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.sonPrimary)
                    .clipShape(Capsule())
                }
            } else if let card = manager.currentCard {
                VStack {
                    // Progress Bar
                    ProgressBar(
                        value: Double(manager.completedCount),
                        total: Double(max(manager.initialQueueCount, 1))
                    )
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    
                    Spacer()
                    
                    FlashcardView(
                        item: card,
                        onFlip: { /* Sound effect? */ },
                        isFlipped: $isFlipped
                    )
                    .id(card.lemma) // Force transition for new card
                    .transition(AnyTransition.asymmetric(insertion: AnyTransition.move(edge: .trailing), removal: AnyTransition.move(edge: .leading)))
                    
                    Spacer()
                    
                    // Grading Controls
                    if isFlipped {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Button {
                                    infoData = WordDetailDataBuilder.build(for: card, modelContext: modelContext)
                                } label: {
                                    Label("Info", systemImage: "info.circle")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.sonPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.sonPrimary.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .accessibilityLabel("Word info")
                                .accessibilityHint("Shows definition, synonyms, and examples.")

                                Button(role: .destructive) {
                                    withAnimation(.spring()) {
                                        manager.removeCurrentCardFromDeck()
                                        isFlipped = false
                                    }
                                } label: {
                                    Label("Remove from Deck", systemImage: "trash")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.red.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(manager.isSubmittingGrade)
                                .accessibilityHint("Removes this word from your learning deck.")
                            }

                            HStack(spacing: 12) {
                                GradeButton(title: "Again", color: .red) { submit(1) }
                                GradeButton(title: "Hard", color: .orange) { submit(2) }
                                GradeButton(title: "Good", color: .blue) { submit(3) }
                                GradeButton(title: "Easy", color: .green) { submit(4) }
                            }
                            .disabled(manager.isSubmittingGrade)
                        }
                        .padding(.bottom, 30)
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        // Placeholder to keep spacing
                        Color.clear.frame(height: 60).padding(.bottom, 30)
                    }
                }
            } else {
                // Loading or Empty (should be handled by isSessionComplete)
                ProgressView()
            }
        }
        .onAppear {
            manager.startSession()
        }
        .sheet(item: $infoData) { detail in
            WordDetailSheet(data: detail)
                .presentationDetents([.medium, .large])
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private func submit(_ grade: Int) {
        withAnimation(.spring()) {
            manager.submitGrade(grade)
            isFlipped = false // Reset for next card
        }
    }
}

struct GradeButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Material.regular)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        }
        .accessibilityLabel("Grade \(title)")
    }
}

struct ProgressBar: View {
    let value: Double
    let total: Double
    
    var body: some View {
        GeometryReader { geometry in
            let progress = total > 0 ? min(max(value / total, 0), 1) : 0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)
                
                Capsule()
                    .fill(Color.sonPrimary)
                    .frame(width: max(0, geometry.size.width * progress), height: 6)
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityLabel("Session progress")
        .accessibilityValue("\(Int(value)) of \(Int(total)) cards reviewed")
    }
}
