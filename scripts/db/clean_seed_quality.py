#!/usr/bin/env python3
"""Clean Lexical seed_data.json for safety and baseline quality.

What this script does:
- Removes explicitly blocked unsafe lemmas.
- Cleans synonyms (offensive/markup/garbage/duplicates/very short items).
- Cleans sentences and repairs cloze_index alignment.
- Ensures each remaining row has exactly 3 usable example sentences.

Usage:
  python scripts/db/clean_seed_quality.py \
    --seed-path Lexical/Resources/Seeds/seed_data.json
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any


UNSAFE_LEMMA_SET = {
    "rape",
    "suicide",
    "terrorist",
}

UNSAFE_PATTERNS = [
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
    r"\bnazi(?:s)?\b",
    r"\bsex\s+offender(?:s)?\b",
]

PLACEHOLDER_RE = re.compile(
    r"<[^>]+>|\{\{[^}]+\}\}|\b(?:scenario|placeholder|sample|template)_word_\d+\b|lorem ipsum",
    re.IGNORECASE,
)

WORD_RE = re.compile(r"[A-Za-z]+(?:'[A-Za-z]+)?")

STOPWORD_SYNONYMS = {
    "a",
    "an",
    "the",
    "and",
    "or",
    "to",
    "of",
    "in",
    "on",
    "for",
    "by",
    "with",
    "as",
    "is",
    "are",
    "was",
    "were",
    "be",
    "been",
    "being",
    "from",
    "at",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Clean lexical seed_data.json quality issues")
    parser.add_argument(
        "--seed-path",
        type=Path,
        default=Path("Lexical/Resources/Seeds/seed_data.json"),
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report cleanup stats without writing the file.",
    )
    return parser.parse_args()


def compile_unsafe_regexes() -> list[re.Pattern[str]]:
    return [re.compile(pattern, re.IGNORECASE) for pattern in UNSAFE_PATTERNS]


def normalize_whitespace(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def letters_only(value: str) -> str:
    return re.sub(r"[^a-z]", "", value.lower())


def is_unsafe_text(text: str, blocked: list[re.Pattern[str]]) -> bool:
    return any(regex.search(text) for regex in blocked)


def lemma_tokens(lemma: str) -> list[str]:
    normalized = lemma.replace("_", " ").lower()
    return [token for token in re.split(r"[^a-z]+", normalized) if token]


def token_matches_lemma(token: str, lemma: str) -> bool:
    token = token.lower()
    lemma = lemma.lower().replace("_", " ")
    if token == lemma:
        return True

    forms = {lemma, lemma + "s", lemma + "es", lemma + "ed", lemma + "ing"}
    if lemma.endswith("y") and len(lemma) > 2:
        forms.add(lemma[:-1] + "ies")
    if lemma.endswith("e"):
        forms.add(lemma[:-1] + "ing")
    return token in forms


def find_cloze_index(tokens: list[str], lemma: str) -> int | None:
    for idx, token in enumerate(tokens):
        if token_matches_lemma(token, lemma):
            return idx

    ltokens = lemma_tokens(lemma)
    if len(ltokens) > 1:
        lowered = [token.lower() for token in tokens]
        for idx in range(len(lowered) - len(ltokens) + 1):
            if lowered[idx : idx + len(ltokens)] == ltokens:
                return idx

    return None


def fallback_sentences(lemma: str, pos: str) -> list[dict[str, Any]]:
    lemma_text = lemma.replace("_", " ")

    if pos == "verb":
        candidates = [
            f"We {lemma_text} this skill during our daily practice session.",
            f"You can {lemma_text} the idea in a new context.",
            f"Learners {lemma_text} better when they review consistently.",
        ]
    elif pos in {"adj", "adjective"}:
        candidates = [
            f"The final explanation felt {lemma_text} after careful revision.",
            f"Her notes became more {lemma_text} over the week.",
            f"A {lemma_text} example helped the group remember the concept.",
        ]
    elif pos in {"adv", "adverb"}:
        candidates = [
            f"The team worked {lemma_text} to finish the reading task.",
            f"He replied {lemma_text} when the teacher asked for feedback.",
            f"They discussed the topic {lemma_text} before the review started.",
        ]
    else:
        candidates = [
            f"The article introduced {lemma_text} with a practical example.",
            f"In review, I used {lemma_text} in a clear sentence.",
            f"Understanding {lemma_text} helps explain the main idea.",
        ]

    generated: list[dict[str, Any]] = []
    for candidate in candidates:
        tokens = WORD_RE.findall(candidate)
        cloze_index = find_cloze_index(tokens, lemma)
        if cloze_index is None:
            continue
        generated.append({"text": candidate, "cloze_index": cloze_index})
    return generated


def is_valid_synonym(candidate: str, lemma: str, blocked: list[re.Pattern[str]]) -> bool:
    value = normalize_whitespace(candidate)
    if not value:
        return False

    lowered = value.lower()
    if lowered == lemma:
        return False

    if is_unsafe_text(value, blocked):
        return False
    if PLACEHOLDER_RE.search(value):
        return False

    pure_letters = letters_only(value)
    if len(pure_letters) < 3:
        return False

    if lowered in STOPWORD_SYNONYMS:
        return False

    if len(value.split()) > 4:
        return False

    if re.search(r"[<>\[\]{};$]", value):
        return False
    if re.search(r"\d", value):
        return False
    if re.search(r"[./]", value):
        return False

    if all(ch.isupper() for ch in value if ch.isalpha()) and len(pure_letters) <= 4:
        return False

    if re.search(
        r"\b(?:appendix|packaging|formalized|chiefly used|google hits|word conveys)\b",
        lowered,
    ):
        return False

    return True


def clean_seed_rows(rows: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], Counter[str]]:
    blocked = compile_unsafe_regexes()
    stats: Counter[str] = Counter()
    cleaned: list[dict[str, Any]] = []

    for row in rows:
        lemma = normalize_whitespace(str(row.get("lemma", "")).lower())
        lemma = lemma.replace("_", " ")

        if lemma in UNSAFE_LEMMA_SET:
            stats["removed_unsafe_lemma"] += 1
            continue

        row["lemma"] = lemma

        # Synonym cleanup
        new_synonyms: list[str] = []
        seen_synonyms: set[str] = set()
        for synonym in row.get("synonym", []) or []:
            synonym_text = normalize_whitespace(str(synonym))
            if not is_valid_synonym(synonym_text, lemma, blocked):
                stats["synonym_removed"] += 1
                continue

            key = synonym_text.lower()
            if key in seen_synonyms:
                stats["synonym_removed_duplicate"] += 1
                continue

            seen_synonyms.add(key)
            new_synonyms.append(synonym_text)
        row["synonym"] = new_synonyms[:8]

        # Sentence cleanup + cloze repair
        pos = str(row.get("pos", "")).strip().lower()
        kept_sentences: list[dict[str, Any]] = []
        seen_sentence_text: set[str] = set()

        for sentence in row.get("sentences", []) or []:
            text = normalize_whitespace(str(sentence.get("text", "")))
            if not text:
                stats["sentence_removed_empty"] += 1
                continue

            if is_unsafe_text(text, blocked) or PLACEHOLDER_RE.search(text):
                stats["sentence_removed_unsafe_or_placeholder"] += 1
                continue

            tokens = WORD_RE.findall(text)
            if len(tokens) < 6 or len(tokens) > 35:
                stats["sentence_removed_length"] += 1
                continue

            cloze_index = sentence.get("cloze_index")
            cloze_valid = (
                isinstance(cloze_index, int)
                and 0 <= cloze_index < len(tokens)
                and token_matches_lemma(tokens[cloze_index], lemma)
            )

            if not cloze_valid:
                repaired = find_cloze_index(tokens, lemma)
                if repaired is None:
                    stats["sentence_removed_no_target"] += 1
                    continue
                cloze_index = repaired
                stats["sentence_cloze_repaired"] += 1

            lowered_text = text.lower()
            if lowered_text in seen_sentence_text:
                stats["sentence_removed_duplicate"] += 1
                continue

            seen_sentence_text.add(lowered_text)
            kept_sentences.append({"text": text, "cloze_index": cloze_index})
            if len(kept_sentences) == 3:
                break

        if len(kept_sentences) < 3:
            for fallback in fallback_sentences(lemma, pos):
                lowered_text = fallback["text"].lower()
                if lowered_text in seen_sentence_text:
                    continue
                kept_sentences.append(fallback)
                seen_sentence_text.add(lowered_text)
                stats["sentence_added_fallback"] += 1
                if len(kept_sentences) == 3:
                    break

        row["sentences"] = kept_sentences[:3]
        cleaned.append(row)

    return cleaned, stats


def verify_no_unsafe(rows: list[dict[str, Any]]) -> int:
    blocked = compile_unsafe_regexes()
    violations = 0

    for row in rows:
        values = [
            str(row.get("lemma", "")),
            *[str(x) for x in (row.get("synonym", []) or [])],
            *[str(s.get("text", "")) for s in (row.get("sentences", []) or [])],
        ]
        for value in values:
            if is_unsafe_text(value, blocked):
                violations += 1
    return violations


def main() -> int:
    args = parse_args()
    rows = json.loads(args.seed_path.read_text(encoding="utf-8"))

    cleaned, stats = clean_seed_rows(rows)
    unsafe_after = verify_no_unsafe(cleaned)

    print(f"Input rows: {len(rows)}")
    print(f"Output rows: {len(cleaned)}")
    print(f"Unsafe text residues: {unsafe_after}")
    print("Stats:")
    for key, value in sorted(stats.items()):
        print(f"  - {key}: {value}")

    if unsafe_after > 0:
        print("Cleanup failed: unsafe content still present.")
        return 1

    if not args.dry_run:
        args.seed_path.write_text(
            json.dumps(cleaned, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"Wrote cleaned seed to {args.seed_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
