import SwiftUI
import UserNotifications
import LexicalCore
#if canImport(StoreKit)
import StoreKit
#endif

struct OnboardingWelcomeStepView: View {
    @Binding var userName: String
    @FocusState private var isNameFieldFocused: Bool

    private var hasName: Bool {
        !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        OnboardingStepContainer {
            VStack(spacing: 0) {
                VStack(alignment: .center, spacing: 0) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(hex: OnboardingFlowModel.accentHex))
                        .frame(width: 72, height: 72)
                        .overlay {
                            Image(systemName: "book.closed")
                                .font(.system(size: 34, weight: .regular))
                                .foregroundStyle(.white)
                        }
                        .padding(.bottom, 40)

                    Text("Master fluency with\nretrieval-first learning.")
                        .font(.display(size: 28, weight: .regular))
                        .foregroundStyle(Color(hex: "0A0A0A"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .accessibilityIdentifier("onboarding.welcomeHeadline")

                    Text("Join the daily loop that combines Reading, Review, and Contextual Analysis.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color(hex: "525252"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.top, 12)
                }

                HStack(spacing: 8) {
                    OnboardingFeaturePill(icon: "book", label: "Read")
                    OnboardingFeaturePill(icon: "brain", label: "Review")
                    OnboardingFeaturePill(icon: "chart.bar", label: "Analyze")
                }
                .padding(.top, 28)

                VStack(alignment: .leading, spacing: 0) {
                    Text("What should we call you?")
                        .font(.system(size: hasName || isNameFieldFocused ? 10 : 15, weight: .medium))
                        .foregroundStyle(hasName || isNameFieldFocused ? Color(hex: OnboardingFlowModel.accentHex) : Color(hex: "8E8E93"))
                        .offset(y: hasName || isNameFieldFocused ? 14 : 31)
                        .padding(.leading, 16)
                        .animation(.easeInOut(duration: 0.16), value: hasName)
                        .animation(.easeInOut(duration: 0.16), value: isNameFieldFocused)

                    TextField("", text: $userName)
                        .focused($isNameFieldFocused)
                        .lexicalWordsAutocapitalization()
                        .padding(.horizontal, 16)
                        .padding(.top, 22)
                        .padding(.bottom, 10)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color(hex: "0A0A0A"))
                        .background(Color.white.opacity(0.64))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    isNameFieldFocused ? Color(hex: OnboardingFlowModel.accentHex) : Color.white.opacity(0.52),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
                        .accessibilityIdentifier("onboarding.nameField")
                }
                .padding(.top, 36)

                Text("Plan: Standard (1 article/week). Upgrade later for unlimited access.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .padding(.horizontal, 8)

                Spacer(minLength: 0)
            }
            .padding(.top, 48)
        }
    }
}

struct OnboardingFSRSStepView: View {
    @Binding var hasPlayedCurveDemo: Bool
    @State private var showFeedback = false

    private func handleGoodTap() {
        guard !hasPlayedCurveDemo else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            hasPlayedCurveDemo = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.25)) {
                showFeedback = true
            }
        }
    }

    var body: some View {
        OnboardingStepContainer {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Learn at the edge\nof forgetting.")
                        .font(.display(size: 26, weight: .regular))
                        .foregroundStyle(Color(hex: "0A0A0A"))
                        .lineSpacing(2)

                    Text("We schedule reviews exactly when your memory starts to decay.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color(hex: "525252"))
                        .lineSpacing(5)
                        .padding(.top, 8)
                }

                VStack(spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(hasPlayedCurveDemo ? Color(hex: OnboardingFlowModel.accentHex).opacity(0.10) : Color.white.opacity(0.64))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(hasPlayedCurveDemo ? Color(hex: OnboardingFlowModel.accentHex).opacity(0.30) : Color.white.opacity(0.50), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)

                        VStack(spacing: 12) {
                            Text(hasPlayedCurveDemo ? "Answer" : "Complete the Sentence")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(hex: "525252"))
                                .textCase(.uppercase)

                            if hasPlayedCurveDemo {
                                Text("Irrigation")
                                    .font(.display(size: 30, weight: .regular))
                                    .foregroundStyle(Color(hex: "0A0A0A"))

                                Divider().overlay(Color(hex: "BCBCBC"))

                                Text("Engineers are improving lighting systems and closed-loop irrigation to lower energy and water costs.")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(Color(hex: "0A0A0A"))
                                    .lineSpacing(4)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Engineers are improving lighting systems and closed-loop [_____ ] to lower energy and water costs.")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(Color(hex: "0A0A0A"))
                                    .lineSpacing(5)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(24)
                    }
                    .frame(minHeight: 230)

                    if !hasPlayedCurveDemo {
                        Text("Tap 'Good' to see how the algorithm reacts.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color(hex: "8E8E93"))
                            .padding(.top, 12)

                        HStack(spacing: 10) {
                            OnboardingGradeButton(title: "Again", colorHex: "FF2929", enabled: false)
                            OnboardingGradeButton(title: "Hard", colorHex: "EF8700", enabled: false)
                            OnboardingGradeButton(
                                title: "Good",
                                colorHex: "2987CF",
                                enabled: true,
                                accessibilityID: "onboarding.fsrsGoodButton",
                                action: handleGoodTap
                            )
                            OnboardingGradeButton(title: "Easy", colorHex: "387633", enabled: false)
                        }
                        .padding(.top, 10)
                    }

                    if showFeedback {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: OnboardingFlowModel.accentHex))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Text("4d")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Interval set to 4 days")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color(hex: OnboardingFlowModel.accentHex))
                                Text("You'll review this word again on the optimal day.")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color(hex: "525252"))
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .background(Color(hex: OnboardingFlowModel.accentHex).opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.top, 20)
                    }
                }
                .padding(.top, 24)

                Spacer(minLength: 0)
            }
            .padding(.top, 32)
        }
    }
}

struct OnboardingRankCalibrationStepView: View {
    let calibrationQuestionCount: Int
    let calibrationQuestions: [OnboardingCalibrationQuestion]
    let calibrationAnswers: [String: OnboardingCalibrationAnswer]
    @Binding var calibrationQuestionIndex: Int
    let calibrationResultPreview: LexicalCalibrationResult?
    let onSelectAnswer: (OnboardingCalibrationAnswer, OnboardingCalibrationQuestion) -> Void

    private var currentQuestion: OnboardingCalibrationQuestion? {
        guard !calibrationQuestions.isEmpty else { return nil }
        let index = min(max(calibrationQuestionIndex, 0), calibrationQuestions.count - 1)
        return calibrationQuestions[index]
    }

    private var isComplete: Bool {
        calibrationAnswers.count == calibrationQuestions.count && !calibrationQuestions.isEmpty
    }

    private func indicatorColor(for index: Int) -> Color {
        guard index < calibrationQuestions.count else {
            return Color(hex: "BCBCBC")
        }

        let question = calibrationQuestions[index]
        guard let answer = calibrationAnswers[question.id] else {
            return index == calibrationQuestionIndex
            ? Color(hex: OnboardingFlowModel.accentHex).opacity(0.40)
            : Color(hex: "BCBCBC")
        }

        switch answer {
        case .know:
            return Color(hex: OnboardingFlowModel.accentHex)
        case .unsure:
            return Color(hex: "EF8700")
        case .dontKnow:
            return Color(hex: "D32F2F")
        }
    }

    var body: some View {
        OnboardingStepContainer {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Let's find your baseline.")
                        .font(.display(size: 26, weight: .regular))
                        .foregroundStyle(Color(hex: "0A0A0A"))
                        .accessibilityIdentifier("onboarding.calibrationHeadline")

                    Text("\(calibrationQuestionCount) quick checks to personalize your content.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color(hex: "525252"))
                        .lineSpacing(5)
                        .padding(.top, 8)
                }

                HStack(spacing: 4) {
                    ForEach(0..<calibrationQuestionCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 99, style: .continuous)
                            .fill(indicatorColor(for: index))
                            .frame(width: index < calibrationAnswers.count ? 20 : (index == calibrationQuestionIndex ? 20 : 12), height: 4)
                            .animation(.easeInOut(duration: 0.20), value: calibrationAnswers.count)
                            .animation(.easeInOut(duration: 0.20), value: calibrationQuestionIndex)
                    }
                }
                .padding(.top, 16)

                if calibrationQuestions.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Preparing rank check...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "525252"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 32)
                } else {
                    ZStack {
                        if !isComplete && calibrationQuestionIndex < calibrationQuestions.count - 1 {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.30))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.30), lineWidth: 1)
                                )
                                .padding(.horizontal, 12)
                                .offset(y: 8)
                        }

                        if !isComplete && calibrationQuestionIndex < calibrationQuestions.count - 2 {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.20))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                                )
                                .padding(.horizontal, 24)
                                .offset(y: 16)
                        }

                        Group {
                            if isComplete {
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(hex: OnboardingFlowModel.accentHex))
                                        .frame(width: 56, height: 56)
                                        .overlay {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                        .padding(.bottom, 4)

                                    Text("Calibration complete!")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(Color(hex: "0A0A0A"))

                                    Text(calibrationSummary)
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(Color(hex: "525252"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(24)
                                .background(Color(hex: OnboardingFlowModel.accentHex).opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color(hex: OnboardingFlowModel.accentHex).opacity(0.20), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            } else if let question = currentQuestion {
                                VStack(spacing: 8) {
                                    Text("Word \(calibrationQuestionIndex + 1) of \(calibrationQuestions.count)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color(hex: "8E8E93"))
                                        .textCase(.uppercase)

                                    Text(question.lemma.capitalized)
                                        .font(.display(size: 32, weight: .regular))
                                        .foregroundStyle(Color(hex: "0A0A0A"))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(24)
                                .background(Color.white.opacity(0.64))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.52), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                    .frame(minHeight: 238)
                    .padding(.top, 20)

                    if !isComplete, let question = currentQuestion {
                        HStack(spacing: 10) {
                            OnboardingCalibrationRateButton(
                                title: "I know this",
                                answer: .know,
                                colorHex: OnboardingFlowModel.accentHex,
                                onTap: { onSelectAnswer(.know, question) }
                            )

                            OnboardingCalibrationRateButton(
                                title: "Not sure",
                                answer: .unsure,
                                colorHex: "EF8700",
                                onTap: { onSelectAnswer(.unsure, question) }
                            )

                            OnboardingCalibrationRateButton(
                                title: "New to me",
                                answer: .dontKnow,
                                colorHex: "D32F2F",
                                onTap: { onSelectAnswer(.dontKnow, question) }
                            )
                        }
                        .padding(.top, 16)
                    }
                }

                if let result = calibrationResultPreview, isComplete {
                    Text("Estimated rank: \(result.estimatedRank) · Confidence: \(formattedCalibrationConfidence(result.confidence))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "525252"))
                        .padding(.top, 12)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 32)
        }
    }

    private var calibrationSummary: String {
        let knowCount = calibrationAnswers.values.filter { $0 == .know }.count
        let unsureCount = calibrationAnswers.values.filter { $0 == .unsure }.count
        let newCount = calibrationAnswers.values.filter { $0 == .dontKnow }.count
        return "Known: \(knowCount) · Unsure: \(unsureCount) · New: \(newCount)"
    }

    private func formattedCalibrationConfidence(_ confidence: Double) -> String {
        let percent = Int((max(0, min(1, confidence)) * 100.0).rounded())
        return "\(percent)%"
    }
}

struct OnboardingInterestsStepView: View {
    @Binding var selectedInterests: Set<String>

    private var catalogTopics: [String] {
        var seen = Set<String>()
        var topics: [String] = []
        for group in InterestCatalog.groups {
            for option in group.options {
                if seen.insert(option.title).inserted {
                    topics.append(option.title)
                }
            }
        }
        return topics
    }

    private func toggleTopic(_ topic: String) {
        if selectedInterests.contains(topic) {
            selectedInterests.remove(topic)
        } else {
            selectedInterests.insert(topic)
        }
    }

    private func sanitizeSelection() {
        selectedInterests = OnboardingFlowModel.sanitizeInterests(selectedInterests)
    }

    var body: some View {
        OnboardingStepContainer {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("What fuels your curiosity?")
                        .font(.display(size: 26, weight: .regular))
                        .foregroundStyle(Color(hex: "0A0A0A"))

                    Text("Select at least 2 topics from our catalog to tailor your weekly articles.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color(hex: "525252"))
                        .lineSpacing(5)
                        .padding(.top, 8)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 124), spacing: 10)], spacing: 10) {
                    ForEach(catalogTopics, id: \.self) { topic in
                        let isSelected = selectedInterests.contains(topic)
                        OnboardingInterestChip(
                            title: topic,
                            selected: isSelected,
                            isPopular: ["Technology", "Science"].contains(topic)
                        ) {
                            toggleTopic(topic)
                        }
                    }
                }
                .padding(.top, 28)

                Spacer(minLength: 0)
            }
            .padding(.top, 32)
        }
        .onAppear {
            sanitizeSelection()
        }
    }
}

struct OnboardingArticleStyleStepView: View {
    @Binding var articleStylePreferenceRaw: String

    private var selectedArticleStyle: ArticleStylePreference {
        ArticleStylePreference(rawValue: articleStylePreferenceRaw) ?? .balanced
    }

    private let styleIconMap: [ArticleStylePreference: String] = [
        .balanced: "scale.3d",
        .informative: "magnifyingglass",
        .fun: "sparkles",
        .fresh: "lightbulb"
    ]

    var body: some View {
        OnboardingStepContainer {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Choose your narrative style.")
                        .font(.display(size: 26, weight: .regular))
                        .foregroundStyle(Color(hex: "0A0A0A"))

                    Text("We'll rotate angles, but this sets your default flavor.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color(hex: "525252"))
                        .lineSpacing(5)
                        .padding(.top, 8)
                }

                VStack(spacing: 10) {
                    ForEach(ArticleStylePreference.allCases, id: \.rawValue) { style in
                        let isSelected = selectedArticleStyle == style
                        OnboardingSelectableCard(
                            title: style.title,
                            description: styleSubtitle(style),
                            selected: isSelected,
                            iconName: styleIconMap[style]
                        ) {
                            articleStylePreferenceRaw = style.rawValue
                        }
                        .accessibilityIdentifier("onboarding.articleStyle.\(style.rawValue)")
                    }
                }
                .padding(.top, 28)

                Spacer(minLength: 0)
            }
            .padding(.top, 32)
        }
    }

    private func styleSubtitle(_ style: ArticleStylePreference) -> String {
        switch style {
        case .balanced:
            return "Insight + Clarity"
        case .informative:
            return "Evidence + Structure"
        case .fun:
            return "Storytelling + Examples"
        case .fresh:
            return "Contrarian + New Perspectives"
        }
    }
}

struct OnboardingReadingPrimerStepView: View {
    @State private var tappedWord = false
    @State private var showWordSheet = false

    private func handleWordTap() {
        guard !tappedWord else { return }
        tappedWord = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                showWordSheet = true
            }
        }
    }

    var body: some View {
        OnboardingStepContainer {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Turn reading into recall.")
                        .font(.display(size: 26, weight: .regular))
                        .foregroundStyle(Color(hex: "0A0A0A"))

                    Text("Tap any word in an article to capture it. We'll generate the definition, examples, and synonyms automatically.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color(hex: "525252"))
                        .lineSpacing(5)
                        .padding(.top, 8)
                }

                articleCard
                    .padding(.top, 28)

                if !tappedWord {
                    Text("↑ Tap the highlighted word above")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(hex: OnboardingFlowModel.accentHex))
                        .padding(.top, 16)
                }

                if showWordSheet {
                    wordInfoSheet
                        .padding(.top, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 32)
        }
    }

    private var articleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Music")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "4A5565"))
                    .textCase(.uppercase)
                Spacer()
                Text("5 min read")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(hex: "4A5565"))
            }

            Text("The Physics of Sound")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color(hex: "0A0A0A"))
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 0) {
                    Text("A ")
                    Button("sonorous") { handleWordTap() }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 2)
                        .background(tappedWord ? Color(hex: "B6FF94") : Color(hex: "FFB362"))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    Text(" voice can captivate a room instantly.")
                }

                Text("But what gives sound its depth and resonance? It begins with vibrations.")

                HStack(spacing: 0) {
                    Text("Voice can ")
                    Text("captivate")
                        .padding(.horizontal, 2)
                        .background(Color(hex: "79B1FF"))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    Text(" a room instantly.")
                }
            }
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Color(hex: "364153"))
            .lineSpacing(6)
            .padding(.top, 12)
        }
        .padding(16)
        .background(Color.white.opacity(0.80))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1)
    }

    private var wordInfoSheet: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 99)
                .fill(Color(hex: "D8DEDC"))
                .frame(width: 36, height: 5)
                .padding(.top, 9)

            Text("Word Info")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(hex: "0A0A0A"))
                .textCase(.uppercase)
                .padding(.top, 10)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sonorous")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(Color(hex: "131615"))
                            Text("adjective")
                                .font(.system(size: 10, weight: .regular))
                                .italic()
                                .foregroundStyle(Color(hex: "4E7366"))
                        }
                        Spacer()
                        Circle()
                            .fill(Color(hex: "233F18").opacity(0.50))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(.white)
                            }
                    }
                    .padding(16)
                    .onboardingGlassCard()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Definition")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "0A0A0A").opacity(0.8))
                            .textCase(.uppercase)
                        Text("Having a deep, full, rich sound; imposingly grand.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color(hex: "131615"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .onboardingGlassCard()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Example")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "0A0A0A").opacity(0.8))
                            .textCase(.uppercase)
                        Text("The actor's sonorous voice carried to the back of the theater.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color(hex: "131615"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .onboardingGlassCard()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Synonyms")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "0A0A0A").opacity(0.8))
                            .textCase(.uppercase)

                        HStack(spacing: 8) {
                            OnboardingWordTag(title: "resonant")
                            OnboardingWordTag(title: "rich-toned")
                            OnboardingWordTag(title: "full-bodied")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .onboardingGlassCard()

                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                        Text("Add to Deck")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(hex: OnboardingFlowModel.accentHex))
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                }
                .padding(16)
            }
            .frame(maxHeight: 300)
        }
        .background(Color(hex: "F5F5F7"))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: -4)
    }
}

struct OnboardingNotificationsStepView: View {
    let notificationStatus: UNAuthorizationStatus
    let isRequestingNotificationPermission: Bool
    let isNotificationEnabled: Bool
    let requestNotificationPermission: () -> Void

    private var notificationStatusDescription: String {
        switch notificationStatus {
        case .notDetermined: return "Not requested"
        case .denied: return "Denied"
        case .authorized, .provisional, .ephemeral: return "Enabled"
        @unknown default: return "Unknown"
        }
    }

    var body: some View {
        OnboardingStepContainer {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Never miss a\nmemory window.")
                        .font(.display(size: 26, weight: .regular))
                        .foregroundStyle(Color(hex: "0A0A0A"))
                        .lineSpacing(2)

                    Text("Timing is everything in spaced repetition. We only nudge you when reviews are critical or rank-fit articles arrive.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color(hex: "525252"))
                        .lineSpacing(5)
                        .padding(.top, 8)
                }

                Circle()
                    .fill(Color(hex: OnboardingFlowModel.accentHex).opacity(0.10))
                    .frame(width: 88, height: 88)
                    .overlay {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 36, weight: .regular))
                            .foregroundStyle(Color(hex: OnboardingFlowModel.accentHex))
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 32)

                VStack(spacing: 0) {
                    HStack {
                        Text("Smart Schedule Preview")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "0A0A0A"))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) {
                        Divider().overlay(Color(hex: "F0F0F0"))
                    }

                    OnboardingScheduleRow(
                        iconName: "brain",
                        iconTint: Color(hex: OnboardingFlowModel.accentHex),
                        iconBackground: Color(hex: OnboardingFlowModel.accentHex).opacity(0.10),
                        title: "New Words",
                        subtitle: "Daily vocabulary from your articles",
                        time: "09:00"
                    )

                    Divider().overlay(Color(hex: "F0F0F0")).padding(.leading, 16)

                    OnboardingScheduleRow(
                        iconName: "arrow.triangle.2.circlepath",
                        iconTint: Color(hex: "EF8700"),
                        iconBackground: Color(hex: "EF8700").opacity(0.10),
                        title: "Review Check",
                        subtitle: "Spaced repetition reminders",
                        time: "20:00"
                    )
                }
                .background(Color.white.opacity(0.64))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.50), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)

                Button {
                    requestNotificationPermission()
                } label: {
                    HStack(spacing: 8) {
                        if isRequestingNotificationPermission {
                            ProgressView().tint(.white)
                        }
                        Text("Enable Smart Nudges")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(hex: OnboardingFlowModel.accentHex))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRequestingNotificationPermission || isNotificationEnabled)
                .padding(.top, 24)

                Text("Status: \(notificationStatusDescription). You can also skip this step.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(hex: "525252"))
                    .padding(.top, 10)

                Spacer(minLength: 0)
            }
            .padding(.top, 32)
        }
    }
}

struct OnboardingPremiumOfferStepView: View {
    let productIDs: [String]
    let currentTier: SubscriptionTier
    let isRestoringPurchases: Bool
    let termsURL: URL?
    let privacyURL: URL?
    let onRestorePurchases: () -> Void

    private var hasLegalLinks: Bool {
        termsURL != nil || privacyURL != nil
    }

    var body: some View {
        OnboardingStepContainer {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Go Premium for\nfaster fluency.")
                        .font(.display(size: 26, weight: .regular))
                        .foregroundStyle(Color(hex: "0A0A0A"))
                        .lineSpacing(2)
                        .accessibilityIdentifier("onboarding.premiumHeadline")

                    Text("Outcome-first upgrade: unlimited article generation, unlimited widgets, and personalized FSRS tuning.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color(hex: "525252"))
                        .lineSpacing(5)
                        .padding(.top, 8)
                }

                VStack(spacing: 10) {
                    OnboardingFeatureValueRow(
                        title: "Free",
                        detail: "\(FeatureGateService.freeArticleLimitPerWindow) article / \(FeatureGateService.freeArticleWindowDays) days"
                    )
                    OnboardingFeatureValueRow(
                        title: "Premium",
                        detail: "Unlimited generation + personalized FSRS"
                    )
                }
                .padding(16)
                .background(Color.white.opacity(0.64))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.52), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)
                .overlay(alignment: .topTrailing) {
                    Text("Best value: Yearly")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: OnboardingFlowModel.accentHex))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: OnboardingFlowModel.accentHex).opacity(0.10))
                        .clipShape(Capsule())
                        .padding(10)
                }
                .padding(.top, 20)

                if currentTier == .premium {
                    Text("Premium is already active for this Apple ID.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "2A6A43"))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "EAF3ED"))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 14)
                }

                premiumStoreSection
                    .padding(.top, 14)

                Button {
                    onRestorePurchases()
                } label: {
                    HStack(spacing: 8) {
                        if isRestoringPurchases {
                            ProgressView().tint(Color(hex: OnboardingFlowModel.accentHex))
                        }
                        Text(isRestoringPurchases ? "Restoring..." : "Restore Purchases")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: OnboardingFlowModel.accentHex))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(hex: OnboardingFlowModel.accentHex).opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(hex: OnboardingFlowModel.accentHex).opacity(0.20), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRestoringPurchases)
                .padding(.top, 14)

                if hasLegalLinks {
                    HStack(spacing: 10) {
                        if let termsURL {
                            Link("Terms", destination: termsURL)
                        }
                        if let privacyURL {
                            Link("Privacy", destination: privacyURL)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "6D7788"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 32)
        }
    }

    @ViewBuilder
    private var premiumStoreSection: some View {
#if canImport(StoreKit)
        if #available(iOS 17.0, *) {
            SubscriptionStoreView(productIDs: productIDs)
                .storeButton(.visible, for: .restorePurchases)
                .storeButton(.hidden, for: .cancellation)
                .frame(minHeight: 340)
                .onboardingGlassCard()
        } else {
            unsupportedStoreSection
        }
#else
        unsupportedStoreSection
#endif
    }

    private var unsupportedStoreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("In-app purchase UI is unavailable in this environment.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "222222"))
            Text("Use a StoreKit-enabled iOS build to purchase Premium plans.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(hex: "5C6778"))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onboardingGlassCard()
    }
}

struct OnboardingCompletionStepView: View {
    let userName: String
    let startRankSummary: String
    let selectedInterests: [String]
    let selectedArticleStyleTitle: String

    private var personalizedName: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Learner" : trimmed
    }

    private var interestSummary: String {
        guard !selectedInterests.isEmpty else { return "General" }
        return selectedInterests.prefix(3).joined(separator: ", ")
    }

    var body: some View {
        OnboardingStepContainer {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color(hex: OnboardingFlowModel.accentHex))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 24)

                Text("You're all set, \(personalizedName).")
                    .font(.display(size: 28, weight: .regular))
                    .foregroundStyle(Color(hex: "0A0A0A"))
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                    .accessibilityIdentifier("onboarding.completionHeadline")

                Text("Your learning loop is ready.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(hex: "525252"))
                    .padding(.top, 8)

                VStack(spacing: 0) {
                    OnboardingCompletionRow(icon: "star", title: "Start Rank", detail: startRankSummary)
                    Divider().overlay(Color(hex: "F0F0F0")).padding(.leading, 16)
                    OnboardingCompletionRow(icon: "book", title: "Interests", detail: interestSummary)
                    Divider().overlay(Color(hex: "F0F0F0")).padding(.leading, 16)
                    OnboardingCompletionRow(icon: "paintpalette", title: "Article Style", detail: selectedArticleStyleTitle)
                }
                .background(Color.white.opacity(0.64))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.50), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1)
                .padding(.top, 32)

                Spacer(minLength: 0)
            }
            .padding(.top, 32)
        }
    }
}

private struct OnboardingFeaturePill: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: OnboardingFlowModel.accentHex))
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: OnboardingFlowModel.accentHex))
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Color(hex: OnboardingFlowModel.accentHex).opacity(0.08))
        .clipShape(Capsule())
    }
}

private struct OnboardingGradeButton: View {
    let title: String
    let colorHex: String
    let enabled: Bool
    var accessibilityID: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .textCase(.uppercase)
                .tracking(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color(hex: colorHex).opacity(enabled ? 0.64 : 0.30))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .ifLet(accessibilityID) { view, id in
            view.accessibilityIdentifier(id)
        }
    }
}

private struct OnboardingCalibrationRateButton: View {
    let title: String
    let answer: OnboardingCalibrationAnswer
    let colorHex: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: colorHex))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(hex: colorHex).opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.calibration.\(answer.rawValue)")
    }
}

private struct OnboardingInterestChip: View {
    let title: String
    let selected: Bool
    let isPopular: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(selected ? .white : Color(hex: "0A0A0A"))

                if isPopular && !selected {
                    Text("Popular")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hex: OnboardingFlowModel.accentHex))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color(hex: OnboardingFlowModel.accentHex).opacity(0.10))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .frame(maxWidth: .infinity)
            .background(selected ? Color(hex: OnboardingFlowModel.accentHex) : Color.white.opacity(0.64))
            .overlay(
                Capsule()
                    .stroke(selected ? Color(hex: OnboardingFlowModel.accentHex) : Color.white.opacity(0.50), lineWidth: 1)
            )
            .clipShape(Capsule())
            .shadow(color: selected ? .clear : Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingSelectableCard: View {
    let title: String
    let description: String
    let selected: Bool
    let iconName: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                if let iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(hex: OnboardingFlowModel.accentHex))
                        .frame(width: 18)
                        .padding(.top, 2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(hex: "0A0A0A"))
                    Text(description)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(hex: "525252"))
                }

                Spacer(minLength: 0)

                Circle()
                    .stroke(selected ? Color(hex: OnboardingFlowModel.accentHex) : Color(hex: "BCBCBC"), lineWidth: 1.5)
                    .background(Circle().fill(selected ? Color(hex: OnboardingFlowModel.accentHex) : .clear))
                    .frame(width: 22, height: 22)
                    .overlay {
                        if selected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
            }
            .padding(16)
            .background(selected ? Color(hex: OnboardingFlowModel.accentHex).opacity(0.10) : Color.white.opacity(0.64))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        selected ? Color(hex: OnboardingFlowModel.accentHex) : Color.white.opacity(0.50),
                        lineWidth: selected ? 1.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: selected ? .clear : Color.black.opacity(0.10), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingWordTag: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(hex: OnboardingFlowModel.accentHex))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: OnboardingFlowModel.accentHex).opacity(0.10))
            .clipShape(Capsule())
    }
}

private struct OnboardingScheduleRow: View {
    let iconName: String
    let iconTint: Color
    let iconBackground: Color
    let title: String
    let subtitle: String
    let time: String

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(iconBackground)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: iconName)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(iconTint)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "0A0A0A"))
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }

            Spacer(minLength: 0)

            Text(time)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(hex: "525252"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct OnboardingFeatureValueRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: OnboardingFlowModel.accentHex))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "0A0A0A"))
                Text(detail)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(hex: "525252"))
            }

            Spacer(minLength: 0)
        }
    }
}

private struct OnboardingCompletionRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: OnboardingFlowModel.accentHex).opacity(0.10))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(hex: OnboardingFlowModel.accentHex))
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .textCase(.uppercase)
                Text(detail)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(hex: "0A0A0A"))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private extension View {
    @ViewBuilder
    func ifLet<T, Transformed: View>(_ value: T?, transform: (Self, T) -> Transformed) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}
