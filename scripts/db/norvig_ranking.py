#!/usr/bin/env python3
"""Backfill Lexical seed ranks from Norvig unigram counts."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


FALLBACK_RANK = 60_001


def load_norvig_ranking(path: Path) -> dict[str, int]:
    ranking: dict[str, int] = {}
    current_rank = 0

    with path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue

            parts = line.split()
            if not parts:
                continue

            lemma = parts[0].strip().lower()
            if not lemma or lemma in ranking:
                continue

            current_rank += 1
            ranking[lemma] = current_rank

    return ranking


def build_rank_index(
    lemma: str,
    ranking: dict[str, int],
    fallback_rank: int = FALLBACK_RANK,
) -> int:
    normalized = lemma.strip().lower()
    if not normalized:
        return fallback_rank
    return ranking.get(normalized, fallback_rank)


def rerank_seed_data(
    seed_rows: list[dict[str, Any]],
    ranking: dict[str, int],
    fallback_rank: int = FALLBACK_RANK,
) -> dict[str, int]:
    fallback_before = 0
    updated = 0

    for row in seed_rows:
        if row.get("rank") != fallback_rank:
            continue

        fallback_before += 1
        lemma = str(row.get("lemma", ""))
        rank = build_rank_index(lemma, ranking, fallback_rank=fallback_rank)
        if rank != fallback_rank:
            row["rank"] = rank
            updated += 1

    remaining_fallback = sum(1 for row in seed_rows if row.get("rank") == fallback_rank)
    return {
        "total_rows": len(seed_rows),
        "fallback_before": fallback_before,
        "updated": updated,
        "remaining_fallback": remaining_fallback,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Backfill Lexical seed_data ranks from Norvig unigram ranking."
    )
    parser.add_argument(
        "--seed-path",
        type=Path,
        default=Path("Lexical/Resources/Seeds/seed_data.json"),
    )
    parser.add_argument(
        "--norvig-path",
        type=Path,
        default=Path("count_1w.txt"),
    )
    parser.add_argument(
        "--output-path",
        type=Path,
        default=None,
        help="Optional output path. If omitted with --in-place, source file is overwritten.",
    )
    parser.add_argument(
        "--fallback-rank",
        type=int,
        default=FALLBACK_RANK,
    )
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Overwrite --seed-path directly.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if not args.norvig_path.exists():
        raise FileNotFoundError(f"Norvig file not found: {args.norvig_path}")
    if not args.seed_path.exists():
        raise FileNotFoundError(f"Seed file not found: {args.seed_path}")

    ranking = load_norvig_ranking(args.norvig_path)
    seed_rows = json.loads(args.seed_path.read_text(encoding="utf-8"))
    if not isinstance(seed_rows, list):
        raise ValueError("Seed payload must be a top-level JSON array")

    report = rerank_seed_data(
        seed_rows,
        ranking,
        fallback_rank=args.fallback_rank,
    )

    output_path = args.output_path
    if args.in_place:
        output_path = args.seed_path
    elif output_path is None:
        output_path = args.seed_path.with_suffix(".norvig-ranked.json")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(seed_rows, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"Norvig entries loaded: {len(ranking)}")
    print(f"Output path: {output_path}")
    print(
        "Backfill report: "
        f"total={report['total_rows']} "
        f"fallback_before={report['fallback_before']} "
        f"updated={report['updated']} "
        f"remaining_fallback={report['remaining_fallback']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
