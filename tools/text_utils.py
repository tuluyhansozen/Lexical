#!/usr/bin/env python3
"""Text utilities for seed sentence validation and cloze indexing."""

from __future__ import annotations

from difflib import SequenceMatcher
import re
from typing import Any

TOKEN_RE = re.compile(r"\w+(?:'\w+)?|[^\w\s]")
WORDLIKE_RE = re.compile(r"\w+(?:'\w+)?")
COMPLEX_MARKERS = {
    "although",
    "while",
    "because",
    "unless",
    "since",
    "if",
    "when",
    "after",
    "before",
    "though",
    "whereas",
}
MIN_WORDLIKE_COUNT = 8
MAX_WORDLIKE_COUNT = 14


def tokenize(text: Any) -> list[str]:
    """Tokenize text using the deterministic regex contract."""
    return TOKEN_RE.findall(str(text or ""))


def wordlike_count(tokens: list[str]) -> int:
    """Count word-like tokens only."""
    return sum(1 for token in tokens if WORDLIKE_RE.fullmatch(token))


def find_cloze_index(text: Any, lemma: Any) -> int | None:
    """Find the first exact-token lemma index, case-insensitive."""
    target = str(lemma or "").strip().lower()
    if not target:
        return None

    for idx, token in enumerate(tokenize(text)):
        if token.lower() == target:
            return idx
    return None


def validate_sentence(text: Any, lemma: Any) -> tuple[bool, list[str]]:
    """Validate hard sentence constraints for one lemma occurrence and length."""
    reasons: list[str] = []
    tokens = tokenize(text)
    count = wordlike_count(tokens)

    if find_cloze_index(text, lemma) is None:
        reasons.append("lemma_missing")
    if count < MIN_WORDLIKE_COUNT:
        reasons.append("word_count_lt_8")
    if count > MAX_WORDLIKE_COUNT:
        reasons.append("word_count_gt_14")

    return (len(reasons) == 0, reasons)


def diversity_signature(text: Any) -> dict[str, Any]:
    """Build a lightweight signature for set-level diversity checks."""
    raw = str(text or "")
    tokens = tokenize(raw)
    words = [token for token in tokens if WORDLIKE_RE.fullmatch(token)]
    lowered_words = [word.lower() for word in words]

    has_question = "?" in raw
    has_quote = any(ch in raw for ch in ('"', "“", "”"))
    has_complex_clause = any(word in COMPLEX_MARKERS for word in lowered_words)
    starts_with = lowered_words[0] if lowered_words else ""

    terminal = ""
    for token in reversed(tokens):
        if token.strip():
            terminal = token
            break

    punctuation_pattern = (
        f"{terminal}|q={int(has_question)}|quote={int(has_quote)}|complex={int(has_complex_clause)}"
    )

    return {
        "has_question": has_question,
        "has_quote": has_quote,
        "has_complex_clause": has_complex_clause,
        "starts_with": starts_with,
        "punctuation_pattern": punctuation_pattern,
    }


def validate_set(sentences_texts: list[str]) -> tuple[bool, list[str]]:
    """Validate set-level diversity constraints using simple heuristics."""
    reasons: list[str] = []
    signatures = [diversity_signature(text) for text in sentences_texts]

    if not any(
        sig["has_question"] or sig["has_quote"] or sig["has_complex_clause"]
        for sig in signatures
    ):
        reasons.append("set_missing_question_or_dialogue_or_complex")

    starts = [sig["starts_with"] for sig in signatures]
    if starts and len(set(starts)) == 1:
        reasons.append("set_all_same_start_token")

    punct_patterns = [sig["punctuation_pattern"] for sig in signatures]
    if punct_patterns and len(set(punct_patterns)) == 1:
        reasons.append("set_all_same_punctuation_pattern")

    return (len(reasons) == 0, reasons)


def sentence_skeleton(text: Any, lemma: Any) -> str:
    """Normalize sentence shape by replacing exact lemma tokens with {LEMMA}."""
    target = str(lemma or "").strip().lower()
    tokens = tokenize(text)
    normalized: list[str] = []
    for token in tokens:
        if target and token.lower() == target:
            normalized.append("{LEMMA}")
        else:
            normalized.append(token.lower())
    skeleton = " ".join(normalized)
    return re.sub(r"\s+", " ", skeleton).strip()


def pairwise_similarity(left: Any, right: Any) -> float:
    """Compute normalized string similarity for near-duplicate checks."""
    a = re.sub(r"\s+", " ", str(left or "").strip().lower())
    b = re.sub(r"\s+", " ", str(right or "").strip().lower())
    if not a and not b:
        return 1.0
    return SequenceMatcher(None, a, b).ratio()


def has_near_duplicates(sentences: list[str], threshold: float = 0.9) -> bool:
    """Detect whether any pair of sentences are near-duplicates by ratio."""
    for i in range(len(sentences)):
        for j in range(i + 1, len(sentences)):
            if pairwise_similarity(sentences[i], sentences[j]) >= threshold:
                return True
    return False
