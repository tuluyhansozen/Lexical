import SwiftUI
import SwiftData
import LexicalCore

/// SettingsView - Profile + App Settings
/// Per design spec: Sync Status, Notification Settings, Voice Settings, etc.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    @Query private var interestProfiles: [InterestProfile]
    
    @AppStorage("dailyGoal") private var dailyGoal: Int = 20
    @AppStorage("darkModeEnabled") private var darkModeEnabled: Bool = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("userName") private var userName: String = "Learner"
    @AppStorage(OnboardingStorageKeys.completed) private var hasCompletedOnboarding = false
    @AppStorage(OnboardingStorageKeys.currentStep) private var onboardingStep = 0
    
    @State private var showingExportSheet = false
    @State private var showingResetAlert = false
    @State private var restorePurchasesMessage: String?
    @State private var isRestoringPurchases = false
    @State private var showingPremiumOffer = false
    
    private var activeUserId: String {
        userProfiles.first?.userId ?? UserProfile.fallbackLocalUserID
    }

    // Cached stats for performance
    @State private var totalWords: Int = 0
    @State private var masteredWords: Int = 0
    @State private var totalReviews: Int = 0
    @State private var currentStreak: Int = 0
    
    // Safe accessor for InterestProfile (singleton pattern)
    private var profile: InterestProfile? {
        interestProfiles.first
    }
    
    var body: some View {
        ZStack {
            Color.adaptiveBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Group {
                        if #available(iOS 26, *) {
                            GlassEffectContainer(spacing: 24) {
                                screenHeader
                                profileSection
                                statsSection
                                learningSettingsSection
                                personalizationSection
                                notificationSettingsSection
                                dataSettingsSection
                                aboutSection
                            }
                        } else {
                            screenHeader
                            profileSection
                            statsSection
                            learningSettingsSection
                            personalizationSection
                            notificationSettingsSection
                            dataSettingsSection
                            aboutSection
                        }
                    }
                    
                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .task {
            ensureInterestProfileExists()
            updateAllStats()
        }
        .onChange(of: notificationsEnabled) { _, isEnabled in
            Task { @MainActor in
                await handleNotificationToggleChange(isEnabled)
            }
        }
        .alert("Reset All Progress?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllProgress()
            }
        } message: {
            Text("This will delete all your vocabulary and review history. This cannot be undone.")
        }
        .alert(
            "Restore Purchases",
            isPresented: Binding(
                get: { restorePurchasesMessage != nil },
                set: { presented in
                    if !presented {
                        restorePurchasesMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(restorePurchasesMessage ?? "")
        }
        .sheet(isPresented: $showingPremiumOffer) {
            PremiumOfferView(
                productIDs: SubscriptionEntitlementService.configuredProductIDs()
            )
        }
    }
    
    private func ensureInterestProfileExists() {
        if interestProfiles.isEmpty {
            let newProfile = InterestProfile()
            modelContext.insert(newProfile)
        }
    }

    private var screenHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Settings")
                .font(.display(.largeTitle, weight: .bold))
                .foregroundStyle(Color.adaptiveText)
                .accessibilityAddTraits(.isHeader)

            Text("Profile and learning preferences")
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Profile Section
    
    private var profileSection: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.sonPrimary, Color.sonPrimary.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Text(String(userName.prefix(1)).uppercased())
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            // Name
            TextField("Your Name", text: $userName)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveText)
                .lexicalWordsAutocapitalization()
                .accessibilityLabel("Display name")
                .accessibilityHint("Used across profile and progress surfaces.")
            
            // Streak Badge
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("\(currentStreak) day streak")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .modifier(LiquidGlassCardModifier(cornerRadius: 20))
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        HStack(spacing: 12) {
            StatBox(title: "Total", value: "\(totalWords)", color: .blue)
            StatBox(title: "Mastered", value: "\(masteredWords)", color: .green)
            StatBox(
                title: "Reviews",
                value: "\(totalReviews)",
                color: .purple
            )
        }
    }
    
    // MARK: - Learning Settings
    
    private var learningSettingsSection: some View {
        SettingsGroup(title: "Learning") {
            // Daily Goal
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Daily Goal", systemImage: "target")
                    Spacer()
                    Text("\(dailyGoal) words")
                        .foregroundStyle(Color.adaptiveTextSecondary)
                }
                
                Slider(value: Binding(
                    get: { Double(dailyGoal) },
                    set: { dailyGoal = Int($0) }
                ), in: 5...50, step: 5)
                .tint(Color.sonPrimary)
                .accessibilityLabel("Daily goal")
                .accessibilityValue("\(dailyGoal) words")
            }
            
            Divider()
            
            // Appearance
            Toggle(isOn: $darkModeEnabled) {
                Label("Dark Mode", systemImage: "moon.fill")
            }
            .tint(Color.sonPrimary)
        }
    }
    
    // MARK: - Personalization
    
    private var personalizationSection: some View {
        SettingsGroup(title: "Personalization") {
            if let profile = profile {
                NavigationLink(value: profile) {
                    HStack {
                        Label("Interests", systemImage: "heart.fill")
                            .foregroundStyle(Color.adaptiveText)
                        Spacer()
                        Text("\(profile.selectedTags.count) selected")
                            .foregroundStyle(Color.adaptiveTextSecondary)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
                .navigationDestination(for: InterestProfile.self) { profile in
                    ManageInterestsView(profile: profile)
                }
                .accessibilityHint("Opens the interest selection screen.")
            } else {
                Text("Loading profile...")
                    .foregroundStyle(Color.adaptiveTextSecondary)
            }
        }
    }
    
    // MARK: - Notification Settings
    
    private var notificationSettingsSection: some View {
        SettingsGroup(title: "Notifications") {
            Toggle(isOn: $notificationsEnabled) {
                Label("Study Reminders", systemImage: "bell.fill")
            }
            .tint(Color.sonPrimary)
            
            if notificationsEnabled {
                Divider()
                
                HStack {
                    Label("Timing", systemImage: "clock.fill")
                    Spacer()
                    Text("09:00/14:00 suggestions • 20:00 review")
                        .foregroundStyle(Color.adaptiveTextSecondary)
                }
            }
        }
    }
    
    // MARK: - Data Settings
    
    private var dataSettingsSection: some View {
        SettingsGroup(title: "Data") {
            Button {
                showingExportSheet = true
            } label: {
                HStack {
                    Label("Export Vocabulary", systemImage: "square.and.arrow.up")
                        .foregroundStyle(Color.adaptiveText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityHint("Exports your current vocabulary data.")
            
            Divider()

            Button {
                showingPremiumOffer = true
            } label: {
                HStack {
                    Label("View Premium Plans", systemImage: "crown.fill")
                        .foregroundStyle(Color.adaptiveText)
                    Spacer()
                }
            }

            Divider()

            Button {
                restorePurchases()
            } label: {
                HStack {
                    Label(
                        isRestoringPurchases ? "Restoring..." : "Restore Purchases",
                        systemImage: "arrow.clockwise.circle"
                    )
                    .foregroundStyle(Color.adaptiveText)
                    Spacer()
                }
            }
            .disabled(isRestoringPurchases)
            .accessibilityHint("Restores premium purchases linked to your Apple ID.")

            Divider()
            
            // Sync Status
            HStack {
                Label("Sync Status", systemImage: "cloud.fill")
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Local Only")
                        .foregroundStyle(Color.adaptiveTextSecondary)
                }
                .font(.caption)
            }
            
            Divider()
            
            Button(role: .destructive) {
                showingResetAlert = true
            } label: {
                HStack {
                    Label("Reset All Progress", systemImage: "trash.fill")
                        .foregroundStyle(.red)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        SettingsGroup(title: "About") {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("1.0.0 (Beta)")
                    .foregroundStyle(Color.adaptiveTextSecondary)
            }
            
            Divider()
            
            Button {
                // Open privacy policy
            } label: {
                HStack {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                        .foregroundStyle(Color.adaptiveText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }

            Divider()

            Button {
                onboardingStep = 0
                hasCompletedOnboarding = false
            } label: {
                HStack {
                    Label("Replay Onboarding", systemImage: "sparkles.rectangle.stack")
                        .foregroundStyle(Color.adaptiveText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    @MainActor
    private func updateAllStats() {
        let userId = activeUserId
        
        // 1. Total Words
        do {
            totalWords = try modelContext.fetchCount(FetchDescriptor<LexemeDefinition>())
        } catch {
            totalWords = 0
        }
        
        // 2. Mastered Words
        do {
            let descriptor = FetchDescriptor<UserWordState>(
                predicate: #Predicate { $0.userId == userId }
            )
            let allStates = try modelContext.fetch(descriptor)
            masteredWords = allStates.filter { $0.status == .known }.count
        } catch {
            masteredWords = 0
        }
        
        // 3. Total Reviews
        do {
            let descriptor = FetchDescriptor<ReviewEvent>(
                predicate: #Predicate { $0.userId == userId }
            )
            totalReviews = try modelContext.fetchCount(descriptor)
        } catch {
            totalReviews = 0
        }
        
        // 4. Current Streak - Since we removed the reviewEvents array, we use the StatsService (or re-fetch)
        let statsService = StatsService(modelContext: modelContext)
        currentStreak = statsService.calculateStreak()
    }
    
    private func resetAllProgress() {
        do {
            try modelContext.delete(model: ReviewEvent.self)
            try modelContext.delete(model: UserWordState.self)
            try modelContext.delete(model: DiscoveredLexeme.self)
            try modelContext.save()
            updateAllStats()
        } catch {
            print("Error resetting progress: \(error)")
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
                    productIDs: SubscriptionEntitlementService.configuredProductIDs()
                )

                if snapshot.tier == .premium {
                    restorePurchasesMessage = "Premium access restored successfully."
                } else {
                    restorePurchasesMessage = "No active premium subscription was found for this Apple ID."
                }
            } catch {
                restorePurchasesMessage = "Restore failed: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func handleNotificationToggleChange(_ isEnabled: Bool) async {
        if !isEnabled {
            BanditScheduler.shared.cancelOutOfAppReminderNotifications()
            return
        }

        let scheduler = BanditScheduler.shared
        let status = await scheduler.notificationAuthorizationStatus()
        switch status {
        case .authorized, .provisional:
            scheduler.syncOutOfAppReminderNotifications(notificationsEnabled: true)
        case .notDetermined:
            let granted = await scheduler.requestNotificationAuthorization()
            if granted {
                scheduler.syncOutOfAppReminderNotifications(notificationsEnabled: true)
            } else {
                notificationsEnabled = false
                scheduler.cancelOutOfAppReminderNotifications()
            }
        default:
            notificationsEnabled = false
            scheduler.cancelOutOfAppReminderNotifications()
        }
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

// MARK: - Components

struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.metricValue)
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.adaptiveTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .modifier(LiquidGlassCardModifier(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.metricLabel)
                .foregroundStyle(Color.adaptiveTextSecondary)
                .padding(.leading, 4)
            
            VStack(spacing: 16) {
                content
            }
            .padding(16)
            .modifier(LiquidGlassCardModifier(cornerRadius: 16))
        }
    }
}

struct LiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let withShadow: Bool
    
    init(cornerRadius: CGFloat = 16, withShadow: Bool = true) {
        self.cornerRadius = cornerRadius
        self.withShadow = withShadow
    }
    
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            if withShadow {
                content
                    .background(Color.adaptiveSurfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.adaptiveBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .shadow(color: Color.cardShadow.opacity(0.32), radius: 4, x: 0, y: 2)
            } else {
                content
                    .background(Color.adaptiveSurfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.adaptiveBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(
            for: [
                UserWordState.self,
                ReviewEvent.self,
                LexemeDefinition.self,
                InterestProfile.self,
                MorphologicalRoot.self,
                UserProfile.self,
            ]
        )
}
