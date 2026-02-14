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
    @AppStorage("userName") private var userName: String = "Learner"

    @State private var selectedStep: Int = 0
    @State private var selectedInterests: Set<String> = []
    @State private var customInterest: String = ""
    @State private var hasPlayedCurveDemo = false
    @State private var isRequestingNotificationPermission = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    let onComplete: () -> Void

    private let suggestedInterests = [
        "Technology", "Science", "Business", "Health", "Arts", "Psychology", "History", "Design"
    ]

    var body: some View {
        ZStack {
            Color(hex: "F5F5F7").ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                TabView(selection: $selectedStep) {
                    welcomeStep.tag(OnboardingStep.welcome.rawValue)
                    fsrsPrimerStep.tag(OnboardingStep.fsrsPrimer.rawValue)
                    interestsStep.tag(OnboardingStep.interests.rawValue)
                    readingPrimerStep.tag(OnboardingStep.readingPrimer.rawValue)
                    notificationsStep.tag(OnboardingStep.notifications.rawValue)
                    completionStep.tag(OnboardingStep.completion.rawValue)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.2), value: selectedStep)

                bottomControls
            }
        }
        .interactiveDismissDisabled(true)
        .onAppear {
            ensureInterestProfileExists()
            selectedStep = clampedStepIndex(persistedStep)
            selectedInterests = Set(interestProfiles.first?.selectedTags ?? [])
            normalizeUserName()
            Task { await refreshNotificationStatus() }
        }
        .onChange(of: selectedStep) { _, newValue in
            persistedStep = clampedStepIndex(newValue)
        }
    }

    private var topBar: some View {
        HStack {
            Text("Lexical Onboarding")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "4A5565"))

            Spacer()

            if selectedStep < OnboardingStep.completion.rawValue {
                Button("Skip") {
                    selectedStep = OnboardingStep.completion.rawValue
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.sonPrimary)
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

                Text("Lexical combines Reading, Review, and Word Matrix into one daily loop tuned for intermediate learners.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(hex: "364153"))
                    .lineSpacing(4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("What should we call you?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "4A5565"))

                    TextField("Learner", text: $userName)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(hex: "E0E3E8"), lineWidth: 1)
                        )
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

    private var interestsStep: some View {
        stepContainer {
            VStack(alignment: .leading, spacing: 18) {
                Text("Pick your reading interests.")
                    .font(.display(size: 31, weight: .bold))
                    .foregroundStyle(Color(hex: "0A0A0A"))

                Text("We use these to generate articles and keep your daily reading loop meaningful.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(hex: "364153"))
                    .lineSpacing(4)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                    ForEach(suggestedInterests, id: \.self) { tag in
                        let isSelected = selectedInterests.contains(tag)
                        Button {
                            if isSelected {
                                selectedInterests.remove(tag)
                            } else {
                                selectedInterests.insert(tag)
                            }
                        } label: {
                            Text(tag)
                                .font(.system(size: 14, weight: .semibold))
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

                HStack(spacing: 10) {
                    TextField("Add custom interest", text: $customInterest)
                        .textInputAutocapitalization(.words)
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

                Text("Select at least one interest to continue.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(hex: "6D7788"))
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
        case .interests:
            return !selectedInterests.isEmpty
        default:
            return true
        }
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

        let profile = interestProfiles.first ?? {
            let created = InterestProfile()
            modelContext.insert(created)
            return created
        }()
        profile.selectedTags = selectedInterests.sorted()

        try? modelContext.save()
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
    case interests
    case readingPrimer
    case notifications
    case completion
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
