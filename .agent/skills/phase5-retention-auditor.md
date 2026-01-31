# Skill: Phase 5 Retention Engine Auditor

## Description
Audit Phase 5 retention-loop work against documented requirements, focusing on flashcard UI, grading semantics, FSRS updates, and Brain Boost behavior.

## 1. Audit Focus
- **Phase 5 Deliverables:** FlashcardView, ReviewSessionView, SessionManager, FSRSV4Engine.
- **Recall Dominance:** Verify grading controls appear only after recall attempt (flip).
- **Brain Boost:** Confirm failed cards are re-queued within the session and do not advance prematurely.

## 2. Evidence Checklist
- **3D Flip & Cloze:** Verify the front/back card display and cloze text replacement.
- **Four-Button Grades:** Ensure Again/Hard/Good/Easy map to numeric grades consistently.
- **FSRS State Updates:** Confirm stability/difficulty updates and next review date are persisted on successful recall.
- **Review Logs:** Ensure immutable logs are created per review event (including fails if required by docs).

## 3. Reporting Standards
- **Compliant Items:** Provide file-level evidence and alignment with docs.
- **Gaps & Risks:** Call out mismatched grade semantics or missing Brain Boost graduation criteria.
- **Recommendations:** Suggest targeted fixes aligned with the project plan.

## 4. Non-Goals
- Do not redesign UI styles unless required by documentation.
- Do not change algorithm math unless it deviates from documented FSRS requirements.
