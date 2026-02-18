#!/usr/bin/env python3
"""Refine repetitive seed example sentences in Lexical seed_data.json.

Targets legacy template-like examples and rewrites them with:
- one complex clause sentence
- one question sentence
- one dialogue sentence

Each rewrite recomputes cloze_index for the lemma token.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from import_extra_words import cloze_index_for, generate_sentence_pack


REPETITIVE_PATTERNS = [
    r"^The report explains how .+ affects planning in complex organizations\.$",
    r"^In class, students used .+ to compare two related concepts clearly\.$",
    r"^A clear .+ helped the team make faster and better decisions\.$",
    r"^Teams often .+ data carefully before publishing final recommendations\.$",
    r"^During the workshop, participants .+ each example step by step\.$",
    r"^We .+ the feedback to improve the next product release\.$",
    r"^The proposal seemed .+, so everyone asked for stronger evidence\.$",
    r"^Her .+ explanation made the policy easier for newcomers to understand\.$",
    r"^A .+ approach helped the group avoid repeated mistakes\.$",
    r"^The analyst reviewed the numbers .+ before sending the report\.$",
    r"^They communicated .+, which reduced confusion across departments\.$",
    r"^We tested the feature .+ to catch hidden issues early\.$",
    r"^The article introduced .+ with a practical example\.$",
    r"^In review, I used .+ in a clear sentence\.$",
    r"^Understanding .+ helps explain the main idea\.$",
    r"^We .+ this skill during our daily practice session\.$",
    r"^You can .+ the idea in a new context\.$",
    r"^Learners .+ better when they review consistently\.$",
    r"^The final explanation felt .+ after careful revision\.$",
    r"^Her notes became more .+ over the week\.$",
    r"^A .+ example helped the group remember the concept\.$",
    r"^The team worked .+ to finish the reading task\.$",
    r"^He replied .+ when the teacher asked for feedback\.$",
    r"^They discussed the topic .+ before the review started\.$",
    r"^In class today, we practiced the word .+ in a clear context\.$",
]
COMPILED_PATTERNS = [re.compile(pattern) for pattern in REPETITIVE_PATTERNS]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Refine repetitive examples in seed_data.json")
    parser.add_argument(
        "--seed-path",
        type=Path,
        default=Path("Lexical/Resources/Seeds/seed_data.json"),
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report impacted rows without writing changes.",
    )
    return parser.parse_args()


def normalize_lemma(value: Any) -> str:
    return str(value or "").strip().lower().replace("_", " ")


def normalize_supported_pos(value: Any) -> str | None:
    raw = str(value or "").strip().lower()
    if raw in {"noun", "verb", "adjective", "adverb"}:
        return raw
    if raw == "adj":
        return "adjective"
    if raw == "adv":
        return "adverb"
    return None


def is_repetitive_sentence(text: str) -> bool:
    normalized = re.sub(r"\s+", " ", str(text or "").strip())
    return any(pattern.match(normalized) for pattern in COMPILED_PATTERNS)


def is_valid_pack(lemma: str, pack: list[dict[str, Any]]) -> bool:
    if len(pack) != 3:
        return False

    for entry in pack:
        text = str(entry.get("text", "")).strip()
        if not text:
            return False
        expected = cloze_index_for(lemma, text)
        if expected != entry.get("cloze_index"):
            return False
    return True


def main() -> int:
    args = parse_args()
    rows = json.loads(args.seed_path.read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        raise ValueError("Seed payload must be a JSON array")

    changed_rows = 0
    changed_sentence_count = 0

    for row in rows:
        lemma = normalize_lemma(row.get("lemma"))
        if not lemma:
            continue

        normalized_pos = normalize_supported_pos(row.get("pos"))
        if normalized_pos is None:
            continue

        sentences = row.get("sentences", []) or []
        if not isinstance(sentences, list):
            continue

        repetitive_hits = 0
        for sentence in sentences:
            text = sentence.get("text") if isinstance(sentence, dict) else ""
            if is_repetitive_sentence(str(text or "")):
                repetitive_hits += 1

        if repetitive_hits == 0:
            continue

        new_pack = generate_sentence_pack(
            lemma=lemma,
            pos=normalized_pos,
            definition=str(row.get("definition", "")),
            cefr=str(row.get("cefr", "")),
        )
        if not is_valid_pack(lemma, new_pack):
            continue

        row["sentences"] = new_pack
        changed_rows += 1
        changed_sentence_count += repetitive_hits

    print(f"Seed rows: {len(rows)}")
    print(f"Rows rewritten: {changed_rows}")
    print(f"Template sentences replaced: {changed_sentence_count}")

    if not args.dry_run:
        args.seed_path.write_text(
            json.dumps(rows, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"Wrote updated seed data to {args.seed_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
