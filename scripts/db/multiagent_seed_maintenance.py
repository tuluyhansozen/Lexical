#!/usr/bin/env python3
"""Batch-evaluate and repair seed sentences/synonyms via multi-agent workers.

Agent model:
- SentenceAgent: detects low-quality/duplicate/misaligned sentence packs and rewrites them.
- SynonymAgent: dedupes/filters synonym lists to safe, valid entries.
- RowWorker (parallel): applies both agents to each target row.
"""

from __future__ import annotations

import argparse
import json
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any

from clean_seed_quality import (
    compile_unsafe_regexes,
    is_valid_synonym,
    normalize_whitespace,
)
from import_extra_words import cloze_index_for, generate_sentence_pack


@dataclass
class AgentFinding:
    needs_update: bool
    issues: list[str]
    updates: dict[str, Any]


@dataclass
class RowResult:
    index: int
    row_id: int | None
    updated_row: dict[str, Any]
    sentence_issues: list[str]
    synonym_issues: list[str]
    sentence_updated: bool
    synonym_updated: bool


class SentenceAgent:
    def __init__(self, duplicate_threshold: float = 0.92) -> None:
        self.duplicate_threshold = duplicate_threshold

    def _has_near_duplicates(self, texts: list[str]) -> bool:
        lowered = [text.lower() for text in texts if text]
        for left in range(len(lowered)):
            for right in range(left + 1, len(lowered)):
                ratio = SequenceMatcher(None, lowered[left], lowered[right]).ratio()
                if ratio >= self.duplicate_threshold:
                    return True
        return False

    def evaluate(self, row: dict[str, Any]) -> AgentFinding:
        lemma = str(row.get("lemma", "")).strip().lower()
        pos = str(row.get("pos", "")).strip().lower()
        definition = str(row.get("definition", ""))
        cefr = str(row.get("cefr", ""))

        issues: list[str] = []
        sentences = row.get("sentences", [])
        if not isinstance(sentences, list):
            sentences = []
            issues.append("sentences_not_list")

        if len(sentences) != 3:
            issues.append("invalid_sentence_count")

        normalized_texts: list[str] = []
        for sentence in sentences:
            if not isinstance(sentence, dict):
                issues.append("invalid_sentence_item")
                continue

            text = normalize_whitespace(str(sentence.get("text", "")))
            if not text:
                issues.append("empty_sentence_text")
                continue
            normalized_texts.append(text)

            expected_cloze = cloze_index_for(lemma, text)
            current_cloze = sentence.get("cloze_index")
            if not isinstance(current_cloze, int) or current_cloze != expected_cloze:
                issues.append("cloze_mismatch")

        lowered = [text.lower() for text in normalized_texts]
        if len(set(lowered)) != len(lowered):
            issues.append("duplicate_sentences")
        if self._has_near_duplicates(normalized_texts):
            issues.append("near_duplicate_sentences")

        unique_issues = sorted(set(issues))
        if not unique_issues:
            return AgentFinding(needs_update=False, issues=[], updates={})

        rewritten = generate_sentence_pack(
            lemma=lemma,
            pos=pos,
            definition=definition,
            cefr=cefr,
        )
        return AgentFinding(
            needs_update=True,
            issues=unique_issues,
            updates={"sentences": rewritten},
        )


class SynonymAgent:
    def __init__(self) -> None:
        self.blocked = compile_unsafe_regexes()

    def evaluate(self, row: dict[str, Any]) -> AgentFinding:
        lemma = str(row.get("lemma", "")).strip().lower()
        raw_synonyms = row.get("synonym", [])
        issues: list[str] = []

        if not isinstance(raw_synonyms, list):
            raw_synonyms = []
            issues.append("synonym_not_list")

        cleaned: list[str] = []
        seen: set[str] = set()
        for candidate in raw_synonyms:
            text = normalize_whitespace(str(candidate))
            if not text:
                issues.append("empty_synonym")
                continue
            if not is_valid_synonym(text, lemma, self.blocked):
                issues.append("invalid_synonym")
                continue

            key = text.lower()
            if key in seen:
                issues.append("duplicate_synonym")
                continue
            seen.add(key)
            cleaned.append(text)

        cleaned = cleaned[:8]
        if cleaned != raw_synonyms:
            issues.append("synonym_normalized")

        unique_issues = sorted(set(issues))
        if not unique_issues:
            return AgentFinding(needs_update=False, issues=[], updates={})

        return AgentFinding(
            needs_update=True,
            issues=unique_issues,
            updates={"synonym": cleaned},
        )


def _process_row(
    index: int,
    row: dict[str, Any],
    sentence_agent: SentenceAgent,
    synonym_agent: SynonymAgent,
) -> RowResult:
    updated = dict(row)

    sentence_finding = sentence_agent.evaluate(row)
    synonym_finding = synonym_agent.evaluate(row)

    if sentence_finding.needs_update:
        updated["sentences"] = sentence_finding.updates["sentences"]
    if synonym_finding.needs_update:
        updated["synonym"] = synonym_finding.updates["synonym"]

    return RowResult(
        index=index,
        row_id=row.get("id") if isinstance(row.get("id"), int) else None,
        updated_row=updated,
        sentence_issues=sentence_finding.issues,
        synonym_issues=synonym_finding.issues,
        sentence_updated=sentence_finding.needs_update,
        synonym_updated=synonym_finding.needs_update,
    )


def run_multiagent_batch(
    rows: list[dict[str, Any]],
    *,
    target_ids: set[int] | None = None,
    workers: int = 8,
    duplicate_threshold: float = 0.92,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    sentence_agent = SentenceAgent(duplicate_threshold=duplicate_threshold)
    synonym_agent = SynonymAgent()

    processed_rows = list(rows)
    target_indexes = [
        index
        for index, row in enumerate(rows)
        if target_ids is None or row.get("id") in target_ids
    ]

    results: list[RowResult] = []
    max_workers = max(1, min(workers, len(target_indexes) if target_indexes else 1))
    with ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = [
            pool.submit(
                _process_row,
                index,
                rows[index],
                sentence_agent,
                synonym_agent,
            )
            for index in target_indexes
        ]
        for future in futures:
            results.append(future.result())

    sentence_updated_count = 0
    synonym_updated_count = 0
    updated_ids: list[int] = []
    rows_with_sentence_issues: list[int] = []
    rows_with_synonym_issues: list[int] = []

    for result in sorted(results, key=lambda item: item.index):
        processed_rows[result.index] = result.updated_row
        if result.sentence_updated:
            sentence_updated_count += 1
            if result.row_id is not None:
                rows_with_sentence_issues.append(result.row_id)
        if result.synonym_updated:
            synonym_updated_count += 1
            if result.row_id is not None:
                rows_with_synonym_issues.append(result.row_id)
        if (result.sentence_updated or result.synonym_updated) and result.row_id is not None:
            updated_ids.append(result.row_id)

    summary = {
        "rows_scanned": len(target_indexes),
        "rows_updated": len(updated_ids),
        "rows_sentence_updated": sentence_updated_count,
        "rows_synonym_updated": synonym_updated_count,
        "updated_ids": sorted(updated_ids),
        "rows_with_sentence_issues": sorted(rows_with_sentence_issues),
        "rows_with_synonym_issues": sorted(rows_with_synonym_issues),
    }
    return processed_rows, summary


def parse_target_ids(values: list[str]) -> set[int]:
    parsed: set[int] = set()
    for value in values:
        for token in value.split(","):
            token = token.strip()
            if not token:
                continue
            parsed.add(int(token))
    return parsed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Evaluate and repair seed sentences/synonyms with parallel multi-agent workers."
    )
    parser.add_argument(
        "--seed-path",
        type=Path,
        default=Path("Lexical/Resources/Seeds/seed_data.json"),
    )
    parser.add_argument(
        "--ids",
        nargs="*",
        default=[],
        help="Optional IDs to process (space or comma separated).",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=8,
        help="Parallel row workers.",
    )
    parser.add_argument(
        "--duplicate-threshold",
        type=float,
        default=0.92,
        help="Similarity ratio threshold for near-duplicate sentence detection.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Evaluate and report updates without writing changes.",
    )
    parser.add_argument(
        "--report-path",
        type=Path,
        default=None,
        help="Optional JSON output path for summary report.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    rows = json.loads(args.seed_path.read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        raise ValueError("Seed payload must be a JSON array")

    target_ids = parse_target_ids(args.ids) if args.ids else None

    updated_rows, summary = run_multiagent_batch(
        rows,
        target_ids=target_ids,
        workers=args.workers,
        duplicate_threshold=args.duplicate_threshold,
    )

    print(json.dumps(summary, indent=2))

    if args.report_path is not None:
        args.report_path.parent.mkdir(parents=True, exist_ok=True)
        args.report_path.write_text(
            json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    if not args.dry_run and summary["rows_updated"] > 0:
        args.seed_path.write_text(
            json.dumps(updated_rows, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"Wrote updated seed data to {args.seed_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
