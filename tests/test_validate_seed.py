#!/usr/bin/env python3
"""Tests for scripts/validate_seed.py quality-gate behavior."""

from __future__ import annotations

import importlib.util
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "scripts" / "validate_seed.py"
SPEC = importlib.util.spec_from_file_location("validate_seed_module", SCRIPT_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Unable to load module from {SCRIPT_PATH}")
validate_seed_module = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = validate_seed_module
SPEC.loader.exec_module(validate_seed_module)


class ValidateSeedTests(unittest.TestCase):
    def _write_seed(self, rows: list[dict[str, object]]) -> Path:
        tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(tmpdir.cleanup)
        path = Path(tmpdir.name) / "seed_data.json"
        path.write_text(json.dumps(rows), encoding="utf-8")
        return path

    def _run_main(self, args: list[str]) -> tuple[int, str]:
        output = io.StringIO()
        with redirect_stdout(output):
            code = validate_seed_module.main(args)
        return code, output.getvalue()

    def _quality_debt_rows(self) -> list[dict[str, object]]:
        return [
            {
                "lemma": "alpha",
                "ipa": "/ˈalfə/",
                "definition": "The first letter of the Greek alphabet.",
                "rank": 100,
                "collocations": ["alpha wave"],
                "sentences": [
                    {"text": "This sentence omits the target token.", "cloze_index": 0},
                    {"text": "Alpha appears here once.", "cloze_index": 99},
                ],
            }
        ]

    def test_default_mode_warns_but_does_not_fail_quality_debt(self) -> None:
        seed_path = self._write_seed(self._quality_debt_rows())
        code, output = self._run_main(["--seed-path", str(seed_path)])

        self.assertEqual(code, 0)
        self.assertIn("QUALITY SIGNALS", output)
        self.assertIn("QUALITY WARNINGS", output)

    def test_strict_mode_fails_when_threshold_exceeded(self) -> None:
        seed_path = self._write_seed(self._quality_debt_rows())
        code, output = self._run_main(
            [
                "--seed-path",
                str(seed_path),
                "--strict-quality",
                "--max-lemma-missing-rate",
                "0.0",
                "--max-cloze-mismatch-rate",
                "0.0",
                "--max-sentence-set-violation-rate",
                "0.0",
                "--max-duplicate-set-rate",
                "0.0",
            ]
        )

        self.assertEqual(code, 1)
        self.assertIn("QUALITY THRESHOLD FAILURES", output)

    def test_analyze_seed_detects_cloze_mismatches(self) -> None:
        stats = validate_seed_module.analyze_seed(self._quality_debt_rows())
        self.assertEqual(stats.total_sentences, 2)
        self.assertGreaterEqual(stats.cloze_mismatch_sentences, 1)

    def test_analyze_seed_detects_lemma_missing_sentences(self) -> None:
        stats = validate_seed_module.analyze_seed(self._quality_debt_rows())
        self.assertEqual(stats.lemma_missing_sentences, 1)

    def test_analyze_seed_detects_sentence_set_size_violations(self) -> None:
        stats = validate_seed_module.analyze_seed(self._quality_debt_rows())
        self.assertEqual(stats.sentence_set_size_violations, 1)


if __name__ == "__main__":
    unittest.main()
