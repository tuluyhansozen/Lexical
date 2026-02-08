# Repository Audit Report (Phase 0 + Phase 8 Alignment)

## Scope
This audit validates repository state against:
- `docs/project_implementation_plan.md`
- `.agent/tasks.json`
- `.agent/rules/*` and `.agent/skills/*` role/quality expectations

Audit run: **2026-02-07**.

## Findings

### ✅ Compliant Items
- **Phase 0 stabilization implemented:** platform-guarded imports and cross-platform glass abstraction are in place (`LexicalCore/Models/ReviewLog.swift`, `LexicalCore/DesignSystem/Colors.swift`, `LexicalCore/DesignSystem/GlassEffectContainer.swift`).
- **SwiftPM warning cleanup implemented:** executable target excludes now omit non-source files (`Package.swift`).
- **Swift 6 actor warning resolved:** `ArticleStore` no longer calls an actor-isolated method from initializer (`LexicalCore/Services/ArticleStore.swift`).
- **Build verification passed:** `xcodebuild -scheme Lexical -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e' build` reports `BUILD SUCCEEDED` on 2026-02-07.
- **Phase 8 personalization core present:** `InterestProfile`, `ArticleGenerator`, `ArticleConstraintsEvaluator`, `ArticleStore`, and `ArticleTemplateBank.json` are implemented and wired into feed/profile flows.
- **Navigation structure matches target app shape:** `ContentView` + `CustomTabBar` provide Feed/Explore/Practice/Stats/Profile tabs.

### ⚠️ Gaps & Risks
- **Target selection is still temporary:** article generation currently uses static `targetWords` in `HomeFeedView.triggerGeneration()` instead of FSRS-driven due/recent selection.
- **Production generation backend not wired:** `ArticleGenerator` defaults to `MockLLMProvider`; `RemoteArticleService` is present but not integrated as primary provider.
- **Stats fidelity incomplete:** `StatsView` period chips are currently visual-only and heatmap values are randomized each render.
- **Test coverage gap:** there are no focused tests yet for seeding idempotency/hash upgrades, article constraint validation behavior, or stats calculations.

## Recommendations
1. Connect article target selection to real FSRS state (`VocabularyItem` due/recent windows) and remove static demo values.
2. Promote `RemoteArticleService` (or equivalent provider abstraction) to production default with retry/backoff and failure fallback.
3. Complete Stats hardening by wiring period filters to query windows and replacing randomized heatmap with persisted review-activity bins.
4. Add Phase 0/8 regression tests for seeding idempotency, article quality constraints, and stats metrics.

## Notes
This audit is repository-level and build-level validation. It does not replace simulator walkthrough QA for end-to-end UX behavior.
