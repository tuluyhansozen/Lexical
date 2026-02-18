import SwiftUI
import LexicalCore

#if canImport(StoreKit)
import StoreKit
#endif

struct PremiumOfferView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showingAlert = false
    @State private var alertMessage: String?
    @State private var isRestoring = false
    @State private var currentTier: SubscriptionTier = .free

    private let productIDs: [String]
    private let onEntitlementChanged: (() -> Void)?

    init(
        productIDs: Set<String>,
        onEntitlementChanged: (() -> Void)? = nil
    ) {
        self.productIDs = productIDs.sorted()
        self.onEntitlementChanged = onEntitlementChanged
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection
                    benefitsSection
                    storeSection
                    restoreButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(Color(hex: "F5F5F7").ignoresSafeArea())
            .navigationTitle("Premium")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem {
                    Button("Close") {
                        dismiss()
                    }
                }
                #endif
            }
        }
        .task {
            await refreshEntitlementState()
        }
        .alert(
            "Premium",
            isPresented: $showingAlert
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unlock adaptive learning at full scale.")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(hex: "101010"))
                .fixedSize(horizontal: false, vertical: true)

            Text("Premium gives unlimited articles/widgets plus personalized FSRS tuning.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(hex: "445164"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            benefitRow("Unlimited article generation")
            benefitRow("Unlimited widget profiles")
            benefitRow("Personalized FSRS parameters")

            if currentTier == .premium {
                Text("You already have active Premium access.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "2A6A43"))
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var storeSection: some View {
        #if canImport(StoreKit)
        if #available(iOS 17.0, *) {
            SubscriptionStoreView(productIDs: productIDs)
                .storeButton(.visible, for: .restorePurchases)
                .storeButton(.hidden, for: .cancellation)
                .frame(minHeight: 420)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        } else {
            unsupportedStoreSection
        }
        #else
        unsupportedStoreSection
        #endif
    }

    private var unsupportedStoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("In-app purchase UI is unavailable in this environment.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "222222"))
            Text("Use a StoreKit-enabled iOS build to purchase Premium plans.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(hex: "5C6778"))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private var restoreButton: some View {
        Button {
            restorePurchases()
        } label: {
            HStack(spacing: 8) {
                if isRestoring {
                    ProgressView()
                        .tint(Color.white)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
                Text(isRestoring ? "Restoring..." : "Restore Purchases")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color(hex: "181818"))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isRestoring)
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(hex: "4A7D5F"))
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(hex: "111111"))
        }
    }

    @MainActor
    private func refreshEntitlementState() async {
        let snapshot = await SubscriptionEntitlementService.shared.refreshEntitlements(
            modelContainer: Persistence.sharedModelContainer,
            productIDs: Set(productIDs)
        )
        currentTier = snapshot.tier
        onEntitlementChanged?()
    }

    private func restorePurchases() {
        guard !isRestoring else { return }
        isRestoring = true

        Task { @MainActor in
            defer { isRestoring = false }
            do {
                let snapshot = try await SubscriptionEntitlementService.shared.restorePurchases(
                    modelContainer: Persistence.sharedModelContainer,
                    productIDs: Set(productIDs)
                )
                currentTier = snapshot.tier

                if snapshot.tier == .premium {
                    alertMessage = "Premium access restored successfully."
                    onEntitlementChanged?()
                } else {
                    alertMessage = "No active premium subscription was found for this Apple ID."
                }
            } catch {
                alertMessage = "Restore failed: \(error.localizedDescription)"
            }
            showingAlert = alertMessage != nil
        }
    }
}
