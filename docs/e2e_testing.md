# Lexical End-to-End (E2E) Test Harnesses

## True UI Automation (recommended)

```bash
scripts/ui_automation/run_true_ui.sh
```

This runner uses `idb ui` to perform real UI actions (tap + accessibility tree assertions) on the simulator.

### 5 automated flows

1. `onboarding_visible`: fresh launch shows onboarding welcome.
2. `onboarding_skip_to_reading`: taps Skip, then Start Learning, lands on Reading.
3. `free_limit_state`: verifies free quota (`0/1`) and upgrade CTA.
4. `premium_state`: verifies unlimited quota and generate CTA.
5. `prompt_route_open_and_close`: opens prompt card then closes back to Review.

### Artifacts

- Screenshots and logs are written to:

```text
build/ui_automation_artifacts/<timestamp>/
```

Key files:
- `report.txt`
- `build.log`
- `01_onboarding_visible.png`
- `02_onboarding_skip_to_reading.png`
- `03_free_limit_state.png`
- `04_premium_unlimited_state.png`
- `05_prompt_open.png`
- `06_prompt_closed_to_review.png`

### Requirements

- `idb` must be installed and able to connect to the target simulator companion.
- `jq` is used to parse accessibility-tree JSON.

## Black-box Harness (legacy)

```bash
scripts/e2e/run.sh
```

This harness uses `simctl` + SQLite/plist assertions + screenshots.

### What it verifies

1. Fresh install starts with onboarding gate active.
2. Onboarding completion flag persists and app enters main shell.
3. Free tier state and weekly article quota state can be enforced end-to-end.
4. Premium tier + personalized FSRS mode state can be enforced end-to-end.
5. Pending prompt deep-link state is consumed on launch.

## Notes

- `XCUIApplication`-based tests require an Xcode UI test bundle target; SwiftPM unit-test bundles cannot host those directly.
- The `idb` runner is therefore the practical true UI automation path for this repo layout.
- Simulator target defaults to:
  - `98FACCED-3F83-4A94-8D7B-F8905AAF08D1`
