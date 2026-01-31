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
    @Environment(\.dismiss) var dismiss
    @State private var isFlipped = false
    
    var body: some View {
        ZStack {
            // Background
            Color.adaptiveBackground
                .ignoresSafeArea()
            
            if manager.isSessionComplete {
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.sonPrimary)
                    
                    Text("Session Complete!")
                        .font(.display(size: 32, weight: .bold))
                        .foregroundStyle(Color.adaptiveText)
                    
                    Text("You've reviewed all due words.")
                        .font(.bodyText)
                        .foregroundStyle(.secondary)
                    
                    Button("Home") {
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
                    ProgressBar(value: Double(manager.queue.count), total: 10 + Double(manager.queue.count))
                        .padding()
                    
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
                        HStack(spacing: 12) {
                            GradeButton(title: "Again", color: .red) { submit(1) }
                            GradeButton(title: "Hard", color: .orange) { submit(2) }
                            GradeButton(title: "Good", color: .blue) { submit(3) }
                            GradeButton(title: "Easy", color: .green) { submit(4) }
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
        .navigationBarTitleDisplayMode(.inline)
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
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Material.regular)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct ProgressBar: View {
    let value: Double
    let total: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)
                
                Capsule()
                    .fill(Color.sonPrimary)
                    .frame(width: max(0, geometry.size.width * 0.5), height: 6) // Placeholder logic
            }
        }
        .frame(height: 6)
    }
}
