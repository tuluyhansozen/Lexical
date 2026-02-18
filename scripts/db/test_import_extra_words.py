#!/usr/bin/env python3
import unittest

from import_extra_words import (
    FALLBACK_RANK,
    build_extra_index,
    cloze_index_for,
    determine_fallback_rank,
    generate_sentence_pack,
    normalize_cefr,
    merge_extra_words,
)


class ImportExtraWordsTests(unittest.TestCase):
    def test_determine_fallback_rank_uses_max_plus_1000(self) -> None:
        seed = [
            {"id": 1, "lemma": "alpha", "rank": 10},
            {"id": 2, "lemma": "beta", "rank": 2500},
            {"id": 3, "lemma": "gamma", "rank": 900},
        ]
        self.assertEqual(determine_fallback_rank(seed, None), 3500)
        self.assertEqual(determine_fallback_rank(seed, 7777), 7777)

    def test_build_extra_index_dedupes_by_word(self) -> None:
        rows = [
            {"word": "Alpha", "type": "noun", "definition": "short", "cefr_level": ""},
            {
                "word": "alpha",
                "type": "noun",
                "definition": "a longer and better definition",
                "cefr_level": "B2",
            },
        ]
        idx = build_extra_index(rows)
        self.assertEqual(set(idx.keys()), {"alpha"})
        self.assertEqual(idx["alpha"]["cefr_level"], "B2")
        self.assertIn("longer", idx["alpha"]["definition"])

    def test_generate_sentence_pack_has_three_valid_cloze_entries(self) -> None:
        pack = generate_sentence_pack("construe", "verb")
        self.assertEqual(len(pack), 3)
        for item in pack:
            text = item["text"]
            self.assertGreaterEqual(item["cloze_index"], 0)
            self.assertEqual(item["cloze_index"], cloze_index_for("construe", text))

    def test_merge_extra_words_skips_existing_and_assigns_rank(self) -> None:
        seed = [
            {
                "id": 10,
                "lemma": "existing",
                "rank": 100,
                "cefr": "A2",
                "pos": "noun",
                "ipa": None,
                "definition": "already here",
                "synonym": [],
                "fsrs_initial": {"d": 2.03, "s": 0.0, "r": 0.0},
                "sentences": [
                    {"text": "An existing entry remains unchanged.", "cloze_index": 1},
                    {"text": "We keep the existing record in the seed.", "cloze_index": 3},
                    {"text": "No update is needed for existing words.", "cloze_index": 5},
                ],
            }
        ]
        extra = [
            {"word": "existing", "type": "noun", "definition": "dup", "cefr_level": "B1"},
            {"word": "newword", "type": "noun", "definition": "fresh def", "cefr_level": "C1"},
            {"word": "fallbackword", "type": "noun", "definition": "fallback", "cefr_level": "B2"},
        ]
        ranking = {"newword": 1234}

        report = merge_extra_words(seed, extra, ranking, fallback_rank=FALLBACK_RANK)

        self.assertEqual(report["inserted"], 2)
        self.assertEqual(report["skipped_existing"], 1)
        by_lemma = {row["lemma"]: row for row in seed}
        self.assertEqual(by_lemma["newword"]["rank"], 1234)
        self.assertEqual(by_lemma["fallbackword"]["rank"], FALLBACK_RANK)
        self.assertEqual(len(by_lemma["newword"]["sentences"]), 3)

    def test_merge_extra_words_uses_provided_examples_when_available(self) -> None:
        seed = []
        extra = [
            {
                "word": "meretricious",
                "type": "adj",
                "definition": "apparently attractive but lacking real value",
                "cefr_level": "C2+",
                "examples": [
                    "The review called the design meretricious and hollow.",
                    "She rejected the meretricious proposal immediately.",
                    "Critics disliked the meretricious style of the campaign.",
                ],
            }
        ]
        ranking = {"meretricious": 12345}

        report = merge_extra_words(seed, extra, ranking, fallback_rank=FALLBACK_RANK)

        self.assertEqual(report["inserted"], 1)
        added = seed[0]
        self.assertEqual(added["lemma"], "meretricious")
        self.assertEqual(added["cefr"], "C2")
        self.assertEqual(len(added["sentences"]), 3)
        for sentence in added["sentences"]:
            self.assertIn("meretricious", sentence["text"].lower())
            self.assertEqual(
                sentence["cloze_index"],
                cloze_index_for("meretricious", sentence["text"]),
            )

    def test_normalize_cefr_maps_plus_levels(self) -> None:
        self.assertEqual(normalize_cefr("C2+"), "C2")
        self.assertEqual(normalize_cefr("B2+"), "B2")

    def test_provided_examples_with_inflection_are_kept(self) -> None:
        seed = []
        extra = [
            {
                "word": "coalesce",
                "type": "verb",
                "definition": "to come together and form one whole",
                "cefr_level": "C2+",
                "examples": [
                    "The teams coalesced around a single strategy by noon.",
                    "Several ideas coalesce into one final proposal.",
                    "As pressure increased, the group quickly coalesced.",
                ],
            }
        ]
        ranking = {"coalesce": 2222}

        report = merge_extra_words(seed, extra, ranking, fallback_rank=FALLBACK_RANK)
        self.assertEqual(report["inserted"], 1)
        added = seed[0]
        texts = [s["text"] for s in added["sentences"]]
        self.assertEqual(texts, extra[0]["examples"])


if __name__ == "__main__":
    unittest.main()
