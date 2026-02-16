# Repository Review Report

Date: 2026-02-16
Reviewer scope: full repo static audit + docs alignment + test run

## Findings (ordered by severity)

1. **[Critical] Unsafe vocabulary examples are currently shippable and user-visible**
- Evidence:
  - `Lexical/Resources/Seeds/seed_data.json:24` contains explicit sexual phrasing.
  - `Lexical/Resources/Seeds/seed_data.json:35473` contains spam/scam-style wording.
  - `Lexical/Resources/Seeds/seed_data.json:69808` contains unnatural/unsuitable sentence quality.
  - Your own enrichment contract requires safe content: `scripts/db/prepare_batch_enrichment.py:189` and `scripts/db/prepare_batch_enrichment.py:217`.
- Risk: content safety and trust issues in Reader/Word Detail; potential App Store review risk for educational audience positioning.
- Recommendation: run a hard profanity/toxicity/safety filter pass over `seed_data.json` before shipping, plus CI validation to block unsafe lines.

2. **[High] Review session can schedule non-due words, corrupting FSRS signal quality**
- Evidence:
  - `Lexical/Features/Review/SessionManager.swift:43` falls back to all words when due queue is empty.
  - `Lexical/Features/Review/SessionManager.swift:49` enqueues up to 20 non-due items.
- Risk: users with no due cards still generate review writes, which can distort scheduling, retention analytics, and streak interpretation.
- Recommendation: when no due cards exist, show a true “no due cards” state; if optional extra practice is desired, keep it explicitly labeled and excluded from FSRS writes/stat retention metrics.

3. **[High] First word-detail open performs large synchronous JSON decode on UI path**
- Evidence:
  - `Lexical/Features/Review/WordDetailSheet.swift:150` + `Lexical/Features/Review/WordDetailSheet.swift:153` load/decode the full seed file.
  - Called directly from interaction paths: `Lexical/Features/Reader/ReaderView.swift:172` and `Lexical/Features/Review/ReviewSessionView.swift:88`.
- Context7 cross-check: SwiftData `mainContext` is main-actor-bound; heavy work on UI-bound paths should be avoided.
  - https://developer.apple.com/documentation/swiftdata/modelcontainer/maincontext
  - https://developer.apple.com/documentation/swiftdata/modelcontext
- Risk: visible hitch/jank on first tap; memory pressure spikes with large seed DB.
- Recommendation: prebuild and persist a compact lookup index at seed time (or lazy background actor cache), then query only needed lemma rows.

4. **[Medium] Free/Premium monetization plan is documented as active but core StoreKit implementation is still missing**
- Evidence:
  - Plan marks StoreKit phase active: `docs/project_implementation_plan.md:410`.
  - Core deliverables still unchecked/missing: `docs/project_implementation_plan.md:439`, `docs/project_implementation_plan.md:444`, `docs/project_implementation_plan.md:445`.
  - Missing files in repo: `LexicalCore/Services/SubscriptionEntitlementService.swift`, `Lexical/Features/Monetization/PremiumOfferView.swift`, `Lexical/Resources/StoreKit/Lexical.storekit`, `LexicalCoreTests/SubscriptionEntitlementServiceTests.swift`.
- Context7 cross-check (StoreKit 2): verified transactions, `Transaction.updates`, and user-triggered `AppStore.sync()` restore are core best-practice paths.
  - https://developer.apple.com/documentation/StoreKit/Transaction/updates
  - https://developer.apple.com/documentation/StoreKit/AppStore/sync()
- Risk: entitlement state can drift from real App Store status; monetization is not production-ready.
- Recommendation: implement a single entitlement service and gate all premium checks through it.

5. **[Medium] Quota failure path can still continue article generation after gate-check error**
- Evidence:
  - Gate check error is swallowed: `Lexical/Features/Home/HomeFeedView.swift:264`.
  - Flow continues to generation after catch block: `Lexical/Features/Home/HomeFeedView.swift:268`.
- Risk: transient data errors can bypass intended quota UX and create inconsistent entitlement behavior.
- Recommendation: fail closed on gate-check errors (show unavailable alert and return), with telemetry.

6. **[Medium] Premium word-plan sizing ignores entitlement expiry-aware tier resolution**
- Evidence:
  - Uses raw tier check: `Lexical/Features/Home/HomeFeedView.swift:269`.
  - `FeatureGateService` has expiry-aware tier logic, but it is bypassed here.
- Risk: expired premium users can still receive premium targeting mix in generation setup.
- Recommendation: derive premium behavior from `FeatureGateService` snapshot/result only.

7. **[Medium] Review progress UI is placeholder logic, not real progress**
- Evidence:
  - Progress inputs are non-semantic: `Lexical/Features/Review/ReviewSessionView.swift:68`.
  - Bar fill is hardcoded 50%: `Lexical/Features/Review/ReviewSessionView.swift:190`.
- Risk: misleading feedback during sessions, poor UX trust.
- Recommendation: compute progress from `completedCount / initialCount` and remove placeholder denominator.

8. **[Low] Dark mode setting is currently non-functional due to forced light scheme**
- Evidence:
  - Toggle exists: `Lexical/Features/Settings/SettingsView.swift:171`.
  - App forces light mode globally: `Lexical/ContentView.swift:83`.
- Risk: user setting mismatch and accessibility regression for low-light users.
- Recommendation: bind `preferredColorScheme` to saved setting, or remove toggle until implemented.

9. **[Low] Multiple hot paths still use full-table fetches + in-memory filtering**
- Evidence:
  - `LexicalCore/Services/LemmaResolver.swift:39`
  - `Lexical/Features/Reader/ReaderView.swift:283`
  - `LexicalCore/Services/CloudKitSyncManager.swift:216`
- Risk: scalability issues as user data grows (latency, battery, memory).
- Recommendation: use predicate-based fetches keyed by user/lemma subsets and incremental syncing.

## Open Questions / Assumptions

1. Is “practice when no due cards exist” an intentional product mode? If yes, should it be explicitly separated from FSRS-scored reviews?
2. Is the current seed corpus considered temporary for local simulation only, or intended for production app bundles?
3. Should onboarding’s Dark Mode toggle be functional in this release or hidden until implemented?

## Verification Executed

- Full core test suite:
  - `xcodebuild -scheme Lexical-Package -destination 'platform=iOS Simulator,name=iPhone 16e' -derivedDataPath build/derived_data test`
  - Result: **49 tests passed, 0 failed**.
- Static scans:
  - unsafe patterns (`try!`, `fatalError`, placeholder logic)
  - monetization/gating paths
  - docs-plan vs code artifact presence

## Summary

Core architecture and test health are strong, but there are four high-impact blockers before production hardening: unsafe seed content, non-due review fallback behavior, word-detail UI-path JSON loading, and incomplete StoreKit entitlement implementation.
