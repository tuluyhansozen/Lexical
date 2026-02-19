#!/usr/bin/env python3
"""Tests for turbo deterministic sentence-improvement utilities."""

from __future__ import annotations

import unittest

from improve_sentences_inplace import (
    deterministic_review_item_once,
    enforce_sentence_generation,
    ensure_set_constraints,
    is_sampled_id,
    style_presence,
    verify_rows,
)
from tools.text_utils import validate_sentence


class TurboDeterministicTests(unittest.TestCase):
    def test_deterministic_review_marks_major_and_fatal(self) -> None:
        review = deterministic_review_item_once(
            lemma="management",
            definition="The executives of an organisation, especially senior executives.",
            sentences=[
                "Excellent time management helped her succeed in all facets of her life.",
                "The management approved a careful hiring freeze during the budget crisis.",
                "They improved planning during the crisis meeting yesterday.",
            ],
        )
        self.assertEqual(review[0]["severity"], "major")
        self.assertEqual(review[0]["action"], "REWRITE")
        self.assertIn("meaning_shift_fixed_expression", review[0]["reasons"])
        self.assertEqual(review[2]["severity"], "fatal")
        self.assertEqual(review[2]["action"], "REWRITE")
        self.assertIn("lemma_missing", review[2]["reasons"])

    def test_deterministic_generation_respects_style_and_constraints(self) -> None:
        text, errors = enforce_sentence_generation(
            idx=0,
            lemma="management",
            definition="The executives of an organisation, especially senior executives.",
            pos="noun",
            cefr="B2",
            style="question",
            review_rewrite="",
            current_texts=[],
            model="unused",
            ollama_url="unused",
            deterministic=True,
        )
        ok, reasons = validate_sentence(text, "management")
        self.assertTrue(ok, reasons)
        self.assertIn("?", text)
        self.assertTrue(any(token.startswith("deterministic_rewrite_") for token in errors))

    def test_ensure_set_constraints_produces_full_mix_in_deterministic_mode(self) -> None:
        texts = [
            "The management reviewed staffing during the long quarterly planning session.",
            "After lunch, management outlined new reporting goals for every team.",
            "By evening, management clarified responsibilities before the public update.",
        ]
        review = {
            0: {"rewrite": ""},
            1: {"rewrite": ""},
            2: {"rewrite": ""},
        }
        review_scores = {0: 10.0, 1: 20.0, 2: 30.0}
        rewritten_records: dict[int, dict[str, object]] = {}
        rewrite_indices = {0}
        error_log: list[str] = []

        final_texts, final_indices, _ = ensure_set_constraints(
            texts=texts,
            lemma="management",
            definition="The executives of an organisation, especially senior executives.",
            pos="noun",
            cefr="B2",
            review=review,
            review_scores=review_scores,
            rewritten_records=rewritten_records,
            rewrite_indices=rewrite_indices,
            model="unused",
            ollama_url="unused",
            error_log=error_log,
            deterministic=True,
        )
        mix = style_presence(final_texts)
        self.assertTrue(all(mix.values()))
        self.assertTrue(len(final_indices) >= 1)

    def test_sample_selector_is_stable(self) -> None:
        first = [row_id for row_id in range(1, 101) if is_sampled_id(row_id, 0.02)]
        second = [row_id for row_id in range(1, 101) if is_sampled_id(row_id, 0.02)]
        self.assertEqual(first, second)
        self.assertEqual(len(first), 2)

    def test_verify_rows_allows_missing_sentences_old_when_disabled(self) -> None:
        row = {
            "id": 1,
            "lemma": "management",
            "sentences": [
                {"text": "Although the management faced pressure, they kept the project stable all week.", "cloze_index": 2},
                {"text": '"The management agreed," she said, "to publish the timeline before noon."', "cloze_index": 2},
                {"text": "What management decision prevented another delay during the final release rehearsal?", "cloze_index": 1},
            ],
        }
        ok_no_old, errors_no_old = verify_rows([row], require_sentences_old=False)
        self.assertTrue(ok_no_old, errors_no_old)

        ok_require_old, errors_require_old = verify_rows([row], require_sentences_old=True)
        self.assertFalse(ok_require_old)
        self.assertTrue(any("missing_sentences_old" in token for token in errors_require_old))


if __name__ == "__main__":
    unittest.main()
