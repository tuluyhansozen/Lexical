import SwiftUI

struct WordCaptureSheet: View {
    let word: String
    let definition: String

    // Mock data for "ios 26" demo feel
    let transcription = "/ˌsɛrənˈdɪpɪti/"
    let partOfSpeech = "noun"
    let contextSentence = "\"The discovery of penicillin was a stroke of serendipity.\""

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.adaptiveBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag Handle
                Capsule()
                    .fill(Color.adaptiveBorder)
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Common")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .textCase(.uppercase)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.sonPrimary)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())

                            HStack {
                                Text(word.capitalized)
                                    .font(.display(.largeTitle, weight: .bold))
                                    .foregroundStyle(Color.adaptiveText)

                                Spacer()

                                Button {
                                    // Play Sound
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color.sonPrimary)
                                        .padding(12)
                                        .background(Color.sonPrimary.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .accessibilityLabel("Play pronunciation")
                            }

                            Text(transcription)
                                .font(.monospaced(.body)())
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        // Definition
                        VStack(alignment: .leading, spacing: 8) {
                            Text(partOfSpeech)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .italic()
                                .foregroundStyle(Color.sonPrimary)

                            Text(definition)
                                .font(.bodyText)
                                .foregroundStyle(Color.adaptiveText)
                        }

                        // Context Box
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "quote.opening")
                                Text("CONTEXT")
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            
                            Text(contextSentence)
                                .font(.bodyText)
                                .italic()
                                .foregroundStyle(Color.adaptiveText.opacity(0.9))
                        }
                        .padding(20)
                        .background(Color.adaptiveSurfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.adaptiveBorder, lineWidth: 1)
                        )

                        // Synonyms/Antonyms
                        HStack(spacing: 12) {
                            VStack(alignment: .leading) {
                                Text("SYNONYMS")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                Text("Chance, Fluke")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.adaptiveText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.adaptiveSurface.opacity(0.65))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading) {
                                Text("ANTONYMS")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                Text("Misfortune")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.adaptiveText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.adaptiveSurface.opacity(0.65))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100) // Space for button
                }
            }
            
            // Sticky Footer
            VStack {
                Button {
                    // Add to Deck
                } label: {
                    HStack {
                        Image(systemName: "plus.square.on.square")
                        Text("Add to Deck")
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.sonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.sonPrimary.opacity(0.3), radius: 10, x: 0, y: 4)
                }
                .accessibilityLabel("Add to deck")
                .accessibilityHint("Adds this word to your learning queue.")
            }
            .padding(24)
            .background(
                LinearGradient(colors: [
                    Color.adaptiveSurface.opacity(0),
                    Color.adaptiveSurface
                ], startPoint: .top, endPoint: .bottom)
            )
        }
        .background(Color.adaptiveSurface.ignoresSafeArea())
    }
}
