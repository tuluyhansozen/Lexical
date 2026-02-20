#!/usr/bin/env python3
"""Unit tests for deterministic text utility behavior."""

from __future__ import annotations

import unittest

from tools.text_utils import (
    find_cloze_index,
    has_near_duplicates,
    pairwise_similarity,
    sentence_skeleton,
    tokenize,
    validate_sentence,
    validate_set,
    wordlike_count,
)


class TextUtilsTests(unittest.TestCase):
    def test_tokenize_handles_punctuation(self) -> None:
        tokens = tokenize("Wait, really?")
        self.assertEqual(tokens, ["Wait", ",", "really", "?"])

    def test_tokenize_keeps_apostrophes(self) -> None:
        tokens = tokenize("She's sure it's done.")
        self.assertIn("She's", tokens)
        self.assertIn("it's", tokens)
        self.assertEqual(wordlike_count(tokens), 4)

    def test_find_cloze_exact_token(self) -> None:
        text = "Their ways differ, but one way worked yesterday."
        self.assertEqual(find_cloze_index(text, "way"), 6)
        self.assertIsNone(find_cloze_index(text, "wayss"))

    def test_validate_sentence_ok(self) -> None:
        ok, reasons = validate_sentence(
            "During the long commute, one way saved me from another missed transfer.",
            "way",
        )
        self.assertTrue(ok)
        self.assertEqual(reasons, [])

    def test_validate_sentence_missing_lemma(self) -> None:
        ok, reasons = validate_sentence(
            "During the long commute, a route saved me from another missed transfer.",
            "way",
        )
        self.assertFalse(ok)
        self.assertIn("lemma_missing", reasons)

    def test_validate_sentence_too_short(self) -> None:
        ok, reasons = validate_sentence("This way helps.", "way")
        self.assertFalse(ok)
        self.assertIn("word_count_lt_8", reasons)

    def test_validate_sentence_too_long(self) -> None:
        text = (
            "One way seemed workable until the delayed train, flooded station, confused updates, "
            "rerouted buses, staff shortages, broken ticket kiosks, missed alerts, and repeated platform changes "
            "ruined every backup plan we had carefully prepared."
        )
        ok, reasons = validate_sentence(text, "way")
        self.assertFalse(ok)
        self.assertIn("word_count_gt_14", reasons)

    def test_validate_set_fails_same_start(self) -> None:
        ok, reasons = validate_set(
            [
                'When the way changed, "we adapted overnight," she said.',
                "When the way looked risky, we paused because legal requested edits.",
                "When one way failed, what way should we test next?",
            ]
        )
        self.assertFalse(ok)
        self.assertIn("set_all_same_start_token", reasons)

    def test_validate_set_fails_same_punctuation_pattern(self) -> None:
        ok, reasons = validate_set(
            [
                "A careful way reduced rework during the long release review.",
                "A different way avoided conflict during the tense planning meeting.",
                "A backup way protected data during the overnight migration window.",
            ]
        )
        self.assertFalse(ok)
        self.assertIn("set_all_same_punctuation_pattern", reasons)

    def test_validate_set_fails_without_question_dialogue_complex(self) -> None:
        ok, reasons = validate_set(
            [
                "Yesterday our way prevented panic amid the server migration drill downtown.",
                "Tonight that way protected revenue amid a messy billing incident downtown.",
                "Later this way restored trust across another delayed product launch cycle.",
            ]
        )
        self.assertFalse(ok)
        self.assertIn("set_missing_question_or_dialogue_or_complex", reasons)

    def test_validate_set_passes_with_mix(self) -> None:
        ok, reasons = validate_set(
            [
                "When this way failed at dawn, what way should we test first?",
                '"That way bought us time," she said, "while the database recovered."',
                "Although one way seemed faster, a slower way avoided another outage.",
            ]
        )
        self.assertTrue(ok)
        self.assertEqual(reasons, [])

    def test_sentence_skeleton_replaces_lemma_token(self) -> None:
        text = "When management changed suddenly, management had to explain the decision twice."
        skeleton = sentence_skeleton(text, "management")
        self.assertIn("{LEMMA}", skeleton)
        self.assertNotIn("management", skeleton.lower())

    def test_pairwise_similarity_and_near_duplicates(self) -> None:
        a = "The manager revised the plan after legal concerns appeared."
        b = "The manager revised the plan after legal concerns appeared!"
        c = "After the outage, the team documented causes and updated the runbook."
        self.assertGreater(pairwise_similarity(a, b), 0.9)
        self.assertTrue(has_near_duplicates([a, b, c], threshold=0.9))


if __name__ == "__main__":
    unittest.main()
