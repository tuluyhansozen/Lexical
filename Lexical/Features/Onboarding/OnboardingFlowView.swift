import SwiftUI
import SwiftData
import UserNotifications
import LexicalCore

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var interestProfiles: [InterestProfile]

    @AppStorage(OnboardingStorageKeys.currentStep) private var persistedStep: Int = 0
    @AppStorage(OnboardingStorageKeys.completed) private var hasCompletedOnboarding = false
    @AppStorage(OnboardingStorageKeys.notificationPrompted) private var hasPromptedNotifications = false
    @AppStorage(OnboardingStorageKeys.articleStylePreference) private var articleStylePreferenceRaw: String = ArticleStylePreference.balanced.rawValue
    @AppStorage(OnboardingStorageKeys.calibrationRank) private var persistedCalibrationRank: Int = 0
    @AppStorage(OnboardingStorageKeys.calibrationConfidence) private var persistedCalibrationConfidence: Double = 0.0
    @AppStorage("userName") private var userName: String = "Learner"

    @State private var selectedStep: Int = 0
    @State private var selectedInterests: Set<String> = []
    @State private var customInterest: String = ""
    @State private var calibrationQuestions: [OnboardingCalibrationQuestion] = []
    @State private var calibrationAnswers: [String: OnboardingCalibrationAnswer] = [:]
    @State private var calibrationQuestionIndex: Int = 0
    @State private var calibrationResultPreview: LexicalCalibrationResult?
    @State private var hasPlayedCurveDemo = false
    @State private var isRequestingNotificationPermission = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "F5F5F7").ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                TabView(selection: $selectedStep) {
                    welcomeStep.tag(OnboardingStep.welcome.rawValue)
                    fsrsPrimerStep.tag(OnboardingStep.fsrsPrimer.rawValue)
                    rankCalibrationStep.tag(OnboardingStep.rankCalibration.rawValue)
                    interestsStep.tag(OnboardingStep.interests.rawValue)
                    articleStyleStep.tag(OnboardingStep.articleStyle.rawValue)
                    readingPrimerStep.tag(OnboardingStep.readingPrimer.rawValue)
                    notificationsStep.tag(OnboardingStep.notifications.rawValue)
                    completionStep.tag(OnboardingStep.completion.rawValue)
                }
                .modifier(OnboardingPagerStyle())
                .animation(.easeInOut(duration: 0.2), value: selectedStep)

                bottomControls
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            ensureInterestProfileExists()
            selectedStep = normalizedOnboardingStep(persistedStep)
            selectedInterests = Set(interestProfiles.first?.selectedTags ?? [])
            if ArticleStylePreference(rawValue: articleStylePreferenceRaw) == nil {
                articleStylePreferenceRaw = ArticleStylePreference.balanced.rawValue
            }
            normalizeUserName()
            prepareCalibrationQuestionsIfNeeded()
            selectedStep = normalizedOnboardingStep(selectedStep)
            Task { await refreshNotificationStatus() }
        }
        .onChange(of: selectedStep) { _, newValue in
            let normalized = normalizedOnboardingStep(newValue)
            if normalized != newValue {
                selectedStep = normalized
                return
            }
            persistedStep = normalized
        }
        .onChange(of: hasCompletedCalibration) { _, _ in
            let normalized = normalizedOnboardingStep(selectedStep)
            if normalized != selectedStep {
                selectedStep = normalized
            }
        }
    }

    private var topBar: some View {
        HStack {
            Text("Lexical Onboarding")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "4A5565"))
                .accessibilityIdentifier("onboarding.title")

            Spacer()

            if canShowSkip {
                Button("Skip") {
                    selectedStep = OnboardingStep.completion.rawValue
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.sonPrimary)
                .accessibilityIdentifier("onboarding.skipButton")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    Capsule()
                        .fill(step.rawValue == selectedStep ? Color.sonPrimary : Color(hex: "D5D8DE"))
                        .frame(width: step.rawValue == selectedStep ? 24 : 8, height: 8)
                }
            }

            HStack(spacing: 12) {
                Button {
                    selectedStep = max(0, selectedStep - 1)
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedStep == 0 ? Color(hex: "9EA3AD") : Color.sonPrimary)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: "E0E3E8"), lineWidth: 1)
                )
                .disabled(selectedStep == 0)
                .accessibilityIdentifier("onboarding.backButton")

                Button {
                    advanceOrComplete()
                } label: {
                    Text(selectedStep == OnboardingStep.completion.rawValue ? "Start Learning" : "Continue")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(canAdvanceCurrentStep ? Color.sonPrimary : Color(hex: "AAB7AE"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(!canAdvanceCurrentStep)
                .accessibilityIdentifier("onboarding.primaryButton")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            GlassEffectContainer(material: .ultraThin) {
                Color.clear
            }
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var welcomeStep: some View {
        stepContainer {
            VStack(alignment: .leading, spacing: 18) {
                Text("Build your reading fluency with retrieval-first learning.")
                    .font(.display(size: 34, weight: .bold))
                    .foregroundStyle(Color(hex: "0A0A0A"))
                    .accessibilityIdentifier("onboarding.welcomeHeadline")

                Text("Lexical combines Reading, Review, and Word Matrix into one daily loop tuned for intermediate learners.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(hex: "364153"))
                    .lineSpacing(4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("What should we call you?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "4A5565"))

                    TextField("Learner", text: $userName)
                        .lexicalWordsAutocapitalization()
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(hex: "E0E3E8"), lineWidth: 1)
                        )
                        .accessibilityIdentifier("onboarding.nameField")
                }

                VStack(alignment: .leading, spacing: 10) {
                    quickBullet("Free: 1 article per week, 1 active widget profile, standard FSRS")
                    quickBullet("Premium: unlimited articles/widgets + personalized FSRS")
                }
                .padding(.top, 6)
            }
        }
    }

    private var fsrsPrimerStep: some View {
        stepContainer {
            VStack(alignment: .leading, spacing: 18) {
                Text("Learn at the edge of forgetting.")
                    .font(.display(size: 31, weight: .bold))
                    .foregroundStyle(Color(hex: "0A0A0A"))

                Text("FSRS schedules each word exactly when recall starts to decay. Use precise grades so intervals stay accurate.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(hex: "364153"))
                    .lineSpacing(4)

                ForgettingCurvePreview(isStabilized: hasPlayedCurveDemo)
                    .frame(height: 200)
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(hex: "E0E3E8"), lineWidth: 1)
                    )

                Button {
                    hasPlayedCurveDemo = true
                } label: {
                    Label(hasPlayedCurveDemo ? "Memory Stabilized" : "Simulate Review Boost", systemImage: "bolt.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .foregroundStyle(hasPlayedCurveDemo ? Color.sonPrimary : .white)
                        .background(hasPlayedCurveDemo ? Color(hex: "E9F2EC") : Color.sonPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    reviewGradeRow("Again", color: .red, detail: "I forgot it. Show again soon.")
                    reviewGradeRow("Hard", color: .orange, detail: "I recalled with effort.")
                    reviewGradeRow("Good", color: .blue, detail: "Normal recall.")
                    reviewGradeRow("Easy", color: .green, detail: "Instant recall; extend interval.")
                }
            }
        }
    }

    private var rankCalibrationStep: some View {
        stepContainer {
            VStack(alignment: .leading, spacing: 18) {
                Text("Set your starting rank in 10 quick checks.")
                    .font(.display(size: 31, weight: .bold))
                    .foregroundStyle(Color(hex: "0A0A0A"))
                    .accessibilityIdentifier("onboarding.calibrationHeadline")

                Text("Tap the option that matches your confidence. A couple of control words are included to keep rank estimation honest.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(hex: "364153"))
                    .lineSpacing(4)

                if calibrationQuestions.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Preparing rank check...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "4A5565"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(hex: "E0E3E8"), lineWidth: 1)
                    )
                } else if let question = currentCalibrationQuestion {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Question \(calibrationQuestionIndex + 1) of \(calibrationQuestions.count)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "4A5565"))
                            Spacer()
                            Text("Answered \(calibrationAnswers.count)/\(calibrationQuestions.count)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(hex: "6D7788"))
                        }

                        ProgressView(
                            value: Double(calibrationQuestionIndex + 1),
                            total: Double(max(calibrationQuestions.count, 1))
                        )
                        .tint(Color.sonPrimary)

                        VStack(alignment: .leading, spacing: 8) {
                            if question.isDistractor {
                                Text("CONTROL ITEM")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(hex: "D97706"))
                            }

                            Text(question.lemma.capitalized)
                                .font(.display(size: 30, weight: .bold))
                                .foregroundStyle(Color(hex: "121722"))

                            Text(question.promptHint)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(hex: "4A5565"))
                                .lineSpacing(3)
                        }
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(hex: "E0E3E8"), lineWidth: 1)
                        )

                        VStack(spacing: 10) {
                            ForEach(OnboardingCalibrationAnswer.allCases, id: \.rawValue) { answer in
                                calibrationAnswerButton(answer, for: question)
                            }
                        }

                        HStack(spacing: 10) {
                            Button("Previous Word") {
                                calibrationQuestionIndex = max(0, calibrationQuestionIndex - 1)
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(calibrationQuestionIndex == 0 ? Color(hex: "9EA3AD") : Color.sonPrimary)
                            .disabled(calibrationQuestionIndex == 0)

                            Spacer()

                            Button(calibrationQuestionIndex + 1 >= calibrationQuestions.count ? "Finish Check" : "Next Word") {
                                calibrationQuestionIndex = min(calibrationQuestions.count - 1, calibrationQuestionIndex + 1)
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.sonPrimary)
                        }
                    }
                }

                if let result = calibrationResultPreview,
                   calibrationAnswers.count == calibrationQuestions.count,
                   !calibrationQuestions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Estimated start rank: \(result.estimatedRank)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: "1E2938"))
                        Text("Confidence: \(formattedCalibrationConfidence(result.confidence))")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color(hex: "4A5565"))
                    }
                    .padding(12)
                    .background(Color(hex: "EAF3ED"))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var interestsStep: some View {
        stepContainer {
            VStack(alignment: .leading, spacing: 18) {
                Text("Pick your reading interests.")
                    .font(.display(size: 31, weight: .bold))
                    .foregroundStyle(Color(hex: "0A0A0A"))

                Text("Select at least two. Grouped like Bumble-style tags so users can quickly express identity and taste.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(hex: "364153"))
                    .lineSpacing(4)

                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(InterestCatalog.groups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color(hex: "1E2938"))
                                Text(group.subtitle)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(Color(hex: "6D7788"))
                            }

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 10)], spacing: 10) {
                                ForEach(group.options) { option in
                                    let tag = option.title
                                    let isSelected = selectedInterests.contains(tag)
                                    Button {
                                        if isSelected {
                                            selectedInterests.remove(tag)
                                        } else {
                                            selectedInterests.insert(tag)
                                        }
                                    } label: {
                                        Text(option.chipLabel)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(isSelected ? .white : Color(hex: "364153"))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 38)
                                            .background(isSelected ? Color.sonPrimary : Color.white)
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(isSelected ? Color.sonPrimary : Color(hex: "DDE1E8"), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    TextField("Add custom interest", text: $customInterest)
                        .lexicalWordsAutocapitalization()
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(hex: "E0E3E8"), lineWidth: 1)
                        )

                    Button("Add") {
                        let tag = customInterest.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !tag.isEmpty else { return }
                        selectedInterests.insert(tag)
                        customInterest = ""
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(Color.sonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Text("Selected: \(selectedInterests.count)/\(InterestCatalog.all.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "4A5565"))

                Text("Select at least two interests to continue.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(hex: "6D7788"))
            }
        }
    }

    private var articleStyleStep: some View {
        stepContainer {
            VStack(alignment: .leading, spacing: 18) {
                Text("What kind of articles do you want?")
                    .font(.display(size: 31, weight: .bold))
                    .foregroundStyle(Color(hex: "0A0A0A"))

                Text("Choose your default style. We will still rotate topics and angles, but this sets the main writing flavor.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(hex: "364153"))
                    .lineSpacing(4)

                VStack(spacing: 10) {
                    ForEach(ArticleStylePreference.allCases, id: \.rawValue) { style in
                        let isSelected = selectedArticleStyle == style
                        Button {
                            articleStylePreferenceRaw = style.rawValue
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(style.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color(hex: "1A1A1A"))
                                    Text(style.subtitle)
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(Color(hex: "4A5565"))
                                }
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? Color.sonPrimary : Color(hex: "A8AFBC"))
                            }
                            .padding(14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(isSelected ? Color.sonPrimary : Color(hex: "E0E3E8"), lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("onboarding.articleStyle.\(style.rawValue)")
                    }
                }
            }
        }
    }

    private var readingPrimerStep: some View {
        stepContainer {
            VStack(alignment: .leading, spacing: 18) {
                Text("Capture words from context.")
                    .font(.display(size: 31, weight: .bold))
                    .foregroundStyle(Color(hex: "0A0A0A"))

                Text("In Reading, tap unknown words to add them to your deck with definition, examples, and synonyms.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(hex: "364153"))
                    .lineSpacing(4)

                VStack(alignment: .leading, spacing: 12) {
                    Text("A resilient learner can convert passive input into active recall.")
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .foregroundStyle(Color(hex: "1B2331"))
                        .lineSpacing(4)

                    HStack(spacing: 8) {
                        Text("resilient")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "D8E9FF"))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("Blue: tap to capture")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "4A5565"))
                    }

                    HStack(spacing: 8) {
                        Text("learning")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "FFF4C7"))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("Yellow: in your active queue")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "4A5565"))
                    }
                }
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: "E0E3E8"), lineWidth: 1)
                )
            }
        }
    }

    private var notificationsStep: some View {
        stepContainer {
            VStack(alignment: .leading, spacing: 18) {
                Text("Enable smart nudges.")
                    .font(.display(size: 31, weight: .bold))
                    .foregroundStyle(Color(hex: "0A0A0A"))

                Text("Lexical schedules reminders with Bandit timing so you get fewer but higher-value prompts.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(hex: "364153"))
                    .lineSpacing(4)

                VStack(alignment: .leading, spacing: 10) {
                    Label("No spam cadence", systemImage: "bell.badge")
                    Label("Review at high-interruptibility moments", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    Label("Actionable prompts: Reveal, Add, Ignore", systemImage: "bolt.horizontal.circle")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "3A4758"))
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: "E0E3E8"), lineWidth: 1)
                )

                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text("Notification status: \(notificationStatusDescription)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "4A5565"))
                }

                Button {
                    requestNotificationPermission()
                } label: {
                    HStack(spacing: 8) {
                        if isRequestingNotificationPermission {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "bell.fill")
                        }
                        Text("Enable Smart Nudges")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .foregroundStyle(.white)
                    .background(Color.sonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRequestingNotificationPermission || isNotificationEnabled(notificationStatus))
            }
        }
    }

    private var completionStep: some View {
        stepContainer {
            VStack(alignment: .leading, spacing: 18) {
                Text("Your learning loop is ready.")
                    .font(.display(size: 33, weight: .bold))
                    .foregroundStyle(Color(hex: "0A0A0A"))

                Text("You can now generate articles in Reading, capture words in context, review due cards, and track retention in Statistics.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(hex: "364153"))
                    .lineSpacing(4)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Plan Snapshot")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "4A5565"))

                    summaryRow("Free", value: "\(FeatureGateService.freeArticleLimitPerWindow) article / \(FeatureGateService.freeArticleWindowDays) days")
                    summaryRow("Widgets", value: "\(FeatureGateService.freeWidgetProfileLimit) active profile on Free")
                    summaryRow("FSRS", value: "Standard (Free) / Personalized (Premium)")
                    summaryRow("Start rank", value: startRankSummary)
                    summaryRow("Article style", value: selectedArticleStyle.title)
                }
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: "E0E3E8"), lineWidth: 1)
                )
            }
        }
    }

    private var canAdvanceCurrentStep: Bool {
        switch OnboardingStep(rawValue: selectedStep) ?? .welcome {
        case .rankCalibration:
            return calibrationQuestions.count == 10 && calibrationAnswers.count == calibrationQuestions.count
        case .interests:
            return selectedInterests.count >= 2
        default:
            return true
        }
    }

    private var currentCalibrationQuestion: OnboardingCalibrationQuestion? {
        guard !calibrationQuestions.isEmpty else { return nil }
        let index = min(max(calibrationQuestionIndex, 0), calibrationQuestions.count - 1)
        return calibrationQuestions[index]
    }

    private var startRankSummary: String {
        guard persistedCalibrationRank > 0 else { return "Default rank (2500)" }
        if persistedCalibrationConfidence > 0 {
            return "\(persistedCalibrationRank) (\(formattedCalibrationConfidence(persistedCalibrationConfidence)))"
        }
        return "\(persistedCalibrationRank)"
    }

    private var hasCompletedCalibration: Bool {
        persistedCalibrationRank > 0 ||
        (calibrationQuestions.count == 10 && calibrationAnswers.count == calibrationQuestions.count)
    }

    private var canShowSkip: Bool {
        OnboardingProgressGate.canSkip(
            selectedStep: selectedStep,
            completionStep: OnboardingStep.completion.rawValue,
            calibrationStep: OnboardingStep.rankCalibration.rawValue,
            hasCompletedCalibration: hasCompletedCalibration
        )
    }

    private var selectedArticleStyle: ArticleStylePreference {
        ArticleStylePreference(rawValue: articleStylePreferenceRaw) ?? .balanced
    }

    private var notificationStatusDescription: String {
        switch notificationStatus {
        case .notDetermined: return "Not requested"
        case .denied: return "Denied"
        case .authorized, .provisional, .ephemeral: return "Enabled"
        @unknown default: return "Unknown"
        }
    }

    private var statusColor: Color {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        @unknown default: return .gray
        }
    }

    private func isNotificationEnabled(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    private func stepContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private func quickBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.sonPrimary)
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(hex: "3A4758"))
        }
    }

    private func reviewGradeRow(_ title: String, color: Color, detail: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color)
                .clipShape(Capsule())
            Text(detail)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(hex: "4A5565"))
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "4A5565"))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(hex: "1E2938"))
        }
    }

    private func calibrationAnswerButton(
        _ answer: OnboardingCalibrationAnswer,
        for question: OnboardingCalibrationQuestion
    ) -> some View {
        let isSelected = calibrationAnswers[question.id] == answer
        return Button {
            recordCalibrationAnswer(answer, for: question)
        } label: {
            Text(calibrationAnswerTitle(answer))
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .foregroundStyle(isSelected ? .white : Color(hex: "364153"))
                .background(isSelected ? Color.sonPrimary : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color.sonPrimary : Color(hex: "DDE1E8"), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func calibrationAnswerTitle(_ answer: OnboardingCalibrationAnswer) -> String {
        switch answer {
        case .know:
            return "I know this word"
        case .unsure:
            return "Not sure"
        case .dontKnow:
            return "I don't know this"
        }
    }

    private func formattedCalibrationConfidence(_ confidence: Double) -> String {
        let percent = Int((max(0, min(1, confidence)) * 100.0).rounded())
        return "\(percent)%"
    }

    private func prepareCalibrationQuestionsIfNeeded() {
        guard calibrationQuestions.isEmpty else { return }
        let lexemeDescriptor = FetchDescriptor<LexemeDefinition>()
        let lexemes = (try? modelContext.fetch(lexemeDescriptor)) ?? []
        let service = OnboardingRankAssessmentService()

        calibrationQuestions = service.buildQuestions(from: lexemes, questionCount: 10)
        calibrationQuestionIndex = min(
            calibrationQuestionIndex,
            max(0, calibrationQuestions.count - 1)
        )
        refreshCalibrationResultPreview()
    }

    private func recordCalibrationAnswer(
        _ answer: OnboardingCalibrationAnswer,
        for question: OnboardingCalibrationQuestion
    ) {
        calibrationAnswers[question.id] = answer
        if calibrationQuestionIndex + 1 < calibrationQuestions.count {
            calibrationQuestionIndex += 1
        }
        refreshCalibrationResultPreview()
    }

    private func refreshCalibrationResultPreview() {
        let service = OnboardingRankAssessmentService()
        calibrationResultPreview = service.evaluate(
            questions: calibrationQuestions,
            answers: calibrationAnswers
        )
    }

    private func ensureInterestProfileExists() {
        if interestProfiles.isEmpty {
            let profile = InterestProfile()
            modelContext.insert(profile)
            try? modelContext.save()
        }
    }

    private func normalizeUserName() {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            userName = "Learner"
        } else if trimmed != userName {
            userName = trimmed
        }
    }

    private func clampedStepIndex(_ raw: Int) -> Int {
        let maxIndex = OnboardingStep.allCases.count - 1
        return min(max(raw, 0), maxIndex)
    }

    private func normalizedOnboardingStep(_ raw: Int) -> Int {
        let clamped = clampedStepIndex(raw)
        return OnboardingProgressGate.normalizeSelectedStep(
            clamped,
            completionStep: OnboardingStep.completion.rawValue,
            calibrationStep: OnboardingStep.rankCalibration.rawValue,
            hasCompletedCalibration: hasCompletedCalibration
        )
    }

    private func advanceOrComplete() {
        persistCurrentStepState()
        if selectedStep >= OnboardingStep.completion.rawValue {
            finalizeOnboarding()
            return
        }
        selectedStep += 1
    }

    private func persistCurrentStepState() {
        let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        activeProfile.displayName = trimmedName.isEmpty ? "Learner" : trimmedName
        applyCalibrationResultIfAvailable(to: activeProfile)

        let profile = interestProfiles.first ?? {
            let created = InterestProfile()
            modelContext.insert(created)
            return created
        }()
        profile.selectedTags = selectedInterests.sorted()

        try? modelContext.save()
    }

    private func applyCalibrationResultIfAvailable(to activeProfile: UserProfile) {
        guard calibrationQuestions.count == 10 else { return }
        let service = OnboardingRankAssessmentService()
        guard let result = service.evaluate(
            questions: calibrationQuestions,
            answers: calibrationAnswers
        ) else { return }

        activeProfile.lexicalRank = result.estimatedRank
        activeProfile.stateUpdatedAt = Date()
        persistedCalibrationRank = result.estimatedRank
        persistedCalibrationConfidence = result.confidence
    }

    private func finalizeOnboarding() {
        persistCurrentStepState()
        hasCompletedOnboarding = true
        persistedStep = 0
        onComplete()
    }

    private func requestNotificationPermission() {
        guard !isRequestingNotificationPermission else { return }
        isRequestingNotificationPermission = true
        hasPromptedNotifications = true

        Task {
            _ = await BanditScheduler.shared.requestNotificationAuthorization()
            await refreshNotificationStatus()
            await MainActor.run {
                isRequestingNotificationPermission = false
            }
        }
    }

    @MainActor
    private func refreshNotificationStatus() async {
        notificationStatus = await BanditScheduler.shared.notificationAuthorizationStatus()
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case fsrsPrimer
    case rankCalibration
    case interests
    case articleStyle
    case readingPrimer
    case notifications
    case completion
}

enum OnboardingProgressGate {
    static func normalizeSelectedStep(
        _ selectedStep: Int,
        completionStep: Int,
        calibrationStep: Int,
        hasCompletedCalibration: Bool
    ) -> Int {
        let guardrailStep = min(max(0, calibrationStep), completionStep)
        guard !hasCompletedCalibration, selectedStep > guardrailStep else { return selectedStep }
        return guardrailStep
    }

    static func canSkip(
        selectedStep: Int,
        completionStep: Int,
        calibrationStep: Int,
        hasCompletedCalibration: Bool
    ) -> Bool {
        guard hasCompletedCalibration else { return false }
        let normalizedStep = normalizeSelectedStep(
            selectedStep,
            completionStep: completionStep,
            calibrationStep: calibrationStep,
            hasCompletedCalibration: hasCompletedCalibration
        )
        return normalizedStep < completionStep
    }
}

private struct OnboardingPagerStyle: ViewModifier {
    func body(content: Content) -> some View {
#if os(iOS)
        content.tabViewStyle(.page(indexDisplayMode: .never))
#else
        content
#endif
    }
}

private extension View {
    @ViewBuilder
    func lexicalWordsAutocapitalization() -> some View {
#if os(iOS)
        textInputAutocapitalization(.words)
#else
        self
#endif
    }
}

private struct ForgettingCurvePreview: View {
    let isStabilized: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let baseY = height * 0.15
            let floorY = height * 0.88

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "F7F8F9"), Color(hex: "EFF2F5")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Path { path in
                    path.move(to: CGPoint(x: 14, y: baseY))
                    path.addCurve(
                        to: CGPoint(x: width - 14, y: floorY),
                        control1: CGPoint(x: width * 0.35, y: height * 0.30),
                        control2: CGPoint(x: width * 0.72, y: height * 0.82)
                    )
                }
                .stroke(Color.sonPrimary.opacity(0.9), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                if isStabilized {
                    Path { path in
                        let pivotX = width * 0.56
                        path.move(to: CGPoint(x: pivotX, y: height * 0.68))
                        path.addLine(to: CGPoint(x: pivotX, y: baseY))
                    }
                    .stroke(Color(hex: "D97706"), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))

                    Path { path in
                        let pivotX = width * 0.56
                        path.move(to: CGPoint(x: pivotX, y: baseY))
                        path.addCurve(
                            to: CGPoint(x: width - 14, y: height * 0.24),
                            control1: CGPoint(x: width * 0.72, y: height * 0.18),
                            control2: CGPoint(x: width * 0.88, y: height * 0.26)
                        )
                    }
                    .stroke(Color(hex: "16A34A"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
