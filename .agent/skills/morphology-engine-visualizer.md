# Skill: Morphology Engine Visualizer

## Description
This skill covers the morphology analysis engine and its visualization, focusing on etymology, root graphs, and explainable word families.

## 1. Data Modeling
- **Entities:** `Morpheme`, `WordForm`, `WordFamilyEdge`.
- **Uniqueness:** Enforce unique IDs per morpheme and lemma.
- **Relationships:**
  - `Morpheme` -> `WordForm` (many-to-many).
  - `WordForm` -> `WordFamilyEdge` (graph edges for derivations).

## 2. Graph Construction
- **Graph Type:** Force-directed or hierarchical graph.
- **Edge Semantics:**
  - Derivation (e.g., *spect* -> *inspect*).
  - Affixation (prefix/suffix rules).
- **Layout Constraints:**
  - Keep root morphemes centered.
  - Minimize crossings for readability.

## 3. UX & Interaction
- **Exploration:** Tap a node to reveal examples, definitions, and related roots.
- **Learning Flow:** Allow users to add all derivations to a study session from the graph.
- **Accessibility:** Provide a non-graph list mode when Reduce Motion is enabled.

## 4. Performance Guidelines
- **Chunking:** Load graph nodes in batches for large word families.
- **Caching:** Cache layout positions to avoid re-running physics on every load.
- **Background Work:** Build graphs off the main thread; only apply layout on main.

## 5. Do Not Use When
- Implementing FSRS scheduling logic.
- Handling TextKit 2 rendering or reader highlights.
