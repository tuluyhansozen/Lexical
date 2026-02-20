#!/usr/bin/env python3
"""
Lexical Seed Database Validator
==============================
Validates seed_data.json with core correctness checks and quality signals.
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Sequence

DEFAULT_SEED_FILE = Path("Lexical/Resources/Seeds/seed_data.json")
WORD_RE = re.compile(r"[A-Za-z]+(?:'[A-Za-z]+)?")


@dataclass
class SeedValidationStats:
    total_entries: int = 0
    missing_ipa: int = 0
    missing_def: int = 0
    missing_rank: int = 0
    long_defs: int = 0
    missing_context: int = 0
    orphans: int = 0
    total_sentences: int = 0
    lemma_missing_sentences: int = 0
    cloze_mismatch_sentences: int = 0
    sentence_set_size_violations: int = 0
    duplicate_sentence_sets: int = 0
    entries_with_sentences: int = 0
    ranks: list[int] = field(default_factory=list)


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate Lexical seed_data.json quality and safety")
    parser.add_argument("--seed-path", type=Path, default=DEFAULT_SEED_FILE)
    parser.add_argument("--strict-quality", action="store_true", help="Fail when quality metrics exceed thresholds.")
    parser.add_argument("--max-missing-ipa-rate", type=float, default=0.20)
    parser.add_argument("--max-lemma-missing-rate", type=float, default=0.02)
    parser.add_argument("--max-cloze-mismatch-rate", type=float, default=0.02)
    parser.add_argument("--max-sentence-set-violation-rate", type=float, default=0.01)
    parser.add_argument("--max-duplicate-set-rate", type=float, default=0.01)
    return parser.parse_args(argv)


def load_seed_rows(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        raise FileNotFoundError(f"Seed file not found at {path}")

    with path.open("r", encoding="utf-8") as handle:
        raw = json.load(handle)

    if not isinstance(raw, list):
        raise ValueError("Seed file root must be a JSON array")

    rows: list[dict[str, Any]] = []
    for entry in raw:
        if isinstance(entry, dict):
            rows.append(entry)
    return rows


def tokenize_words(text: str) -> list[str]:
    return WORD_RE.findall(text)


def find_cloze_index(lemma: str, text: str) -> int | None:
    target = lemma.strip().casefold()
    if not target:
        return None

    for idx, token in enumerate(tokenize_words(text)):
        if token.casefold() == target:
            return idx
    return None


def normalize_sentence(text: str) -> str:
    return " ".join(tokenize_words(text)).casefold()


def safe_rate(numerator: int, denominator: int) -> float:
    if denominator <= 0:
        return 0.0
    return numerator / denominator


def format_pct(rate: float) -> str:
    return f"{rate * 100:.2f}%"


def analyze_seed(rows: Sequence[dict[str, Any]]) -> SeedValidationStats:
    stats = SeedValidationStats(total_entries=len(rows))

    for entry in rows:
        lemma = str(entry.get("lemma") or "").strip()

        if not entry.get("ipa"):
            stats.missing_ipa += 1

        definition = str(entry.get("definition") or "")
        if not definition.strip():
            stats.missing_def += 1

        if len(definition) > 200:
            stats.long_defs += 1

        rank = entry.get("rank")
        if isinstance(rank, int):
            stats.ranks.append(rank)
        elif isinstance(rank, float):
            stats.ranks.append(int(rank))
        else:
            stats.missing_rank += 1

        sentences_raw = entry.get("sentences")
        sentences = sentences_raw if isinstance(sentences_raw, list) else []

        if not sentences:
            stats.missing_context += 1
        else:
            stats.entries_with_sentences += 1

        if not entry.get("collocations"):
            stats.orphans += 1

        if len(sentences) != 3:
            stats.sentence_set_size_violations += 1

        normalized_texts: list[str] = []
        for sentence in sentences:
            if not isinstance(sentence, dict):
                continue

            text = str(sentence.get("text") or "")
            reported_cloze = sentence.get("cloze_index")
            expected_cloze = find_cloze_index(lemma, text)
            has_reported_cloze = isinstance(reported_cloze, int)

            stats.total_sentences += 1

            if expected_cloze is None:
                stats.lemma_missing_sentences += 1
                if has_reported_cloze:
                    stats.cloze_mismatch_sentences += 1
            elif (not has_reported_cloze) or (reported_cloze != expected_cloze):
                stats.cloze_mismatch_sentences += 1

            normalized = normalize_sentence(text)
            if normalized:
                normalized_texts.append(normalized)

        if normalized_texts and len(set(normalized_texts)) < len(normalized_texts):
            stats.duplicate_sentence_sets += 1

    return stats


def quality_thresholds(stats: SeedValidationStats, args: argparse.Namespace) -> list[tuple[str, float, float]]:
    return [
        (
            "lemma_missing_in_sentence_rate",
            safe_rate(stats.lemma_missing_sentences, stats.total_sentences),
            args.max_lemma_missing_rate,
        ),
        (
            "cloze_index_mismatch_rate",
            safe_rate(stats.cloze_mismatch_sentences, stats.total_sentences),
            args.max_cloze_mismatch_rate,
        ),
        (
            "sentence_set_size_violation_rate",
            safe_rate(stats.sentence_set_size_violations, stats.total_entries),
            args.max_sentence_set_violation_rate,
        ),
        (
            "duplicate_sentence_set_rate",
            safe_rate(stats.duplicate_sentence_sets, stats.entries_with_sentences),
            args.max_duplicate_set_rate,
        ),
    ]


def print_report(stats: SeedValidationStats, args: argparse.Namespace) -> tuple[list[str], list[str], list[str]]:
    print("=" * 60)
    print("🔍 LEXICAL SEED DATABASE VALIDATION")
    print("=" * 60)
    print(f"📄 Loaded {stats.total_entries} entries.")

    print("\n📊 VALIDATION REPORT")
    print(f"   Total Entries:      {stats.total_entries}")
    print(f"   Missing IPA:        {stats.missing_ipa} ({format_pct(safe_rate(stats.missing_ipa, stats.total_entries))})")
    print(f"   Missing Definition: {stats.missing_def}")
    print(f"   Missing Rank:       {stats.missing_rank}")
    print(f"   Definitions > 200c: {stats.long_defs}")
    print(f"   Missing Context:    {stats.missing_context}")
    print(f"   Orphan Words:       {stats.orphans}")

    if stats.ranks:
        print("\n📈 RANK STATISTICS")
        print(f"   Min Rank: {min(stats.ranks)}")
        print(f"   Max Rank: {max(stats.ranks)}")
        print(f"   Avg Rank: {sum(stats.ranks) / len(stats.ranks):.1f}")

    print("\n🧪 QUALITY SIGNALS")
    print(f"   Sentences scanned:               {stats.total_sentences}")
    print(f"   Lemma missing sentences:         {stats.lemma_missing_sentences} ({format_pct(safe_rate(stats.lemma_missing_sentences, stats.total_sentences))})")
    print(f"   Cloze index mismatches:          {stats.cloze_mismatch_sentences} ({format_pct(safe_rate(stats.cloze_mismatch_sentences, stats.total_sentences))})")
    print(f"   Sentence-set size violations:    {stats.sentence_set_size_violations} ({format_pct(safe_rate(stats.sentence_set_size_violations, stats.total_entries))})")
    print(f"   Duplicate sentence sets:         {stats.duplicate_sentence_sets} ({format_pct(safe_rate(stats.duplicate_sentence_sets, stats.entries_with_sentences))})")

    hard_failures: list[str] = []
    quality_breaches: list[str] = []
    quality_warnings: list[str] = []

    if stats.missing_def > 0:
        hard_failures.append("Missing definitions detected")

    missing_ipa_rate = safe_rate(stats.missing_ipa, stats.total_entries)
    if missing_ipa_rate > args.max_missing_ipa_rate:
        hard_failures.append(
            f"High missing IPA rate ({format_pct(missing_ipa_rate)} > {format_pct(args.max_missing_ipa_rate)})"
        )

    for metric, observed, threshold in quality_thresholds(stats, args):
        if observed > threshold:
            message = f"{metric}={format_pct(observed)} exceeds threshold {format_pct(threshold)}"
            quality_warnings.append(message)
            if args.strict_quality:
                quality_breaches.append(message)

    if quality_warnings:
        print("\n⚠️ QUALITY WARNINGS")
        for warning in quality_warnings:
            print(f"   - {warning}")

    if quality_breaches:
        print("\n❌ QUALITY THRESHOLD FAILURES")
        for breach in quality_breaches:
            print(f"   - {breach}")

    return hard_failures, quality_breaches, quality_warnings


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)

    try:
        rows = load_seed_rows(args.seed_path)
    except (FileNotFoundError, ValueError, OSError, json.JSONDecodeError) as error:
        print(f"❌ Error: {error}")
        return 1

    stats = analyze_seed(rows)
    hard_failures, quality_breaches, _ = print_report(stats, args)

    if hard_failures or quality_breaches:
        print("\n❌ VALIDATION FAILED")
        for failure in hard_failures:
            print(f"   - {failure}")
        return 1

    mode_text = "strict quality mode" if args.strict_quality else "warn-only quality mode"
    print(f"\n✅ VALIDATION PASSED ({mode_text})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
