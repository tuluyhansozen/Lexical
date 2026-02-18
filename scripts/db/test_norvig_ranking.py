#!/usr/bin/env python3
import json
import tempfile
import unittest
from pathlib import Path

from norvig_ranking import (
    FALLBACK_RANK,
    build_rank_index,
    load_norvig_ranking,
    rerank_seed_data,
)


class NorvigRankingTests(unittest.TestCase):
    def test_load_norvig_ranking_assigns_dense_ranks(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            norvig_path = Path(tmpdir) / "count_1w.txt"
            norvig_path.write_text("the\t10\nbe\t9\nbook\t1\n", encoding="utf-8")

            ranking = load_norvig_ranking(norvig_path)

            self.assertEqual(ranking["the"], 1)
            self.assertEqual(ranking["be"], 2)
            self.assertEqual(ranking["book"], 3)

    def test_build_rank_index_falls_back_for_missing_words(self) -> None:
        ranking = {"hello": 1, "world": 2}
        self.assertEqual(build_rank_index("hello", ranking), 1)
        self.assertEqual(build_rank_index("missing", ranking), FALLBACK_RANK)

    def test_rerank_seed_data_updates_only_60001_rows(self) -> None:
        seed = [
            {"lemma": "hello", "rank": 60_001},
            {"lemma": "world", "rank": 60_001},
            {"lemma": "stable", "rank": 900},
        ]
        ranking = {"hello": 100, "world": 200}

        report = rerank_seed_data(seed, ranking)

        self.assertEqual(seed[0]["rank"], 100)
        self.assertEqual(seed[1]["rank"], 200)
        self.assertEqual(seed[2]["rank"], 900)
        self.assertEqual(report["updated"], 2)
        self.assertEqual(report["remaining_fallback"], 0)


if __name__ == "__main__":
    unittest.main()
