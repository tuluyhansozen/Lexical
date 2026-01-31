# Repository Audit Report (Docs Compliance)

## Scope
This audit reviews repository structure plus Phase 4 (Acquisition Engine) and Phase 5 (Retention Engine) implementations against the requirements described in the project documentation, with emphasis on agent setup, immersive reader deliverables, and the FSRS review loop.

## Findings

### ✅ Compliant Items
- **Core skill files present:** The FSRS, reader, liquid glass UI, CRDT sync, and morphology skills are present under `.agent/skills/`.
- **Persona prompts present:** Architect, QA engineer, and senior iOS engineer rules exist under `.agent/rules/`.
- **Agent memory present:** `.agent/memory.md` exists and is populated.
- **Agent tasks present:** `.agent/tasks.json` exists and is untracked per `.gitignore`.
- **Phase 4 deliverables present:** `ReaderView`, `ReaderTextView`, `TokenizationActor`, `LemmaResolver`, and SwiftData models (`VocabularyItem`, `ReviewLog`, `MorphologicalRoot`) are present in the expected locations.
- **Reader highlight colors match spec:** Blue (#E3F2FD) and Yellow (#FFF9C4) highlights are implemented for new/learning states.
- **Phase 5 flashcard UI present:** `FlashcardView` implements a two-sided card with cloze rendering and 3D flip animation.
- **Phase 5 grading controls present:** Review session UI shows four grading buttons (Again/Hard/Good/Easy) after flip.
- **Brain Boost queueing implemented:** `SessionManager` re-inserts failed cards into the current session queue with a fixed offset to enforce re-review.
- **FSRS state updates on pass:** Successful grades update stability/difficulty, schedule next review, and create a `ReviewLog` entry.

### ⚠️ Gaps & Risks
- **TextKit 2 integration gap:** The reader view uses `UITextView` with attributed text instead of TextKit 2 components (e.g., `NSTextLayoutManager`/`NSTextContentStorage`) as required in Phase 4. *(Deferred - not needed for current scope)
- **Lemma-to-surface mismatch risk:** Highlighting uses lemma keys against raw text substring matching, so inflected forms (e.g., “running” vs. “run”) may not be highlighted consistently. *(Fix in progress)
- **Filesystem MCP path mismatch:** `.agent/mcp_config.json` points the filesystem MCP server to `/Users/tuluyhan/projects/Lexical`, not the repo root `/workspace/Lexical`. *(Kept as-is - path does not exist locally)
- **Brain Boost graduation criteria missing:** The session loop promotes cards after a single Good/Easy; docs for the Brain Boost flow specify two consecutive “Good” ratings before graduating back to long-term scheduling.
- **Review logs skipped on failed grades:** `ReviewLog` entries are written only on pass, which undermines deterministic replay and auditability for failed attempts if logs are expected for every review event.
- **Grade semantics ambiguity:** `SessionManager` treats grades 1–2 as non-pass for session flow, while the FSRS engine logic treats grade 2 as a pass with penalty. This mismatch can lead to inconsistent modeling once grade-2 outcomes are persisted.

## Recommendations
1. ~~Upgrade `ReaderTextView` to TextKit 2 primitives for consistent rendering and token-level interaction.~~ *(Deferred)*
2. ~~Adjust highlighting to map lemma states onto surface tokens (tokenization step) rather than direct substring matching.~~ *(Fix in progress)*
3. ~~Update `.agent/mcp_config.json` to point the filesystem MCP server at `/workspace/Lexical`.~~ *(N/A - path does not exist)*
4. ~~Create an empty `.agent/tasks.json` (and keep it untracked) to align with documented agent workflow.~~ *(Done)*
5. Align Brain Boost graduation criteria with documented two-consecutive-Good requirement or update docs to match the current behavior.
6. Record `ReviewLog` entries for failed grades to preserve a complete event log for FSRS replay and auditability.
7. Normalize grade semantics between `SessionManager` and `FSRSV4Engine` so “Hard” is either consistently pass-or-fail across scheduling and logging.

## Notes
This audit focuses on structural compliance and Phase 4 deliverables, not runtime behavior or UI/UX polish.
