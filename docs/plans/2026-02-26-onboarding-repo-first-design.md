# Onboarding Repo-First Hybrid Design

## Goal
Refine Lexical onboarding so the visual and interaction language comes primarily from `tuluyhansozen/Multisteponboardingflow`, while preserving Lexical-specific progression logic, calibration gate, premium entitlement handling, and data persistence.

## Source Baselines
- Reference UI source (primary): `/tmp/multistep_onboarding_ref/src/app/components/onboarding/*`
- Lexical onboarding source (integration target): `Lexical/Features/Onboarding/*`

## Context7 Guardrails (Apple HIG)
- Value-first onboarding and brief prerequisite flow before monetization.
- Permission prompts should be contextual and justified in-step.
- Subscription onboarding should include clear benefits, pricing clarity via StoreKit, restore path, and legal links.

References:
- https://developer.apple.com/design/human-interface-guidelines/onboarding
- https://developer.apple.com/design/human-interface-guidelines/privacy
- https://developer.apple.com/design/human-interface-guidelines/in-app-purchase

## Hybrid Scope Definition
- Repo-first parity for shell, spacing rhythm, motion timing, card treatments, chips, and CTA styling.
- Lexical-preserved behavior for:
  - mandatory rank calibration before skip/finish
  - existing onboarding storage and migration
  - StoreKit entitlement refresh and restore
  - free path and premium path routing
  - existing automation accessibility IDs

## Visual System Mapping
- Background: `#f5f5f7`
- Accent: `#144932`
- Neutral text hierarchy mirrored from repo (`#0a0a0a`, `#525252`, `#8e8e93`).
- Primary button parity:
  - height 48
  - radius 14
  - pressed scale micro-interaction
  - disabled tint `#144932` with lower opacity
- Card parity:
  - default: translucent white card + thin border + soft shadow
  - selected: accent-tinted fill and accent border
- Progress parity:
  - 4px rounded track (`#bcbcbc`) and animated accent fill

## Interaction Parity Plan
- Coordinator parity:
  - same header row geometry, back/skip locations, progress placement
  - horizontal step transitions around 0.35s
- Step parity:
  - Welcome: centered icon + feature pills + floating-label name input
  - FSRS: interactive grade demo and interval feedback state
  - Rank calibration: stacked-card feel + compact progress chips + required completion
  - Interests: chips with inline custom entry
  - Style: selectable cards with radio affordance
  - Reading primer: tappable highlighted lexeme + sheet reveal
  - Notifications: soft ask + schedule preview + defer option
  - Premium (Lexical-only extension): inserted before completion, same visual style as repo steps
  - Completion: summary card rows and success emphasis

## Premium Step Design Rules
- Keep premium step visually aligned to repo style, not legacy Lexical style blocks.
- Keep Lexical product logic and copy constraints:
  - StoreKit `SubscriptionStoreView`
  - restore button
  - `Continue with Free` always visible
  - terms/privacy links from Info.plist when present
  - auto-advance to completion on premium entitlement

## Accessibility and Automation Contracts
- Preserve existing IDs that automation depends on.
- Keep required IDs:
  - `onboarding.progressBar`
  - `onboarding.premiumHeadline`
  - `onboarding.continueFreeButton`
  - `onboarding.completionHeadline`
- Keep button labels expected by automation:
  - `Get Started`
  - `Continue`
  - `Continue with Free`
  - `Start Learning`

## Verification Strategy
- Unit tests:
  - `OnboardingFlowModelTests`
  - `OnboardingProgressGateTests`
- Build:
  - iOS simulator scheme build
- UI automation:
  - `scripts/ui_automation/run_true_ui.sh`
- Canvas verification:
  - welcome, premium, completion preview variants for rapid visual parity checks

## Risks and Mitigations
- Risk: overfitting parity and breaking Lexical gating.
  - Mitigation: treat logic layer as fixed; only swap presentation and interaction scaffolding.
- Risk: premium surface drifting from HIG terms clarity.
  - Mitigation: keep legal links, restore, and StoreKit-native pricing/confirmation.
- Risk: automation breakage from text or ID drift.
  - Mitigation: keep identifiers and expected CTA strings stable.
