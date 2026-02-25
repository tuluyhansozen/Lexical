import SwiftUI
import SwiftData
import LexicalCore
#if canImport(UIKit)
import UIKit
#endif

/// Settings screen aligned to the Figma profile/settings composition.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var interestProfiles: [InterestProfile]

    @AppStorage("dailyGoal") private var dailyGoal: Int = 5
    @AppStorage("darkModeEnabled") private var darkModeEnabled: Bool = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("userName") private var userName: String = "Learner"
    @AppStorage(OnboardingStorageKeys.completed) private var hasCompletedOnboarding = false
    @AppStorage(OnboardingStorageKeys.currentStep) private var onboardingStep = 0

    @State private var restorePurchasesMessage: String?
    @State private var isRestoringPurchases = false
    @State private var showingPremiumOffer = false

    private static let minimumDailyGoal = 1
    private static let maximumDailyGoal = 10

    private var profile: InterestProfile? {
        interestProfiles.first
    }

    private var displayName: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ahmet" : trimmed
    }

    private var displayEmail: String {
        let base = displayName.lowercased().replacingOccurrences(of: " ", with: "")
        let sanitized = base.isEmpty ? "ahmet" : base
        return "\(sanitized)@icloud.com"
    }

    private var goalProgress: CGFloat {
        let span = CGFloat(Self.maximumDailyGoal - Self.minimumDailyGoal)
        guard span > 0 else { return 0 }
        return CGFloat(dailyGoal - Self.minimumDailyGoal) / span
    }

    var body: some View {
        ZStack {
            Color(hex: "F5F5F7")
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 8) {
                    screenHeader

                    VStack(spacing: 14) {
                        profileCard
                        appearanceCard
                        dailyGoalCard
                        personalizationCard
                        notificationsCard
                        widgetsCard
                        acquiredWordsCard
                        accountCard
                    }

                    premiumButton
                        .padding(.top, 6)

                    Color.clear.frame(height: 110)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            ensureInterestProfileExists()
            dailyGoal = clampedDailyGoal(dailyGoal)
        }
        .onChange(of: notificationsEnabled) { _, isEnabled in
            Task { @MainActor in
                await handleNotificationToggleChange(isEnabled)
            }
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
        .navigationDestination(for: InterestProfile.self) { profile in
            ManageInterestsView(profile: profile)
        }
    }

    private var screenHeader: some View {
        HStack {
            Text("Profile")
                .font(.system(size: 24, weight: .bold, design: .default))
                .tracking(0.4)
                .foregroundStyle(Color(hex: "0A0A0A"))
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)
        }
        .frame(height: 36)
    }

    private var profileCard: some View {
        VStack(spacing: 0) {
            settingsAssetImage(named: "settings-avatar-bg", fallbackSystemName: "person.crop.circle.fill")
                .foregroundStyle(Color(hex: "B7BDC9"))
                .frame(width: 70, height: 70)
                .padding(.bottom, 4)

            Text(displayName)
                .font(.system(size: 20, weight: .bold, design: .default))
                .tracking(0.4)
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(displayEmail)
                .font(.system(size: 12, weight: .light, design: .default))
                .tracking(0.4)
                .foregroundStyle(Color(hex: "646464"))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 116)
    }

    private var appearanceCard: some View {
        HStack(spacing: 7) {
            settingsAssetImage(named: "settings-icon-sun", fallbackSystemName: "sun.max")
                .foregroundStyle(Color(hex: "353C45"))
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 0) {
                Text("Appearance")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "0A0A0A"))

                Text(darkModeEnabled ? "Dark mode" : "Light mode")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(hex: "4A5565"))
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    darkModeEnabled.toggle()
                }
            } label: {
                AppearanceModernToggle(isOn: darkModeEnabled)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Appearance")
            .accessibilityValue(darkModeEnabled ? "Dark mode" : "Light mode")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 71)
        .figmaSettingsCard(cornerRadius: 14, showsShadow: false, showsBorder: false)
    }

    private var dailyGoalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                settingsAssetImage(named: "settings-icon-target", fallbackSystemName: "target")
                    .foregroundStyle(Color(hex: "3E4653"))
                    .frame(width: 20, height: 20)

                Text("Daily Goal")
                    .font(.system(size: 16, weight: .medium))
                    .tracking(-0.15)
                    .foregroundStyle(Color(hex: "0A0A0A"))

                Spacer(minLength: 0)
            }

            Text("Set how many words you want to learn daily")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color(hex: "6A7282"))

            dailyGoalSlider

            HStack(spacing: 0) {
                ForEach(Self.minimumDailyGoal...Self.maximumDailyGoal, id: \.self) { step in
                    Capsule()
                        .fill(
                            step <= dailyGoal
                            ? Color(hex: "34C759").opacity(0.92)
                            : Color(hex: "9CA3AF").opacity(0.45)
                        )
                        .frame(width: step <= dailyGoal ? 14 : 7, height: 4)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: dailyGoal)
        }
        .padding(.top, 24)
        .padding(.leading, 14)
        .padding(.trailing, 24)
        .padding(.bottom, 13)
        .frame(maxWidth: .infinity)
        .frame(height: 141)
        .liquidGlassCard(cornerRadius: 16)
    }

    private var personalizationCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Personalization")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: "0A0A0A"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let profile {
                NavigationLink(value: profile) {
                    HStack(spacing: 8) {
                        settingsAssetImage(named: "settings-icon-heart", fallbackSystemName: "heart")
                            .foregroundStyle(Color(hex: "303844"))
                            .frame(width: 20, height: 20)

                        Text("Interests")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "0A0A0A"))

                        Spacer(minLength: 0)

                        Text("\(profile.selectedTags.count) selected")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(hex: "6A7282"))

                        settingsAssetImage(named: "settings-icon-chevron", fallbackSystemName: "chevron.right")
                            .foregroundStyle(Color(hex: "6A7282"))
                            .frame(width: 14, height: 16)
                    }
                    .frame(height: 45)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens interest preferences")
            } else {
                Text("Loading interests")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(hex: "6A7282"))
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 15)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 99)
        .figmaSettingsCard(cornerRadius: 16, showsShadow: true, showsBorder: false)
    }

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notifications")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: "0A0A0A"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 8) {
                settingsAssetImage(named: "settings-icon-bell", fallbackSystemName: "bell")
                    .foregroundStyle(Color(hex: "303844"))
                    .frame(width: 20, height: 20)

                Text("Study Reminders")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "0A0A0A"))

                Spacer(minLength: 0)

                Toggle("", isOn: $notificationsEnabled)
                    .labelsHidden()
                    .tint(Color(hex: "34C759"))
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 15)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 111)
        .figmaSettingsCard(cornerRadius: 16, showsShadow: true, showsBorder: false)
    }

    private var widgetsCard: some View {
        Button {
            // Reserved for widget management flow.
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Widgets")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "0A0A0A"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("Manage your widgets")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(hex: "4A5565"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(height: 75)
            .figmaSettingsCard(cornerRadius: 14, showsShadow: false, showsBorder: false)
        }
        .buttonStyle(.plain)
    }

    private var acquiredWordsCard: some View {
        Button {
            // Reserved for acquired words list flow.
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Acquired Words")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "0A0A0A"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                (
                    Text("See all the ")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(hex: "4A5565"))
                    + Text("words")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(hex: "6DC649"))
                    + Text(" you learned")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(hex: "4A5565"))
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(height: 75)
            .figmaSettingsCard(cornerRadius: 14, showsShadow: false, showsBorder: false)
        }
        .buttonStyle(.plain)
    }

    private var accountCard: some View {
        Menu {
            Button("Replay Onboarding") {
                onboardingStep = 0
                hasCompletedOnboarding = false
            }

            Button(isRestoringPurchases ? "Restoring..." : "Restore Purchases") {
                restorePurchases()
            }
            .disabled(isRestoringPurchases)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Account")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "0A0A0A"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("Manage your account settings")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(hex: "4A5565"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(height: 75)
            .figmaSettingsCard(cornerRadius: 14, showsShadow: false, showsBorder: false)
        }
        .buttonStyle(.plain)
    }

    private var premiumButton: some View {
        Button {
            showingPremiumOffer = true
        } label: {
            ZStack {
                Capsule()
                    .fill(Color(hex: "7B0002").opacity(0.32))
                    .blur(radius: 14)
                    .padding(.horizontal, 6)

                HStack(spacing: 8) {
                    settingsAssetImage(named: "settings-icon-plus", fallbackSystemName: "plus")
                        .foregroundStyle(.white)
                        .frame(width: 18.278, height: 18.278)
                    Text("Get premium")
                        .font(.system(size: 16, weight: .regular))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FF8B8E"), Color(hex: "FF6B73")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.65), lineWidth: 1.2)
                )
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 2)
            }
            .frame(height: 58)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 40)
    }

    private var dailyGoalSlider: some View {
        GeometryReader { geometry in
            let trackHeight: CGFloat = 16
            let thumbSize: CGFloat = 16
            let width = max(geometry.size.width, thumbSize)
            let thumbCenter = thumbSize / 2 + (width - thumbSize) * goalProgress
            let selectedIndex = dailyGoal - Self.minimumDailyGoal
            let stepCount = Self.maximumDailyGoal - Self.minimumDailyGoal + 1

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(Color.white.opacity(0.24))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.62), lineWidth: 0.7)
                    )
                    .frame(height: trackHeight)

                HStack(spacing: 2) {
                    ForEach(0..<stepCount, id: \.self) { index in
                        Capsule()
                            .fill(
                                index <= selectedIndex
                                ? LinearGradient(
                                    colors: [Color(hex: "34C759").opacity(0.92), Color(hex: "2FA84F").opacity(0.86)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.22), Color.white.opacity(0.10)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        index <= selectedIndex
                                        ? Color.white.opacity(0.34)
                                        : Color.white.opacity(0.18),
                                        lineWidth: 0.4
                                    )
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .animation(.easeInOut(duration: 0.14), value: dailyGoal)
                    }
                }
                .padding(.horizontal, 2.5)
                .padding(.vertical, 2.5)
                .frame(height: trackHeight)

                Circle()
                    .fill(Color.white.opacity(0.96))
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.85), lineWidth: 0.5)
                    )
                    .overlay(
                        Circle()
                            .fill(Color(hex: "34C759").opacity(0.24))
                            .frame(width: 6.5, height: 6.5)
                    )
                    .shadow(color: Color(hex: "34C759").opacity(0.28), radius: 7, x: 0, y: 1)
                    .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
                    .offset(x: thumbCenter - thumbSize / 2)
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.88), value: dailyGoal)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        updateDailyGoal(from: gesture.location.x, width: width, thumbSize: thumbSize)
                    }
            )
        }
        .frame(height: 16)
        .accessibilityElement()
        .accessibilityLabel("Daily goal")
        .accessibilityValue("\(dailyGoal) words")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                    dailyGoal = min(dailyGoal + 1, Self.maximumDailyGoal)
                }
            case .decrement:
                withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                    dailyGoal = max(dailyGoal - 1, Self.minimumDailyGoal)
                }
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder
    private func settingsAssetImage(named assetName: String, fallbackSystemName: String) -> some View {
#if canImport(UIKit)
        if UIImage(named: assetName, in: settingsAssetBundle, with: nil) != nil {
            Image(assetName, bundle: settingsAssetBundle)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: fallbackSystemName)
                .font(.system(size: 20, weight: .medium))
        }
#else
        Image(systemName: fallbackSystemName)
            .font(.system(size: 20, weight: .medium))
#endif
    }

    private var settingsAssetBundle: Bundle? {
#if SWIFT_PACKAGE
        return .module
#else
        return .main
#endif
    }

    private func ensureInterestProfileExists() {
        if interestProfiles.isEmpty {
            let newProfile = InterestProfile()
            modelContext.insert(newProfile)
        }
    }

    private func clampedDailyGoal(_ raw: Int) -> Int {
        min(max(raw, Self.minimumDailyGoal), Self.maximumDailyGoal)
    }

    private func updateDailyGoal(from locationX: CGFloat, width: CGFloat, thumbSize: CGFloat) {
        let usableWidth = max(width - thumbSize, 1)
        let normalized = min(max((locationX - thumbSize / 2) / usableWidth, 0), 1)
        let rawValue = CGFloat(Self.minimumDailyGoal) + normalized * CGFloat(Self.maximumDailyGoal - Self.minimumDailyGoal)
        withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
            dailyGoal = clampedDailyGoal(Int(rawValue.rounded()))
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

private struct AppearanceModernToggle: View {
    let isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: isOn
                        ? [Color(hex: "1C4D7C"), Color(hex: "2A7CDB")]
                        : [Color(hex: "D7DAE2"), Color(hex: "C5CAD4")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.6), lineWidth: 0.8)
                )

            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 28, height: 28)
                .shadow(color: Color.black.opacity(0.14), radius: 5, x: 0, y: 2)
                .overlay {
                    Image(systemName: isOn ? "moon.stars.fill" : "sun.max.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isOn ? Color(hex: "2A7CDB") : Color(hex: "F0A100"))
                }
                .padding(.horizontal, 3)
        }
        .frame(width: 62, height: 34)
        .animation(.spring(response: 0.26, dampingFraction: 0.86), value: isOn)
        .accessibilityHidden(true)
    }
}

private struct LiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(Color.white.opacity(0.16))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.62), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        }
    }
}

private struct FigmaSettingsCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let showsShadow: Bool
    let showsBorder: Bool

    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color(hex: "ECECF0"), lineWidth: 1)
                    .opacity(showsBorder ? 1 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: showsShadow ? Color.black.opacity(0.10) : Color.clear,
                radius: showsShadow ? 3 : 0,
                x: 0,
                y: showsShadow ? 1 : 0
            )
    }
}

private extension View {
    func liquidGlassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius))
    }

    func figmaSettingsCard(
        cornerRadius: CGFloat = 16,
        showsShadow: Bool = true,
        showsBorder: Bool = false
    ) -> some View {
        modifier(
            FigmaSettingsCardModifier(
                cornerRadius: cornerRadius,
                showsShadow: showsShadow,
                showsBorder: showsBorder
            )
        )
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
