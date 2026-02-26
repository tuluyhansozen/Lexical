import SwiftUI
import SwiftData
import UserNotifications
import LexicalCore

struct OnboardingFlowView: View {
    private let calibrationQuestionCount = 12

    @Environment(\.modelContext) private var modelContext
    @Query private var interestProfiles: [InterestProfile] 

    @AppStorage(OnboardingStorageKeys.currentStep) private var persistedStep: Int = 0
    @AppStorage(OnboardingStorageKeys.completed) private var hasCompletedOnboarding = false
    @AppStorage(OnboardingStorageKeys.notificationPrompted) private var hasPromptedNotifications = false
    @AppStorage(OnboardingStorageKeys.articleStylePreference) private var articleStylePreferenceRaw: String = ArticleStylePreference.balanced.rawValue
    @AppStorage(OnboardingStorageKeys.calibrationRank) private var persistedCalibrationRank: Int = 0
    @AppStorage(OnboardingStorageKeys.calibrationConfidence) private var persistedCalibrationConfidence: Double = 0.0
    @AppStorage(OnboardingStorageKeys.flowVersion) private var onboardingFlowVersion: Int = 0
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("userName") private var userName: String = "Learner"

    @State private var selectedStep: Int = 0
    @State private var selectedInterests: Set<String> = []
    @State private var calibrationQuestions: [OnboardingCalibrationQuestion] = []
    @State private var calibrationAnswers: [String: OnboardingCalibrationAnswer] = [:]
    @State private var calibrationQuestionIndex: Int = 0
    @State private var calibrationResultPreview: LexicalCalibrationResult?
    @State private var hasPlayedCurveDemo = false
    @State private var isRequestingNotificationPermission = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    @State private var premiumTier: SubscriptionTier = .free
    @State private var isRestoringPurchases = false
    @State private var premiumAlertMessage: String?

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color(hex: OnboardingFlowModel.backgroundHex).ignoresSafeArea()

            VStack(spacing: 0) {
                OnboardingHeaderBar(
                    showBack: canShowBackButton,
                    showSkip: canShowSkipButton,
                    onBack: { selectedStep = max(0, selectedStep - 1) },
                    onSkip: handleSkip
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)

                OnboardingProgressBar(
                    currentStep: selectedStep,
                    totalSteps: OnboardingStep.allCases.count
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                TabView(selection: $selectedStep) {
                    OnboardingWelcomeStepView(userName: $userName)
                        .tag(OnboardingStep.welcome.rawValue)

                    OnboardingFSRSStepView(hasPlayedCurveDemo: $hasPlayedCurveDemo)
                        .tag(OnboardingStep.fsrsPrimer.rawValue)

                    OnboardingRankCalibrationStepView(
                        calibrationQuestionCount: calibrationQuestionCount,
                        calibrationQuestions: calibrationQuestions,
                        calibrationAnswers: calibrationAnswers,
                        calibrationQuestionIndex: $calibrationQuestionIndex,
                        calibrationResultPreview: calibrationResultPreview,
                        onSelectAnswer: recordCalibrationAnswer
                    )
                    .tag(OnboardingStep.rankCalibration.rawValue)

                    OnboardingInterestsStepView(
                        selectedInterests: $selectedInterests
                    )
                    .tag(OnboardingStep.interests.rawValue)

                    OnboardingArticleStyleStepView(articleStylePreferenceRaw: $articleStylePreferenceRaw)
                        .tag(OnboardingStep.articleStyle.rawValue)

                    OnboardingReadingPrimerStepView()
                        .tag(OnboardingStep.readingPrimer.rawValue)

                    OnboardingNotificationsStepView(
                        notificationStatus: notificationStatus,
                        isRequestingNotificationPermission: isRequestingNotificationPermission,
                        isNotificationEnabled: isNotificationEnabled(notificationStatus),
                        requestNotificationPermission: requestNotificationPermission
                    )
                    .tag(OnboardingStep.notifications.rawValue)

                    OnboardingPremiumOfferStepView(
                        productIDs: premiumProductIDs,
                        currentTier: premiumTier,
                        isRestoringPurchases: isRestoringPurchases,
                        termsURL: termsURL,
                        privacyURL: privacyURL,
                        onRestorePurchases: restorePurchases
                    )
                    .tag(OnboardingStep.premiumOffer.rawValue)

                    OnboardingCompletionStepView(
                        userName: userName,
                        startRankSummary: startRankSummary,
                        selectedInterests: selectedInterests.sorted(),
                        selectedArticleStyleTitle: selectedArticleStyle.title
                    )
                    .tag(OnboardingStep.completion.rawValue)
                }
                .modifier(OnboardingPagerStyle())
                .animation(.easeInOut(duration: 0.2), value: selectedStep)

                VStack(spacing: 12) {
                    OnboardingPrimaryButton(
                        title: primaryButtonTitle,
                        isEnabled: canAdvanceCurrentStep,
                        accessibilityID: primaryButtonAccessibilityID,
                        action: advanceOrComplete
                    )
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
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            ensureInterestProfileExists()
            migrateOnboardingStateIfNeeded()

            selectedStep = normalizedOnboardingStep(persistedStep)
            selectedInterests = OnboardingFlowModel.sanitizeInterests(Set(interestProfiles.first?.selectedTags ?? []))

            if ArticleStylePreference(rawValue: articleStylePreferenceRaw) == nil {
                articleStylePreferenceRaw = ArticleStylePreference.balanced.rawValue
            }

            normalizeUserName()
            prepareCalibrationQuestionsIfNeeded()
            selectedStep = normalizedOnboardingStep(selectedStep)

            Task {
                await refreshNotificationStatus()
                if !isRunningForPreviews {
                    await refreshPremiumEntitlement()
                }
            }
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
        .task(id: selectedStep) {
            guard !isRunningForPreviews else { return }
            guard selectedStep == OnboardingStep.premiumOffer.rawValue else { return }
            await refreshPremiumEntitlement()
            while selectedStep == OnboardingStep.premiumOffer.rawValue,
                  premiumTier != .premium,
                  !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await refreshPremiumEntitlement()
            }
        }
        .alert(
            "Premium",
            isPresented: Binding(
                get: { premiumAlertMessage != nil },
                set: { presented in
                    if !presented { premiumAlertMessage = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(premiumAlertMessage ?? "")
        }
    }

    private var currentOnboardingStep: OnboardingStep {
        OnboardingStep(rawValue: selectedStep) ?? .welcome
    }

    private var canShowBackButton: Bool {
        selectedStep > OnboardingStep.welcome.rawValue && selectedStep < OnboardingStep.completion.rawValue
    }

    private var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var canShowSkipButton: Bool {
        guard OnboardingFlowModel.skippableSteps.contains(currentOnboardingStep) else {
            return false
        }

        return OnboardingProgressGate.canSkip(
            selectedStep: selectedStep,
            completionStep: OnboardingStep.completion.rawValue,
            calibrationStep: OnboardingStep.rankCalibration.rawValue,
            hasCompletedCalibration: hasCompletedCalibration
        )
    }

    private var primaryButtonTitle: String {
        OnboardingFlowModel.primaryButtonTitle(for: currentOnboardingStep)
    }

    private var primaryButtonAccessibilityID: String {
        currentOnboardingStep == .premiumOffer
        ? "onboarding.continueFreeButton"
        : "onboarding.primaryButton"
    }

    private var selectedArticleStyle: ArticleStylePreference {
        ArticleStylePreference(rawValue: articleStylePreferenceRaw) ?? .balanced
    }

    private var premiumProductIDs: [String] {
        SubscriptionEntitlementService.configuredProductIDs().sorted()
    }

    private var termsURL: URL? {
        infoURL(for: "LexicalTermsURL")
    }

    private var privacyURL: URL? {
        infoURL(for: "LexicalPrivacyURL")
    }

    private var canAdvanceCurrentStep: Bool {
        switch currentOnboardingStep {
        case .welcome:
            return !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .fsrsPrimer:
            return hasPlayedCurveDemo
        case .rankCalibration:
            return calibrationQuestions.count == calibrationQuestionCount &&
            calibrationAnswers.count == calibrationQuestions.count
        case .interests:
            return OnboardingFlowModel.sanitizeInterests(selectedInterests).count >= 2
        default:
            return true
        }
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
        (calibrationQuestions.count == calibrationQuestionCount &&
         calibrationAnswers.count == calibrationQuestions.count)
    }

    private func migrateOnboardingStateIfNeeded() {
        guard onboardingFlowVersion < OnboardingFlowModel.currentFlowVersion else { return }

        if hasCompletedOnboarding {
            persistedStep = 0
            onboardingFlowVersion = OnboardingFlowModel.currentFlowVersion
            return
        }

        persistedStep = OnboardingFlowModel.migratePersistedStep(
            persistedStep,
            fromFlowVersion: onboardingFlowVersion,
            toFlowVersion: OnboardingFlowModel.currentFlowVersion
        )
        onboardingFlowVersion = OnboardingFlowModel.currentFlowVersion
    }

    private func handleSkip() {
        guard canShowSkipButton else { return }
        persistCurrentStepState()
        selectedStep = min(selectedStep + 1, OnboardingStep.completion.rawValue)
    }

    private func infoURL(for key: String) -> URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return nil
        }

        return url
    }

    private func clampedStepIndex(_ raw: Int) -> Int {
        OnboardingFlowModel.clampStep(raw)
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
        guard canAdvanceCurrentStep else { return }
        persistCurrentStepState()

        if selectedStep >= OnboardingStep.completion.rawValue {
            finalizeOnboarding()
            return
        }

        selectedStep += 1
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

    private func finalizeOnboarding() {
        persistCurrentStepState()
        hasCompletedOnboarding = true
        persistedStep = 0
        onboardingFlowVersion = OnboardingFlowModel.currentFlowVersion
        onComplete()
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
        let sanitizedInterests = OnboardingFlowModel.sanitizeInterests(selectedInterests)
        selectedInterests = sanitizedInterests
        profile.selectedTags = sanitizedInterests.sorted()

        try? modelContext.save()
    }

    private func applyCalibrationResultIfAvailable(to activeProfile: UserProfile) {
        guard calibrationQuestions.count == calibrationQuestionCount else { return }
        let service = OnboardingRankAssessmentService()
        guard let result = service.evaluate(
            questions: calibrationQuestions,
            answers: calibrationAnswers,
            priorRank: calibrationPriorRank(from: activeProfile)
        ) else { return }

        activeProfile.lexicalRank = result.estimatedRank
        activeProfile.stateUpdatedAt = Date()
        persistedCalibrationRank = result.estimatedRank
        persistedCalibrationConfidence = result.confidence
    }

    private func calibrationPriorRank(from activeProfile: UserProfile? = nil) -> Int? {
        if persistedCalibrationRank > 0 {
            return persistedCalibrationRank
        }

        let profile = activeProfile ?? UserProfile.resolveActiveProfile(modelContext: modelContext)
        return profile.lexicalRank > 2_500 ? profile.lexicalRank : nil
    }

    private func prepareCalibrationQuestionsIfNeeded() {
        guard calibrationQuestions.isEmpty else { return }
        let lexemeDescriptor = FetchDescriptor<LexemeDefinition>()
        let lexemes = (try? modelContext.fetch(lexemeDescriptor)) ?? []
        let service = OnboardingRankAssessmentService()

        calibrationQuestions = service.buildQuestions(
            from: lexemes,
            questionCount: calibrationQuestionCount
        )
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
            answers: calibrationAnswers,
            priorRank: calibrationPriorRank()
        )
    }

    private func formattedCalibrationConfidence(_ confidence: Double) -> String {
        let percent = Int((max(0, min(1, confidence)) * 100.0).rounded())
        return "\(percent)%"
    }

    private func requestNotificationPermission() {
        guard !isRequestingNotificationPermission else { return }
        isRequestingNotificationPermission = true
        hasPromptedNotifications = true

        Task {
            _ = await BanditScheduler.shared.requestNotificationAuthorization()
            await refreshNotificationStatus()
            await MainActor.run {
                if notificationsEnabled && isNotificationEnabled(notificationStatus) {
                    BanditScheduler.shared.syncOutOfAppReminderNotifications(notificationsEnabled: true)
                }
                isRequestingNotificationPermission = false
            }
        }
    }

    @MainActor
    private func refreshNotificationStatus() async {
        notificationStatus = await BanditScheduler.shared.notificationAuthorizationStatus()
    }

    private func isNotificationEnabled(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    @MainActor
    private func refreshPremiumEntitlement() async {
        let snapshot = await SubscriptionEntitlementService.shared.refreshEntitlements(
            modelContainer: Persistence.sharedModelContainer,
            productIDs: Set(premiumProductIDs)
        )
        premiumTier = snapshot.tier

        if snapshot.tier == .premium,
           selectedStep == OnboardingStep.premiumOffer.rawValue {
            selectedStep = OnboardingStep.completion.rawValue
        }
    }

    private func restorePurchases() {
        guard !isRestoringPurchases else { return }
        isRestoringPurchases = true

        Task { @MainActor in
            defer { isRestoringPurchases = false }
            do {
                let snapshot = try await SubscriptionEntitlementService.shared.restorePurchases(
                    modelContainer: Persistence.sharedModelContainer,
                    productIDs: Set(premiumProductIDs)
                )
                premiumTier = snapshot.tier
                if snapshot.tier == .premium {
                    selectedStep = OnboardingStep.completion.rawValue
                } else {
                    premiumAlertMessage = "No active premium subscription was found for this Apple ID."
                }
            } catch {
                premiumAlertMessage = "Restore failed: \(error.localizedDescription)"
            }
        }
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

@MainActor
private func onboardingPreviewContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: InterestProfile.self,
             UserProfile.self,
             LexemeDefinition.self,
             MorphologicalRoot.self,
        configurations: config
    )

    let context = container.mainContext
    context.insert(InterestProfile(selectedTags: ["Technology", "Science"]))

    let profile = UserProfile(userId: UserProfile.fallbackLocalUserID)
    profile.displayName = "Preview Learner"
    profile.lexicalRank = 3000
    context.insert(profile)

    try? context.save()
    return container
}

@MainActor
private func configureOnboardingPreviewDefaults(
    step: OnboardingStep,
    calibrationCompleted: Bool
) {
    let defaults = UserDefaults.standard
    defaults.set(false, forKey: OnboardingStorageKeys.completed)
    defaults.set(step.rawValue, forKey: OnboardingStorageKeys.currentStep)
    defaults.set(OnboardingFlowModel.currentFlowVersion, forKey: OnboardingStorageKeys.flowVersion)
    defaults.set("Preview Learner", forKey: "userName")
    defaults.set(ArticleStylePreference.balanced.rawValue, forKey: OnboardingStorageKeys.articleStylePreference)

    if calibrationCompleted {
        defaults.set(3000, forKey: OnboardingStorageKeys.calibrationRank)
        defaults.set(0.75, forKey: OnboardingStorageKeys.calibrationConfidence)
    } else {
        defaults.removeObject(forKey: OnboardingStorageKeys.calibrationRank)
        defaults.removeObject(forKey: OnboardingStorageKeys.calibrationConfidence)
    }
}

@MainActor
private func onboardingPreview(
    step: OnboardingStep,
    calibrationCompleted: Bool
) -> some View {
    configureOnboardingPreviewDefaults(step: step, calibrationCompleted: calibrationCompleted)
    return OnboardingFlowView(onComplete: {})
        .modelContainer(onboardingPreviewContainer())
}

#Preview("Onboarding - Welcome") {
    onboardingPreview(step: .welcome, calibrationCompleted: false)
}

#Preview("Onboarding - Premium") {
    onboardingPreview(step: .premiumOffer, calibrationCompleted: true)
}

#Preview("Onboarding - Completion") {
    onboardingPreview(step: .completion, calibrationCompleted: true)
}
