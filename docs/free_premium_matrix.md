# Lexical Free vs Premium Matrix

> **Created:** 2026-02-11
> **Owner:** Product + Engineering
> **Status:** Ratified baseline for Phase 10C

## Product Principles
- Core learning loop stays accessible on Free.
- Premium monetizes acceleration, scale, and personalization.
- Tier gates must be deterministic, transparent, and testable.

## Locked Tier Decisions

| Capability | Free | Premium | Enforcement Notes |
|---|---|---|---|
| AI Article Generation | 1 generated article per 7-day window | Unlimited | Track usage in a weekly entitlement ledger keyed by user + week window. |
| Widgets | 1 active widget profile at a time | Unlimited widget profiles | In Free tier, all widget instances resolve to one shared active profile. |
| FSRS Parameter Mode | Standard FSRS parameter set (global defaults) | Personalized FSRS parameter set (user-specific) | Personalized parameters require per-user model state + fallback to defaults when insufficient data. |

## Suggested Additions (Recommended)
- Keep reviews and due-card study sessions unlimited in Free so retention outcomes are not paywalled.
- Put premium focus on content scale and adaptive intelligence, not on basic recall execution.
- Add Premium grace handling during billing retry/grace period to avoid abrupt user lockouts.
- Use a clear in-app usage meter for Free limits (e.g., "0/1 weekly article remaining").

## StoreKit 2 Best-Practice Rules
- Use one subscription group for premium tiers to support clean upgrade/downgrade paths.
- Compute access only from verified StoreKit transactions.
- Observe `Transaction.updates` continuously while app is running.
- Bootstrap entitlement at launch from current entitlements before rendering gated surfaces.
- Call `transaction.finish()` only after durable entitlement processing is completed.
- Provide `Restore Purchases` and call `AppStore.sync()` only from explicit user action.

## Data Model and Gate Contracts

### User Profile Fields (Phase 10C)
- `subscriptionTier`: `free | premium`
- `entitlementSource`: `app_store | local_cache`
- `entitlementUpdatedAt`: `Date`
- `entitlementExpiresAt`: `Date?`
- `fsrsParameterMode`: `standard | personalized`

### Usage Ledger Fields
- `articleWindowStart`: `Date` (7-day window anchor)
- `articlesGeneratedInWindow`: `Int`
- `activeWidgetProfileCount`: `Int` (free cap = 1)

### Feature Gate API (single source of truth)
- `canGenerateArticle(now:) -> Bool`
- `canCreateAdditionalWidgetProfile(currentCount:) -> Bool`
- `activeFSRSMode() -> FSRSParameterMode`

## Acceptance Criteria for Tier Rules
- Free user cannot generate a second article within the same 7-day window.
- Premium user can generate articles without quota enforcement.
- Free user can only maintain one active widget profile at any time.
- Premium user has no widget profile cap.
- Free review scheduling always uses standard FSRS parameters.
- Premium review scheduling uses personalized FSRS parameters when available; otherwise uses standard parameters until readiness threshold is met.

## Rollout Notes
- Start with serverless/offline-safe enforcement on device using local entitlement snapshot.
- Sync entitlement and usage metadata through existing CloudKit + resolver flows for cross-device consistency.
- Add telemetry for article-quota hits, paywall impressions, purchase success, restore success, and entitlement downgrade reasons.
