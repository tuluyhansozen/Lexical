#!/usr/bin/env python3
"""TDD tests for non-deterministic seed refactor pipeline."""

from __future__ import annotations

import unittest

from improve_seed_stochastic import (
    build_generation_prompt,
    clean_synonyms_conservative,
    is_sensitive_lemma,
    remap_roots_word_ids,
    resequence_rows,
    validate_sentence_set_quality,
)


class ImproveSeedStochasticTests(unittest.TestCase):
    def test_sensitive_lemma_detection(self) -> None:
        self.assertTrue(is_sensitive_lemma("suicide"))
        self.assertTrue(is_sensitive_lemma("RAPE"))
        self.assertFalse(is_sensitive_lemma("management"))

    def test_resequence_rows_and_id_map(self) -> None:
        rows = [
            {"id": 170, "lemma": "management"},
            {"id": 909, "lemma": "industrial"},
            {"id": 2188, "lemma": "versatile"},
        ]
        resequenced, id_map = resequence_rows(rows)

        self.assertEqual([row["id"] for row in resequenced], [1, 2, 3])
        self.assertEqual(id_map, {170: 1, 909: 2, 2188: 3})

    def test_root_remap_drops_removed_and_empty(self) -> None:
        roots = [
            {"root_id": 1, "root": "man", "basic_meaning": "hand", "word_ids": [170, 909]},
            {"root_id": 2, "root": "xyz", "basic_meaning": "x", "word_ids": [999999]},
        ]
        id_map = {170: 1, 909: 2}
        remapped = remap_roots_word_ids(roots, id_map)

        self.assertEqual(len(remapped), 1)
        self.assertEqual(remapped[0]["word_ids"], [1, 2])

    def test_synonym_cleanup_is_conservative(self) -> None:
        cleaned = clean_synonyms_conservative(
            synonyms=["mgmt.", "leadership", "E174", "the process of handling people", "executive team", "leadership"],
            lemma="management",
            pos="noun",
            max_count=6,
        )
        self.assertIn("leadership", cleaned)
        self.assertNotIn("E174", cleaned)
        self.assertNotIn("mgmt.", cleaned)
        self.assertEqual(len(cleaned), len(set(cleaned)))

    def test_sentence_set_quality_rejects_near_duplicates(self) -> None:
        sentences = [
            "The management reviewed the budget during a long meeting before launch.",
            "The management reviewed the budget during a long meeting before launch!",
            "After legal concerns surfaced, management paused the rollout and revised the timeline.",
        ]
        ok, reasons = validate_sentence_set_quality(
            sentences=sentences,
            lemma="management",
            near_dup_threshold=0.9,
        )
        self.assertFalse(ok)
        self.assertIn("near_duplicate_sentences", reasons)

    def test_generation_prompt_includes_quality_constraints(self) -> None:
        prompt = build_generation_prompt(
            lemma="management",
            definition="The activity of controlling and organizing a business and people.",
            pos="noun",
            cefr="B2",
            existing_synonyms=["administration", "leadership"],
            banned_terms=["slur1", "slur2"],
            recent_skeleton_hints=["subj VERB the lemma in a meeting"],
        )
        self.assertIn("Anti-patterns to avoid", prompt)
        self.assertIn("Generic templates to avoid", prompt)
        self.assertIn("weak: \"The management is important", prompt)
        self.assertIn("\"management\" as a standalone token", prompt)
        self.assertIn("Sense anchors", prompt)
        self.assertIn("controlling", prompt)
        self.assertIn("communicative job", prompt)


if __name__ == "__main__":
    unittest.main()
