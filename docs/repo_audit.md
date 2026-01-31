# Repository Audit Report (Docs Compliance)

## Scope
This audit reviews repository structure and the Phase 4 Acquisition Engine implementation against the requirements described in the project documentation, with emphasis on the agent setup and immersive reader deliverables.

## Findings

### ✅ Compliant Items
- **Core skill files present:** The FSRS, reader, liquid glass UI, CRDT sync, and morphology skills are present under `.agent/skills/`.
- **Persona prompts present:** Architect, QA engineer, and senior iOS engineer rules exist under `.agent/rules/`.
- **Agent memory present:** `.agent/memory.md` exists and is populated.
- **Agent tasks present:** `.agent/tasks.json` exists and is untracked per `.gitignore`.
- **Phase 4 deliverables present:** `ReaderView`, `ReaderTextView`, `TokenizationActor`, `LemmaResolver`, and SwiftData models (`VocabularyItem`, `ReviewLog`, `MorphologicalRoot`) are present in the expected locations.
- **Reader highlight colors match spec:** Blue (#E3F2FD) and Yellow (#FFF9C4) highlights are implemented for new/learning states.

### ⚠️ Gaps & Risks
- **TextKit 2 integration gap:** The reader view uses `UITextView` with attributed text instead of TextKit 2 components (e.g., `NSTextLayoutManager`/`NSTextContentStorage`) as required in Phase 4. *(Deferred - not needed for current scope)
- **Lemma-to-surface mismatch risk:** Highlighting uses lemma keys against raw text substring matching, so inflected forms (e.g., “running” vs. “run”) may not be highlighted consistently. *(Fix in progress)
- **Filesystem MCP path mismatch:** `.agent/mcp_config.json` points the filesystem MCP server to `/Users/tuluyhan/projects/Lexical`, not the repo root `/workspace/Lexical`. *(Kept as-is - path does not exist locally)

## Recommendations
1. ~~Upgrade `ReaderTextView` to TextKit 2 primitives for consistent rendering and token-level interaction.~~ *(Deferred)*
2. ~~Adjust highlighting to map lemma states onto surface tokens (tokenization step) rather than direct substring matching.~~ *(Fix in progress)*
3. ~~Update `.agent/mcp_config.json` to point the filesystem MCP server at `/workspace/Lexical`.~~ *(N/A - path does not exist)*
4. ~~Create an empty `.agent/tasks.json` (and keep it untracked) to align with documented agent workflow.~~ *(Done)*

## Notes
This audit focuses on structural compliance and Phase 4 deliverables, not runtime behavior or UI/UX polish.
