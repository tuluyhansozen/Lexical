# Full Repo Release-Readiness Review (Current Branch vs origin/main)

## Scope & Environment
- Date: 2026-02-20
- Workspace: `/Users/tuluyhan/projects/Lexical`
- Branch: `codex/review`
- HEAD: `1d4e1a3043d50280888a118ba7d8e243a134f302`
- `origin/main`: `1d4e1a3043d50280888a118ba7d8e243a134f302`
- Diff (`origin/main...HEAD`): none
- Lens: release readiness
- Depth: exhaustive (code, tests, docs, scripts, data, media)

## Execution Matrix
| Track | Command(s) | Result | Evidence |
|---|---|---|---|
| Preflight | `git status`, targeted fetch, SHA checks, diff checks, tracked-size scan | PASS | Clean status, fetch succeeded, no diff vs `origin/main` |
| A: Swift static + architecture risk | `rg -n "TODO|FIXME|fatalError\(|try!|as!|@MainActor|Task\{" ... -g '*.swift'` + targeted file reads | PASS (scan complete) | Found no `TODO/FIXME/try!/as!`; reviewed `fatalError` and force-unwrap callsites |
| B1: Simulator tests | `xcodebuild -scheme Lexical-Package -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e' -derivedDataPath build/derived_data test` | PASS | `/Users/tuluyhan/projects/Lexical/build/review_logs/track_b1_xcodebuild_test.log` (`** TEST SUCCEEDED **`, 100 tests, 0 failures) |
| B2: Simulator build | `xcodebuild -scheme Lexical -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e' -derivedDataPath build/derived_data build` | PASS | `/Users/tuluyhan/projects/Lexical/build/review_logs/track_b2_xcodebuild_build.log` (`** BUILD SUCCEEDED **`) |
| C1: Black-box E2E harness | `/Users/tuluyhan/projects/Lexical/scripts/e2e/run.sh` | FAIL | `/Users/tuluyhan/projects/Lexical/build/e2e_artifacts/20260220-190220/report.txt` (`Premium tier state set expected='premium' actual='free'`) |
| C2: True UI automation | `/Users/tuluyhan/projects/Lexical/scripts/ui_automation/run_true_ui.sh` | FAIL | `/Users/tuluyhan/projects/Lexical/build/ui_automation_artifacts/20260220-190335/report.txt` (`Timed out waiting for accessibility id: onboarding.skipButton`) |
| D1: Python unit tests | `python3 -m unittest discover -s tests -p 'test_*.py'` | PASS | 24 tests, 0 failures |
| D2: DB tooling unit tests | `PYTHONPATH=scripts/db python3 -m unittest discover -s scripts/db -p 'test_*.py'` | PASS | 13 tests, 0 failures |
| D3: Seed validator | `python3 scripts/validate_seed.py` | PASS | Reports 5328 entries, validator exits 0 |
| D4: Seed safety validator | `python3 scripts/db/validate_seed_safety.py --seed-path .../seed_data.json` | PASS | `Seed safety validation passed.` |
| D5: Seed cleanup dry-run | `python3 scripts/db/clean_seed_quality.py --seed-path ... --dry-run` | PASS | `sentence_cloze_repaired: 11440` |
| D6: Example refinement dry-run | `python3 scripts/db/refine_seed_examples.py --seed-path ... --dry-run` | PASS | `Rows rewritten: 6` |
| D7: Multiagent maintenance dry-run | `python3 scripts/db/multiagent_seed_maintenance.py --seed-path ... --dry-run --workers 4 --report-path build/seed_maintenance_report.json` | PASS (high delta) | `/Users/tuluyhan/projects/Lexical/build/seed_maintenance_report.json`: `rows_updated=4530/5328` (85%) |
| E: Docs/plan/artifact checks | targeted `rg` + file existence + large-tracked scan | PASS (with findings below) | Key plan files exist; large artifacts present and tracked |

## Findings (P0-P3)

### P0
- No P0 findings.

### P1
1. **E2E premium-gate assertion is invalidated by bootstrap side effects**
   - Files: `/Users/tuluyhan/projects/Lexical/scripts/e2e/run.sh:96`, `/Users/tuluyhan/projects/Lexical/scripts/e2e/run.sh:262`, `/Users/tuluyhan/projects/Lexical/Lexical/LexicalApp.swift:92`, `/Users/tuluyhan/projects/Lexical/LexicalCore/Services/SubscriptionEntitlementService.swift:378`
   - Evidence:
     - Harness fails in `/Users/tuluyhan/projects/Lexical/build/e2e_artifacts/20260220-190220/report.txt`: `Premium tier state set (expected='premium' actual='free')`.
     - `launch_app` in the harness launches without `--lexical-e2e-no-bootstrap` (`scripts/e2e/run.sh:96-103`), so app bootstrap runs (`LexicalApp.swift:92-100`) and refreshes entitlements from StoreKit to `.free` when no active transactions (`SubscriptionEntitlementService.swift:378`).
     - Direct repro in this run: `before_launch=premium`, `after_plain_launch=free`, `after_no_bootstrap_launch=premium`.
   - User impact:
     - Critical monetization E2E signal is unreliable (false failures or masked real regressions depending on ordering).
   - Minimal remediation:
     - Update E2E harness launches used for DB-state assertions to include `--lexical-e2e-no-bootstrap` (and preferably `--lexical-ui-tests` for consistent test-mode behavior), or route state setup entirely through `E2ETestLaunchConfigurator`.
   - Confidence: high

2. **True-UI onboarding skip flow is stale against current product behavior**
   - Files: `/Users/tuluyhan/projects/Lexical/scripts/ui_automation/run_true_ui.sh:197`, `/Users/tuluyhan/projects/Lexical/scripts/ui_automation/run_true_ui.sh:207`, `/Users/tuluyhan/projects/Lexical/Lexical/Features/Onboarding/OnboardingFlowView.swift:95`, `/Users/tuluyhan/projects/Lexical/Lexical/Features/Onboarding/OnboardingFlowView.swift:983`, `/Users/tuluyhan/projects/Lexical/LexicalTests/OnboardingProgressGateTests.swift:30`
   - Evidence:
     - Harness fails in `/Users/tuluyhan/projects/Lexical/build/ui_automation_artifacts/20260220-190335/report.txt`: timed out on `onboarding.skipButton`.
     - Test expects `onboarding.skipButton` on first onboarding screen (`run_true_ui.sh:197`) and taps it (`run_true_ui.sh:207`).
     - UI now renders Skip only when `canShowSkip` is true (`OnboardingFlowView.swift:95`), and `canSkip` explicitly requires completed calibration (`OnboardingFlowView.swift:983`).
     - Unit test confirms this contract (`OnboardingProgressGateTests.swift:30-38`).
     - Runtime UI-tree probe during this run showed onboarding IDs present except `onboarding.skipButton`.
   - User impact:
     - Core onboarding true-UI regression coverage fails at step 1, reducing confidence in onboarding/readiness automation.
   - Minimal remediation:
     - Rewrite onboarding automation to either complete calibration before skip assertions or replace skip-path assumptions with primary-button progression for current gating behavior.
   - Confidence: high

### P2
1. **Content-quality gates are materially weaker than maintenance diagnostics**
   - Files: `/Users/tuluyhan/projects/Lexical/scripts/validate_seed.py:108`, `/Users/tuluyhan/projects/Lexical/build/seed_maintenance_report.json`
   - Evidence:
     - `scripts/validate_seed.py` passes even though only missing-definition and high-missing-IPA thresholds can fail (`validate_seed.py:108-113`).
     - Same run’s maintenance dry-run indicates large-scale quality debt: `rows_updated=4530/5328` (85%) in `/Users/tuluyhan/projects/Lexical/build/seed_maintenance_report.json`.
     - Additional dry-run diagnostics reported heavy cloze repairs (`sentence_cloze_repaired: 11440`).
   - User impact:
     - Release can appear “green” while substantial content quality issues remain in shipped seed data.
   - Minimal remediation:
     - Expand release gate criteria to include sentence/collocation/cloze quality thresholds and fail when rewrite percentage exceeds a defined ceiling.
   - Confidence: medium

### P3
1. **Tracked Python bytecode artifacts in repository**
   - Files: `/Users/tuluyhan/projects/Lexical/scripts/__pycache__/generate_seed_json.cpython-313.pyc`, `/Users/tuluyhan/projects/Lexical/scripts/__pycache__/seed_builder.cpython-313.pyc`, `/Users/tuluyhan/projects/Lexical/scripts/db/__pycache__/import_extra_words.cpython-313.pyc`, `/Users/tuluyhan/projects/Lexical/scripts/db/__pycache__/norvig_ranking.cpython-313.pyc`
   - Evidence:
     - `git ls-files '*__pycache__*'` returns tracked `.pyc` files.
   - User impact:
     - Repository noise and unnecessary binary churn across Python-version changes.
   - Minimal remediation:
     - Remove tracked `.pyc` files and ensure `__pycache__/` and `*.pyc` are ignored.
   - Confidence: high

2. **README testing guidance remains incomplete relative to known simulator-only policy**
   - Files: `/Users/tuluyhan/projects/Lexical/docs/repo_audit.md:30`, `/Users/tuluyhan/projects/Lexical/README.md`
   - Evidence:
     - Audit recommendation explicitly calls for documenting `swift test` limitation in README (`repo_audit.md:30`).
     - Current README is focused on seed-sentence tooling and does not provide project test-entry guidance for `xcodebuild` simulator path.
   - User impact:
     - Contributors can choose incorrect test commands, reducing reproducibility.
   - Minimal remediation:
     - Add a concise “Project verification” section in README with canonical simulator `xcodebuild` commands and `swift test` caveat.
   - Confidence: medium

## Confidence Gaps
- Physical-device validation was not part of this run (simulator-only verification).
- No TestFlight/App Store sandbox purchase-flow exercise in this pass; monetization findings are based on simulator + local harness behavior.
- Data-quality finding is based on dry-run diagnostics and gating logic; it does not prove every suggested row rewrite is objectively required.

## Recommended Remediation Order
1. Fix `scripts/e2e/run.sh` launch flags/state strategy to prevent entitlement bootstrap from overwriting asserted premium/free state.
2. Update `scripts/ui_automation/run_true_ui.sh` onboarding flows to align with current calibration-gated skip behavior.
3. Define and enforce stronger seed-quality release gates (promote dry-run diagnostics into fail conditions where appropriate).
4. Clean tracked Python bytecode artifacts and reinforce ignore rules.
5. Update README test-entry instructions to match simulator-first validation policy.
