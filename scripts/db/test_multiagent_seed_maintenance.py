#!/usr/bin/env python3
import unittest

from import_extra_words import cloze_index_for
from multiagent_seed_maintenance import (
    SentenceAgent,
    SynonymAgent,
    run_multiagent_batch,
)


class MultiagentSeedMaintenanceTests(unittest.TestCase):
    def test_sentence_agent_detects_near_duplicate_and_rewrites(self) -> None:
        row = {
            "id": 2624,
            "lemma": "demonstrate",
            "cefr": "B2",
            "pos": "verb",
            "definition": "To show how to use something.",
            "synonym": [],
            "sentences": [
                {
                    "text": "I don't know how to demonstrate it, since it's too obvious!",
                    "cloze_index": 5,
                },
                {
                    "text": "I'll demonstrate this with the help of a few concrete examples.",
                    "cloze_index": 1,
                },
                {
                    "text": "I'll demonstrate that with the help of a few concrete examples.",
                    "cloze_index": 1,
                },
            ],
        }
        finding = SentenceAgent(duplicate_threshold=0.92).evaluate(row)
        self.assertTrue(finding.needs_update)
        self.assertIn("near_duplicate_sentences", finding.issues)
        self.assertEqual(len(finding.updates["sentences"]), 3)

        rewritten_texts = [item["text"].lower() for item in finding.updates["sentences"]]
        self.assertEqual(len(rewritten_texts), len(set(rewritten_texts)))

    def test_synonym_agent_filters_invalid_and_duplicates(self) -> None:
        row = {
            "id": 1,
            "lemma": "demonstrate",
            "synonym": ["show", "Show", "demonstrate", "", "proof"],
        }
        finding = SynonymAgent().evaluate(row)
        self.assertTrue(finding.needs_update)
        self.assertIn("duplicate_synonym", finding.issues)
        self.assertIn("invalid_synonym", finding.issues)
        self.assertEqual(finding.updates["synonym"], ["show", "proof"])

    def test_run_multiagent_batch_updates_target_id_only(self) -> None:
        target = {
            "id": 2624,
            "lemma": "demonstrate",
            "cefr": "B2",
            "pos": "verb",
            "definition": "To show how to use something.",
            "synonym": [],
            "sentences": [
                {
                    "text": "I'll demonstrate this with the help of a few concrete examples.",
                    "cloze_index": 1,
                },
                {
                    "text": "I'll demonstrate that with the help of a few concrete examples.",
                    "cloze_index": 1,
                },
                {
                    "text": "I'll demonstrate that with the help of a few concrete examples.",
                    "cloze_index": 1,
                },
            ],
        }
        untouched = {
            "id": 7777,
            "lemma": "robust",
            "cefr": "C1",
            "pos": "adjective",
            "definition": "Strong and effective in all conditions.",
            "synonym": ["solid"],
            "sentences": [
                {
                    "text": "Although the weather changed quickly, the robust plan still held.",
                    "cloze_index": cloze_index_for(
                        "robust",
                        "Although the weather changed quickly, the robust plan still held.",
                    ),
                },
                {
                    "text": "Would you trust a robust design during a system outage?",
                    "cloze_index": cloze_index_for(
                        "robust",
                        "Would you trust a robust design during a system outage?",
                    ),
                },
                {
                    "text": "\"This design is robust,\" she said, \"so failures stay isolated.\"",
                    "cloze_index": cloze_index_for(
                        "robust",
                        "\"This design is robust,\" she said, \"so failures stay isolated.\"",
                    ),
                },
            ],
        }

        updated_rows, summary = run_multiagent_batch(
            [target, untouched],
            target_ids={2624},
            workers=2,
            duplicate_threshold=0.92,
        )

        self.assertEqual(summary["rows_scanned"], 1)
        self.assertEqual(summary["rows_updated"], 1)
        self.assertIn(2624, summary["updated_ids"])

        target_after = next(row for row in updated_rows if row["id"] == 2624)
        self.assertEqual(len(target_after["sentences"]), 3)
        self.assertEqual(
            len({item["text"].lower() for item in target_after["sentences"]}),
            3,
        )

        untouched_after = next(row for row in updated_rows if row["id"] == 7777)
        self.assertEqual(untouched_after, untouched)


if __name__ == "__main__":
    unittest.main()
