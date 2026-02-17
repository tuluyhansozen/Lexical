# Phase 10C StoreKit Exit Checks

> **Date:** 2026-02-16  
> **Scope:** Free/Premium entitlement lifecycle validation for StoreKit 2 rollout  
> **Build/Test Command:** `xcodebuild -scheme Lexical-Package -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test`

## Verification Matrix

| Scenario | Coverage Type | Evidence |
|---|---|---|
| Purchase success promotes to premium and persists durable entitlement state | Automated (unit) | `SubscriptionEntitlementServiceTests.testPurchaseFinishesTransactionAfterEntitlementPersistence` |
| Purchase pending returns pending without mutating tier | Automated (unit) | `SubscriptionEntitlementServiceTests.testPurchasePendingReturnsPendingWithoutTierMutation` |
| User-cancelled purchase returns cancellation without mutating tier | Automated (unit) | `SubscriptionEntitlementServiceTests.testPurchaseUserCancelledReturnsCancelledWithoutTierMutation` |
| Restore purchases invokes `AppStore.sync()` path | Automated (unit) | `SubscriptionEntitlementServiceTests.testRestorePurchasesCallsAppStoreSync` |
| Expired entitlement downgrades to free and standard FSRS mode | Automated (unit) | `SubscriptionEntitlementServiceTests.testRefreshDowngradesUserWhenEntitlementExpired` |
| Billing retry + active grace window preserves premium access | Automated (unit) | `SubscriptionEntitlementServiceTests.testBillingRetryWithActiveGraceKeepsPremium` |
| Offline continuity uses cached entitlement snapshot when StoreKit products are unavailable | Automated (unit) | `SubscriptionEntitlementServiceTests.testOfflineRefreshFallsBackToCachedPremiumEntitlement` |
| Entitlement merge behavior is deterministic and convergent across devices | Automated (unit) | `SyncConflictResolverTests` suite |
| Free/Premium capability enforcement for article quota/widget cap/fsrs mode | Automated (unit) | `FeatureGateServiceTests` suite |

## Result

- Exit-check scenarios are covered in automated tests and pass on simulator toolchain.
- Premium merchandising surface and restore entry points are wired in:
  - `Lexical/Features/Monetization/PremiumOfferView.swift`
  - `Lexical/Features/Home/HomeFeedView.swift`
  - `Lexical/Features/Settings/SettingsView.swift`
- Local StoreKit catalog is present for deterministic simulator validation:
  - `Lexical/Resources/StoreKit/Lexical.storekit`
