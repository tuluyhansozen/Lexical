#!/usr/bin/env python3
"""Validate seed_data.json for disallowed unsafe lemma/synonym/sentence patterns.

Usage:
  python scripts/db/validate_seed_safety.py \
    --seed-path Lexical/Resources/Seeds/seed_data.json
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


BLOCKED_PATTERNS = [
    # Existing high-severity lexical patterns
    r"\bmasturbat(?:e|es|ed|ion|ing)?\b",
    r"\bstriptease\b",
    r"\bsevered\s+penis\b",
    r"\bporno(?:graphic)?\b",
    r"\bporn\b",
    r"\bsex(?:ual|ually)?\s+intercourse\b",
    r"\bsex\s+offender(?:s)?\b",
    r"\bsodom(?:y|ise|ize|ised|ized|ising|izing)\b",
    r"\bkill\s+myself\b",
    r"\bcommit\s+suicide\b",
    r"\bsuicide\s+bomber\b",
    r"\bkill\s+you\b",
    r"\bnazi(?:s)?\b",
    r"\bkebab\s+murders\b",
    r"\bselected\s+to\s+receive\s+a\s+free\s+cruise\b",
    # Broader app-safety coverage for seed quality
    r"\bfuck(?:ed|ing|s)?\b",
    r"\bshit(?:ty|ton)?\b",
    r"\bbitch(?:es)?\b",
    r"\bbastard(?:s)?\b",
    r"\basshole(?:s)?\b",
    r"\bcunt(?:s)?\b",
    r"\bslut(?:s)?\b",
    r"\bwhore(?:s)?\b",
    r"\brape\b",
    r"\bsuicide\b",
    r"\bterrorist(?:s)?\b",
]

PLACEHOLDER_PATTERN = re.compile(
    r"<[^>]+>|\{\{[^}]+\}\}|\b(?:scenario|placeholder|sample|template)_word_\d+\b|lorem ipsum",
    re.IGNORECASE,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--seed-path",
        type=Path,
        default=Path("Lexical/Resources/Seeds/seed_data.json"),
    )
    parser.add_argument("--max-errors", type=int, default=100)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    payload = json.loads(args.seed_path.read_text(encoding="utf-8"))

    blocked = [re.compile(p, re.IGNORECASE) for p in BLOCKED_PATTERNS]
    issues: list[tuple[int, str, str, str]] = []

    for row in payload:
        lemma = str(row.get("lemma", "")).strip().lower()
        seed_id = int(row.get("id", -1))

        candidates = [("lemma", lemma)]

        for synonym in row.get("synonym", []) or []:
            text = str(synonym).strip()
            if text:
                candidates.append(("synonym", text))

        for sentence in row.get("sentences", []):
            text = str(sentence.get("text", "")).strip()
            if text:
                candidates.append(("sentence", text))

        for field, text in candidates:
            if PLACEHOLDER_PATTERN.search(text):
                issues.append((seed_id, lemma, field, text))
                continue
            for regex in blocked:
                if regex.search(text):
                    issues.append((seed_id, lemma, field, text))
                    break
            if len(issues) >= args.max_errors:
                break
        if len(issues) >= args.max_errors:
            break

    if not issues:
        print("Seed safety validation passed.")
        return 0

    print(f"Seed safety validation failed. Found {len(issues)} unsafe entry/entries:")
    for seed_id, lemma, field, text in issues:
        print(f"- id={seed_id} lemma={lemma} field={field}: {text}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
