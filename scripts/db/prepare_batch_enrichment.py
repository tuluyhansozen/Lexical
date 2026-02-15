#!/usr/bin/env python3
"""Prepare Lexical seed DB for batch enrichment.

Features:
- Remove CEFR levels (default: A1)
- Enforce exactly 6 word_ids per root
- Generate 50-word batch files for external enrichment
- Emit prompt templates for batch + final merge passes
"""

from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path
from typing import Any


DEFAULT_SEED_PATH = Path("Lexical/Resources/Seeds/seed_data.json")
DEFAULT_ROOTS_PATH = Path("Lexical/Resources/Seeds/roots.json")
DEFAULT_OUTPUT_DIR = Path("build/lexical_enrichment_batches")


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def save_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def normalize_lemma(value: Any) -> str:
    return str(value or "").strip().lower()


def extract_root_tokens(root_value: str) -> list[str]:
    raw = (root_value or "").lower()
    parts = re.split(r"[\s/,&|()\-]+", raw)

    tokens: list[str] = []
    seen: set[str] = set()

    for part in parts:
        token = re.sub(r"[^a-z]", "", part)
        if len(token) < 3:
            continue
        if token in seen:
            continue
        seen.add(token)
        tokens.append(token)

    if tokens:
        return tokens

    fallback = re.sub(r"[^a-z]", "", raw)
    if len(fallback) >= 2:
        return [fallback]
    return []


def rank_key(word: dict[str, Any]) -> tuple[int, int]:
    rank = word.get("rank")
    rank_value = rank if isinstance(rank, int) else 10**9
    word_id = word.get("id")
    id_value = word_id if isinstance(word_id, int) else 10**9
    return rank_value, id_value


def unique_ints(values: list[Any]) -> list[int]:
    result: list[int] = []
    seen: set[int] = set()
    for value in values:
        if not isinstance(value, int):
            continue
        if value in seen:
            continue
        seen.add(value)
        result.append(value)
    return result


def choose_root_word_ids(
    root: dict[str, Any],
    allowed_word_ids: set[int],
    words_by_id: dict[int, dict[str, Any]],
    words_sorted: list[dict[str, Any]],
) -> tuple[list[int], dict[str, Any]]:
    original_word_ids = unique_ints(root.get("word_ids", []))
    selected = [wid for wid in unique_ints(root.get("word_ids", [])) if wid in allowed_word_ids]
    selected = selected[:6]
    selected_set = set(selected)

    supplemental_match_count = 0
    fallback_count = 0

    if len(selected) < 6:
        tokens = extract_root_tokens(str(root.get("root", "")))
        matched: list[tuple[int, int, int, int]] = []

        for word in words_sorted:
            word_id = word.get("id")
            if not isinstance(word_id, int) or word_id in selected_set:
                continue

            lemma = normalize_lemma(word.get("lemma"))
            if not lemma:
                continue

            score: tuple[int, int] | None = None
            for token in tokens:
                if lemma.startswith(token):
                    candidate = (0, -len(token))
                elif token in lemma:
                    candidate = (1, -len(token))
                else:
                    continue

                if score is None or candidate < score:
                    score = candidate

            if score is None:
                continue

            rank_value, _ = rank_key(word)
            matched.append((score[0], score[1], rank_value, word_id))

        matched.sort()
        for _, _, _, word_id in matched:
            if word_id in selected_set:
                continue
            selected.append(word_id)
            selected_set.add(word_id)
            supplemental_match_count += 1
            if len(selected) == 6:
                break

    if len(selected) < 6:
        for word in words_sorted:
            word_id = word.get("id")
            if not isinstance(word_id, int) or word_id in selected_set:
                continue
            selected.append(word_id)
            selected_set.add(word_id)
            fallback_count += 1
            if len(selected) == 6:
                break

    # Safety clamp
    selected = selected[:6]

    if len(selected) != 6:
        raise RuntimeError(
            f"Unable to assign exactly 6 word_ids for root_id={root.get('root_id')} root={root.get('root')}"
        )

    # Ensure all still valid and unique
    if len(set(selected)) != 6:
        raise RuntimeError(f"Duplicate IDs detected in root_id={root.get('root_id')}")
    for word_id in selected:
        if word_id not in allowed_word_ids or word_id not in words_by_id:
            raise RuntimeError(f"Invalid word id {word_id} in root_id={root.get('root_id')}")

    return selected, {
        "root_id": root.get("root_id"),
        "root": root.get("root"),
        "original_word_ids": original_word_ids,
        "selected_word_ids": selected,
        "selected_from_original_count": len([wid for wid in selected if wid in original_word_ids]),
        "supplemental_match_count": supplemental_match_count,
        "fallback_count": fallback_count,
    }


def enrich_prompts() -> tuple[str, str]:
    word_prompt = """You are a senior lexicographer and curriculum editor for the Lexical iOS app.

Task:
Enrich ONLY this batch of words. Do NOT generate roots in this step.

App constraints:
- Synonyms section is hidden when synonym = [].
- Exactly 3 example sentences are needed per word.
- Sentences must be natural, CEFR-appropriate, safe, and useful for intermediate learners.
- cloze_index is 0-based and must point to the target lemma token in each sentence.

Word output schema (strict):
{
  "id": Int,
  "lemma": "lowercase",
  "rank": Int,
  "cefr": "A1|A2|B1|B2|C1|C2",
  "pos": "noun|verb|adj|adv|modal|preposition|conjunction|pronoun|determiner|interjection|name|particle",
  "ipa": "string",
  "definition": "clear learner-friendly definition",
  "synonym": ["..."],
  "fsrs_initial": { "d": 2.03, "s": 0.0, "r": 0.0 },
  "sentences": [
    { "text": "...", "cloze_index": Int },
    { "text": "...", "cloze_index": Int },
    { "text": "...", "cloze_index": Int }
  ]
}

Rules:
- Keep id stable.
- Keep lemma lowercase.
- Keep synonym unique, no lemma itself, max 8; if unreliable, use [].
- Exactly 3 sentences per word.
- Each sentence length: 8–20 words.
- Prefer modern/high-frequency senses.
- No unsafe/offensive content.
- Return valid JSON only.

Input:
{
  "batch_index": {{BATCH_INDEX}},
  "total_batches": {{TOTAL_BATCHES}},
  "words_batch": {{WORDS_BATCH_JSON}}
}

Output:
{
  "batch_index": {{BATCH_INDEX}},
  "words": [ ...enriched words... ],
  "validation": {
    "word_count_matches_input": true/false,
    "all_words_have_3_sentences": true/false,
    "invalid_cloze_index_count": Int,
    "notes": ["..."]
  }
}
"""

    merge_prompt = """You are finalizing Lexical seed data.

Task:
- Merge all enriched word batches.
- Produce final roots with EXACTLY 6 word_ids each.
- Add origin_info for each root.

Root schema:
{
  "root_id": Int,
  "root": "string",
  "basic_meaning": "2-8 words",
  "origin_info": "language + source form + meaning (concise)",
  "word_ids": [Int, Int, Int, Int, Int, Int]
}

Rules:
- word_ids must be unique and exist in final words.
- Exactly 6 word_ids per root.
- Keep root_id and root stable unless explicitly invalid.
- Prefer pedagogically clear morphology links.

Input:
{
  "roots_original": {{ROOTS_JSON}},
  "words_enriched_all_batches": {{WORDS_ENRICHED_ALL_JSON}}
}

Output (strict JSON only):
{
  "roots": [ ...updated roots... ],
  "words": [ ...all enriched words... ],
  "validation": {
    "roots_with_exactly_6_words": true/false,
    "all_word_ids_exist": true/false,
    "duplicate_word_ids_within_root_count": Int,
    "words_with_3_sentences": true/false,
    "invalid_cloze_index_count": Int,
    "notes": ["..."]
  }
}
"""
    return word_prompt, merge_prompt


def validate(words: list[dict[str, Any]], roots: list[dict[str, Any]]) -> dict[str, Any]:
    word_ids = {word.get("id") for word in words if isinstance(word.get("id"), int)}

    roots_with_exactly_six = all(len(unique_ints(root.get("word_ids", []))) == 6 for root in roots)
    invalid_word_id_count = 0
    duplicate_in_root_count = 0

    for root in roots:
        ids = [wid for wid in root.get("word_ids", []) if isinstance(wid, int)]
        if len(ids) != len(set(ids)):
            duplicate_in_root_count += 1
        for word_id in ids:
            if word_id not in word_ids:
                invalid_word_id_count += 1

    a1_remaining = sum(1 for word in words if str(word.get("cefr", "")).upper() == "A1")

    return {
        "word_count": len(words),
        "root_count": len(roots),
        "a1_remaining": a1_remaining,
        "roots_with_exactly_6_words": roots_with_exactly_six,
        "invalid_word_id_count": invalid_word_id_count,
        "roots_with_duplicate_ids": duplicate_in_root_count,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Prepare Lexical DB for batch enrichment")
    parser.add_argument("--seed-path", type=Path, default=DEFAULT_SEED_PATH)
    parser.add_argument("--roots-path", type=Path, default=DEFAULT_ROOTS_PATH)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--batch-size", type=int, default=50)
    parser.add_argument(
        "--remove-cefr",
        nargs="+",
        default=["A1"],
        help="CEFR levels to remove from word DB (default: A1)",
    )
    parser.add_argument("--write-in-place", action="store_true")
    parser.add_argument("--skip-batches", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    words = load_json(args.seed_path)
    roots = load_json(args.roots_path)

    if not isinstance(words, list) or not isinstance(roots, list):
        raise RuntimeError("Expected list JSON payloads for words and roots")

    remove_cefr = {level.upper() for level in args.remove_cefr}

    filtered_words = [
        word
        for word in words
        if str(word.get("cefr", "")).upper() not in remove_cefr
    ]

    words_by_id: dict[int, dict[str, Any]] = {}
    for word in filtered_words:
        word_id = word.get("id")
        if isinstance(word_id, int):
            words_by_id[word_id] = word

    allowed_word_ids = set(words_by_id.keys())
    words_sorted = sorted(filtered_words, key=rank_key)

    updated_roots: list[dict[str, Any]] = []
    total_supplemental_matches = 0
    total_fallbacks = 0
    root_selection_audit: list[dict[str, Any]] = []

    for root in roots:
        root_copy = dict(root)
        selected_ids, stats = choose_root_word_ids(
            root=root_copy,
            allowed_word_ids=allowed_word_ids,
            words_by_id=words_by_id,
            words_sorted=words_sorted,
        )
        root_copy["word_ids"] = selected_ids
        updated_roots.append(root_copy)
        total_supplemental_matches += stats["supplemental_match_count"]
        total_fallbacks += stats["fallback_count"]
        root_selection_audit.append(stats)

    output_dir: Path = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    cleaned_seed_path = output_dir / "seed_data.cleaned.json"
    cleaned_roots_path = output_dir / "roots.cleaned.json"
    save_json(cleaned_seed_path, filtered_words)
    save_json(cleaned_roots_path, updated_roots)
    save_json(
        output_dir / "roots_origin_enrichment_input.json",
        [
            {
                "root_id": root.get("root_id"),
                "root": root.get("root"),
                "basic_meaning": root.get("basic_meaning"),
                "origin_info": root.get("origin_info", ""),
                "word_ids": root.get("word_ids", []),
            }
            for root in updated_roots
        ],
    )

    if args.write_in_place:
        save_json(args.seed_path, filtered_words)
        save_json(args.roots_path, updated_roots)

    batch_manifest: dict[str, Any] = {}
    if not args.skip_batches:
        batches_dir = output_dir / "word_batches"
        batches_dir.mkdir(parents=True, exist_ok=True)

        batch_size = max(1, args.batch_size)
        total_batches = math.ceil(len(filtered_words) / batch_size)

        for index in range(total_batches):
            start = index * batch_size
            end = start + batch_size
            batch_words = filtered_words[start:end]
            payload = {
                "batch_index": index + 1,
                "total_batches": total_batches,
                "words_batch": batch_words,
            }
            save_json(batches_dir / f"batch_{index + 1:03d}.json", payload)

        prompts_dir = output_dir / "prompts"
        prompts_dir.mkdir(parents=True, exist_ok=True)
        word_prompt, merge_prompt = enrich_prompts()

        (prompts_dir / "01_word_batch_prompt.txt").write_text(word_prompt, encoding="utf-8")
        (prompts_dir / "02_final_merge_prompt.txt").write_text(merge_prompt, encoding="utf-8")

        batch_manifest = {
            "batch_size": batch_size,
            "total_batches": total_batches,
            "batches_dir": str(batches_dir),
            "prompts_dir": str(prompts_dir),
        }

    report = {
        "source_seed_path": str(args.seed_path),
        "source_roots_path": str(args.roots_path),
        "removed_cefr_levels": sorted(remove_cefr),
        "original_word_count": len(words),
        "filtered_word_count": len(filtered_words),
        "removed_word_count": len(words) - len(filtered_words),
        "root_count": len(updated_roots),
        "root_supplemental_match_count": total_supplemental_matches,
        "root_fallback_fill_count": total_fallbacks,
        "roots_needing_fallback": [
            {
                "root_id": row["root_id"],
                "root": row["root"],
                "fallback_count": row["fallback_count"],
                "supplemental_match_count": row["supplemental_match_count"],
            }
            for row in root_selection_audit
            if row["fallback_count"] > 0
        ],
        "write_in_place": args.write_in_place,
        "validation": validate(filtered_words, updated_roots),
        "batch_manifest": batch_manifest,
    }

    save_json(output_dir / "report.json", report)
    save_json(output_dir / "root_selection_audit.json", root_selection_audit)

    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
