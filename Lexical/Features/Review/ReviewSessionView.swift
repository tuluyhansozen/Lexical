import SwiftUI

struct ReviewSessionView: View {
    @State private var isAnswerRevealed = false
    @State private var progress: Double = 0.3
    @Environment(\.dismiss) var dismiss
    
    // Sample Data
    let sentenceStart = "The diplomat's"
    let hiddenWord = "placid"
    let sentenceEnd = "demeanor calmed the tense negotiations immediately."
    let hint = "(adj.) — free from disturbance"
    
    var body: some View {
        ZStack {
            Color.sonMidnight.ignoresSafeArea()
            
            // Content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.sonCloud.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("RECALL SESSION")
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(2)
                        .foregroundStyle(Color.sonPrimary.opacity(0.8))
                    
                    Spacer()
                    
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Progress
                VStack(spacing: 8) {
                    HStack(alignment: .bottom) {
                        Text("Progress")
                            .font(.caption)
                            .fontWeight(.bold)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.sonCloud.opacity(0.5))
                        
                        Spacer()
                        
                        Text("15")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.sonCloud)
                        + Text(" / 50")
                            .font(.caption)
                            .foregroundStyle(Color.sonCloud.opacity(0.5))
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1))
                            Capsule().fill(Color.sonPrimary)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(24)
                
                Spacer()
                
                // Question Card
                VStack(spacing: 32) {
                    Text(sentenceStart + " ")
                        .font(.custom("New York", size: 30)) // Fallback to serif if New York not avail
                        .foregroundStyle(Color.sonCloud)
                    + Text(isAnswerRevealed ? hiddenWord : "[ _____ ]")
                        .font(.custom("New York", size: 30).bold())
                        .foregroundStyle(isAnswerRevealed ? Color.sonPrimary : Color.sonCloud)
                    + Text(" " + sentenceEnd)
                        .font(.custom("New York", size: 30))
                        .foregroundStyle(Color.sonCloud)
                    
                    // Hint
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.sonPrimary)
                        Text(hint)
                            .font(.subheadline)
                            .italic()
                            .foregroundStyle(Color.sonCloud.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                    .opacity(isAnswerRevealed ? 0 : 1) // Hide hint when revealed? Or keep it. Design shows it.
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Actions
                VStack(spacing: 20) {
                    if isAnswerRevealed {
                        // Rating Buttons
                        HStack(spacing: 12) {
                            RatingButton(color: .red, label: "Forgot", icon: "xmark")
                            RatingButton(color: .yellow, label: "Hard", icon: "exclamationmark")
                            RatingButton(color: .green, label: "Easy", icon: "checkmark")
                        }
                    } else {
                        // Reveal Button
                        Button {
                            withAnimation {
                                isAnswerRevealed = true
                            }
                        } label: {
                            HStack {
                                Text("Reveal Answer")
                                Image(systemName: "eye.fill")
                            }
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.sonCloud)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.sonPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                            .contentShape(Rectangle())
                        }
                    }
                    
                    // Bottom Controls
                    HStack {
                        Button {
                            // Flag
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "flag")
                                Text("FLAG")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(Color.sonCloud.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        Button {
                            // Edit
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.pencil")
                                Text("EDIT")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(Color.sonCloud.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .padding(24)
            }
        }
    }
}

struct RatingButton: View {
    let color: Color
    let label: String
    let icon: String
    
    var body: some View {
        Button {
            // Rate Action
        } label: {
            VStack {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(color)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
