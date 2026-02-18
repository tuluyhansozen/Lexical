#!/usr/bin/env python3
"""Import extra vocabulary rows into Lexical seed_data.json.

Pipeline-aligned behavior:
- normalize and dedupe incoming words by lemma
- skip lemmas that already exist in seed_data.json
- assign rank from Norvig unigram list when possible
- fallback rank for missing words
- generate exactly 3 safe example sentences with cloze_index
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from norvig_ranking import FALLBACK_RANK, load_norvig_ranking


VALID_CEFR = {"A1", "A2", "B1", "B2", "C1", "C2"}
WORD_PATTERN = re.compile(r"^[a-z][a-z' -]*$")
TOKEN_PATTERN = re.compile(r"\b[\w']+\b")


def normalize_lemma(value: Any) -> str:
    raw = str(value or "").strip().lower()
    raw = re.sub(r"\s+", " ", raw)
    return raw


def normalize_pos(value: Any) -> str:
    raw = str(value or "").strip().lower()
    mapping = {
        "adj": "adjective",
        "adjective": "adjective",
        "adv": "adverb",
        "adverb": "adverb",
        "noun": "noun",
        "verb": "verb",
        "modal": "modal",
        "preposition": "preposition",
        "conjunction": "conjunction",
        "pronoun": "pronoun",
        "determiner": "determiner",
        "interjection": "interjection",
        "name": "name",
        "particle": "particle",
    }
    return mapping.get(raw, "noun")


def normalize_cefr(value: Any) -> str:
    raw = str(value or "").strip().upper()
    raw = raw.rstrip("+")
    return raw if raw in VALID_CEFR else "B2"


def clean_definition(value: Any) -> str:
    text = str(value or "").strip()
    return re.sub(r"\s+", " ", text)


def row_quality_score(row: dict[str, Any]) -> tuple[int, int, int]:
    cefr_score = 1 if normalize_cefr(row.get("cefr_level")) in VALID_CEFR else 0
    definition_len = len(clean_definition(row.get("definition")))
    has_type = 1 if str(row.get("type", "")).strip() else 0
    return (cefr_score, definition_len, has_type)


def build_extra_index(rows: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    indexed: dict[str, dict[str, Any]] = {}
    for row in rows:
        lemma = normalize_lemma(row.get("word") or row.get("lemma"))
        if not lemma:
            continue
        if not WORD_PATTERN.match(lemma):
            continue
        existing = indexed.get(lemma)
        if existing is None or row_quality_score(row) > row_quality_score(existing):
            indexed[lemma] = row
    return indexed


def cloze_index_for(lemma: str, sentence: str) -> int:
    tokens = TOKEN_PATTERN.findall(sentence.lower())
    for index, token in enumerate(tokens):
        if token == lemma:
            return index

    # Lightweight inflection matching for provided examples.
    for index, token in enumerate(tokens):
        if token.startswith(lemma) or lemma.startswith(token):
            return index
        if lemma.endswith("e") and token.startswith(lemma[:-1]):
            return index
        if token.endswith("ed") and token[:-2] == lemma:
            return index
        if token.endswith("ing") and (token[:-3] == lemma or token[:-3] == lemma[:-1]):
            return index
        if token.endswith("es") and (token[:-2] == lemma or token[:-2] == lemma[:-1]):
            return index
        if token.endswith("s") and token[:-1] == lemma:
            return index
    return 0


def generate_sentence_pack(lemma: str, pos: str) -> list[dict[str, Any]]:
    if pos == "verb":
        templates = [
            f"Teams often {lemma} data carefully before publishing final recommendations.",
            f"During the workshop, participants {lemma} each example step by step.",
            f"We {lemma} the feedback to improve the next product release.",
        ]
    elif pos == "adjective":
        templates = [
            f"The proposal seemed {lemma}, so everyone asked for stronger evidence.",
            f"Her {lemma} explanation made the policy easier for newcomers to understand.",
            f"A {lemma} approach helped the group avoid repeated mistakes.",
        ]
    elif pos == "adverb":
        templates = [
            f"The analyst reviewed the numbers {lemma} before sending the report.",
            f"They communicated {lemma}, which reduced confusion across departments.",
            f"We tested the feature {lemma} to catch hidden issues early.",
        ]
    else:
        templates = [
            f"The report explains how {lemma} affects planning in complex organizations.",
            f"In class, students used {lemma} to compare two related concepts clearly.",
            f"A clear {lemma} helped the team make faster and better decisions.",
        ]

    return [
        {"text": text, "cloze_index": cloze_index_for(lemma, text)}
        for text in templates
    ]


def sentence_pack_from_examples(lemma: str, examples: Any) -> list[dict[str, Any]]:
    if not isinstance(examples, list):
        return []

    prepared: list[dict[str, Any]] = []
    for raw in examples:
        text = re.sub(r"\s+", " ", str(raw or "").strip())
        if not text:
            continue

        cloze = cloze_index_for(lemma, text)
        prepared.append({"text": text, "cloze_index": cloze})
        if len(prepared) == 3:
            break

    return prepared


def fsrs_difficulty(rank: int) -> float:
    return min(10.0, round(2.0 + (rank / 60_000.0) * 8.0, 2))


def determine_fallback_rank(
    seed_rows: list[dict[str, Any]],
    configured_fallback_rank: int | None,
) -> int:
    if configured_fallback_rank is not None:
        return configured_fallback_rank

    numeric_ranks = [
        int(row["rank"])
        for row in seed_rows
        if isinstance(row.get("rank"), int)
    ]
    if not numeric_ranks:
        return FALLBACK_RANK
    return max(numeric_ranks) + 1000


def make_seed_entry(
    *,
    seed_id: int,
    lemma: str,
    rank: int,
    cefr: str,
    pos: str,
    definition: str,
    examples: Any = None,
) -> dict[str, Any]:
    sentences = sentence_pack_from_examples(lemma, examples)
    if len(sentences) < 3:
        sentences = generate_sentence_pack(lemma, pos)

    return {
        "id": seed_id,
        "lemma": lemma,
        "rank": rank,
        "cefr": cefr,
        "pos": pos,
        "ipa": None,
        "definition": definition,
        "synonym": [],
        "fsrs_initial": {
            "d": fsrs_difficulty(rank),
            "s": 0.0,
            "r": 0.0,
        },
        "sentences": sentences,
    }


def merge_extra_words(
    seed_rows: list[dict[str, Any]],
    extra_rows: list[dict[str, Any]],
    ranking: dict[str, int],
    *,
    fallback_rank: int = FALLBACK_RANK,
) -> dict[str, Any]:
    existing_lemmas = {
        normalize_lemma(row.get("lemma"))
        for row in seed_rows
        if isinstance(row, dict)
    }
    numeric_ids = [int(row["id"]) for row in seed_rows if isinstance(row.get("id"), int)]
    next_id = (max(numeric_ids) + 1) if numeric_ids else 1

    indexed = build_extra_index(extra_rows)
    duplicate_rows = max(0, len(extra_rows) - len(indexed))

    report = {
        "input_rows": len(extra_rows),
        "unique_lemmas": len(indexed),
        "duplicates_in_input": duplicate_rows,
        "inserted": 0,
        "skipped_existing": 0,
        "rank_from_norvig": 0,
        "rank_fallback": 0,
        "added_lemmas": [],
    }

    for lemma in sorted(indexed.keys()):
        if lemma in existing_lemmas:
            report["skipped_existing"] += 1
            continue

        source = indexed[lemma]
        rank = ranking.get(lemma, fallback_rank)
        if rank == fallback_rank:
            report["rank_fallback"] += 1
        else:
            report["rank_from_norvig"] += 1

        definition = clean_definition(source.get("definition")) or f"Meaning of {lemma}."
        cefr = normalize_cefr(source.get("cefr_level"))
        pos = normalize_pos(source.get("type"))

        seed_rows.append(
            make_seed_entry(
                seed_id=next_id,
                lemma=lemma,
                rank=rank,
                cefr=cefr,
                pos=pos,
                definition=definition,
                examples=source.get("examples"),
            )
        )
        existing_lemmas.add(lemma)
        report["added_lemmas"].append(lemma)
        report["inserted"] += 1
        next_id += 1

    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import extra words into seed_data.json.")
    parser.add_argument(
        "--extra-path",
        type=Path,
        default=Path("extra words.json"),
        help="Input extra words JSON file.",
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
        "--fallback-rank",
        type=int,
        default=None,
        help="Optional explicit fallback rank. Default is max existing rank + 1000.",
    )
    parser.add_argument(
        "--output-path",
        type=Path,
        default=None,
        help="Optional output path. Ignored when --in-place is set.",
    )
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Overwrite seed file directly.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    extra_path = args.extra_path
    if not extra_path.exists():
        alt = Path("extra_words.json")
        if alt.exists():
            extra_path = alt
        else:
            raise FileNotFoundError(
                f"Extra words file not found: {args.extra_path} (or fallback {alt})"
            )

    seed_rows = json.loads(args.seed_path.read_text(encoding="utf-8"))
    if not isinstance(seed_rows, list):
        raise ValueError("Seed payload must be a JSON array")
    extra_rows = json.loads(extra_path.read_text(encoding="utf-8"))
    if not isinstance(extra_rows, list):
        raise ValueError("Extra words payload must be a JSON array")

    ranking: dict[str, int] = {}
    if args.norvig_path.exists():
        ranking = load_norvig_ranking(args.norvig_path)

    fallback_rank = determine_fallback_rank(seed_rows, args.fallback_rank)

    report = merge_extra_words(
        seed_rows,
        extra_rows,
        ranking,
        fallback_rank=fallback_rank,
    )

    output_path = args.seed_path if args.in_place else (args.output_path or args.seed_path.with_suffix(".with-extra.json"))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(seed_rows, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"Extra source: {extra_path}")
    print(f"Output: {output_path}")
    print(f"Input rows: {report['input_rows']}")
    print(f"Unique lemmas: {report['unique_lemmas']}")
    print(f"Duplicates in input: {report['duplicates_in_input']}")
    print(f"Inserted: {report['inserted']}")
    print(f"Skipped existing: {report['skipped_existing']}")
    print(f"Rank from Norvig: {report['rank_from_norvig']}")
    print(f"Rank fallback({fallback_rank}): {report['rank_fallback']}")
    if report["added_lemmas"]:
        print("Added sample (first 25):")
        for lemma in report["added_lemmas"][:25]:
            print(f"- {lemma}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
