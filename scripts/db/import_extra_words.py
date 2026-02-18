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
import hashlib
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
    lemma_tokens = TOKEN_PATTERN.findall(lemma.lower())
    if not tokens or not lemma_tokens:
        return 0

    if len(lemma_tokens) > 1:
        for index in range(len(tokens) - len(lemma_tokens) + 1):
            if tokens[index : index + len(lemma_tokens)] == lemma_tokens:
                return index
        return 0

    lemma_token = lemma_tokens[0]
    for index, token in enumerate(tokens):
        if token == lemma_token:
            return index

    # Lightweight inflection matching for provided examples.
    for index, token in enumerate(tokens):
        if token.startswith(lemma_token) or lemma_token.startswith(token):
            return index
        if lemma_token.endswith("e") and token.startswith(lemma_token[:-1]):
            return index
        if token.endswith("ed") and token[:-2] == lemma_token:
            return index
        if token.endswith("ing") and (
            token[:-3] == lemma_token or token[:-3] == lemma_token[:-1]
        ):
            return index
        if token.endswith("es") and (
            token[:-2] == lemma_token or token[:-2] == lemma_token[:-1]
        ):
            return index
        if token.endswith("s") and token[:-1] == lemma_token:
            return index
    return 0


def stable_index(seed: str, size: int) -> int:
    if size <= 0:
        return 0
    digest = hashlib.sha1(seed.encode("utf-8")).digest()
    value = int.from_bytes(digest[:4], byteorder="big", signed=False)
    return value % size


def is_probably_concrete_noun(definition: str) -> bool:
    text = definition.lower().strip()
    abstract_starts = (
        "quality",
        "state",
        "condition",
        "concept",
        "idea",
        "process",
        "act",
        "action",
        "feeling",
        "emotion",
        "ability",
        "practice",
        "behavior",
        "method",
        "system",
        "relationship",
        "attachment",
        "commitment",
    )
    abstract_pattern = re.compile(
        r"^(?:a|an|the)?\s*(?:"
        + "|".join(re.escape(token) for token in abstract_starts)
        + r")\b"
    )
    if abstract_pattern.search(text):
        return False

    concrete_heads = (
        "person",
        "people",
        "animal",
        "plant",
        "object",
        "item",
        "tool",
        "device",
        "machine",
        "material",
        "substance",
        "gas",
        "liquid",
        "vehicle",
        "building",
        "place",
        "organ",
        "body part",
        "chemical element",
        "element",
    )
    concrete_pattern = re.compile(
        r"^(?:a|an|the)?\s*(?:"
        + "|".join(re.escape(token) for token in concrete_heads)
        + r")\b"
    )
    return concrete_pattern.search(text) is not None


def generate_sentence_pack(
    lemma: str,
    pos: str,
    definition: str | None = None,
    cefr: str | None = None,
) -> list[dict[str, Any]]:
    del cefr  # Reserved for future level-aware variation.
    lemma_text = lemma.replace("_", " ").strip()
    normalized_pos = normalize_pos(pos)
    definition_text = clean_definition(definition or "")

    noun_complex_abstract = [
        "Because shift notes were incomplete, recurring mistakes exposed weak {lemma} across teams.",
        "After the compliance audit, leadership treated {lemma} as essential rather than optional.",
        "Although the team had funding, poor {lemma} delayed the launch by two months.",
        "When customer complaints doubled, the manager rebuilt the service {lemma} from scratch.",
    ]
    noun_question_abstract = [
        "During a group project, what {lemma} keeps everyone from duplicating the same task?",
        "If two job offers look similar, which {lemma} helps you decide with confidence?",
        "When a plan starts failing, which signs of weak {lemma} appear first?",
        "In a stressful meeting, what kind of {lemma} makes people trust your judgment?",
    ]
    noun_dialogue_abstract = [
        "\"Without {lemma},\" the coach warned, \"talent collapses the moment pressure rises.\"",
        "\"That single {lemma} changed everything,\" she said after the negotiation finally closed.",
        "\"We had skills but no {lemma},\" he admitted, staring at the failed prototype.",
        "\"Once we built {lemma},\" the founder said, \"customers stopped leaving after one month.\"",
    ]

    noun_complex_concrete = [
        "Because the storm cut power overnight, extra {lemma} became essential in every apartment.",
        "When the shipment finally arrived, each classroom received {lemma} for new experiments.",
        "Although the workshop was full, missing {lemma} stopped the repair immediately.",
        "After the safety inspection, they replaced damaged {lemma} before reopening the site.",
    ]
    noun_question_concrete = [
        "If you were packing for a long trip, which {lemma} would you refuse to leave behind?",
        "When a neighbor asks to borrow {lemma}, what makes you say yes?",
        "At checkout, how can you tell whether {lemma} is worth the higher price?",
        "During an emergency, which {lemma} would you reach for first?",
    ]
    noun_dialogue_concrete = [
        "\"Pass the {lemma},\" the mechanic said, \"or this bolt will not move.\"",
        "\"Keep {lemma} by the door,\" she said, \"we may need it tonight.\"",
        "\"That {lemma} saved us,\" he said, \"when the elevator stalled between floors.\"",
        "\"Guard the {lemma} carefully,\" the guide said, \"there is no spare in camp.\"",
    ]

    verb_complex = [
        "Because witness accounts conflicted, detectives had to {lemma} every detail before filing charges.",
        "When deadlines tightened, strong teams {lemma} early instead of guessing at the end.",
        "Although the chart looked convincing, the analyst paused to {lemma} the assumptions underneath it.",
        "Since the contract was vague, both sides met again to {lemma} before signing.",
    ]
    verb_question = [
        "If a friend shares a shocking rumor, do you {lemma} first or react immediately?",
        "When plans collapse at the last minute, how do you {lemma} the situation and recover quickly?",
        "During a disagreement, can you {lemma} without raising your voice?",
        "If instructions are unclear, do you {lemma} the goal before you begin?",
    ]
    verb_dialogue = [
        "\"Do not {lemma} yet,\" the editor said, \"sleep on it and read again tomorrow.\"",
        "\"We cannot {lemma} this by guessing,\" she said, pointing at the error log.",
        "\"Before you {lemma},\" the coach said, \"watch how the veterans handle it.\"",
        "\"Let us {lemma} together,\" he said, \"so we do not miss the obvious.\"",
    ]

    adjective_complex = [
        "Although his apology sounded {lemma}, nobody believed him after months of broken promises.",
        "Because the market shifted overnight, even a {lemma} forecast failed by noon.",
        "While the design looked {lemma}, users still struggled with basic tasks.",
        "Since the witness was {lemma}, the judge requested independent evidence.",
    ]
    adjective_question = [
        "Would you invest your savings in a plan that still feels this {lemma}?",
        "If your teammate sounded {lemma} before launch day, would you delay the release?",
        "During heavy turbulence, do you trust a pilot who seems this {lemma}?",
        "When advice feels {lemma}, what evidence helps you decide whether to follow it?",
    ]
    adjective_dialogue = [
        "\"The result looks {lemma},\" Maya said, \"but we still need stronger data.\"",
        "\"The plan is too {lemma} for launch day,\" his mentor said, \"tighten it first.\"",
        "\"This route feels {lemma},\" she whispered, checking the weather radar again.",
        "\"His explanation sounded {lemma},\" Jordan said, \"so I asked a second expert.\"",
    ]

    adverb_complex = [
        "Because the procedure changed twice, the crew moved {lemma} and avoided costly mistakes.",
        "When the customer grew angry, the manager replied {lemma} and de-escalated the call.",
        "Although the room was noisy, she listened {lemma} enough to catch one key detail.",
        "Since the margin for error was tiny, the surgeon worked {lemma} for three hours.",
    ]
    adverb_question = [
        "When your alarm fails and you are late, can you still think {lemma} enough to adapt?",
        "If a friend is upset, do you speak {lemma} or rush into advice?",
        "During a difficult exam, how do you breathe {lemma} and stay focused?",
        "When plans change suddenly, can your team respond {lemma} without blaming each other?",
    ]
    adverb_dialogue = [
        "\"Explain it {lemma},\" the teacher said, \"your cousin is hearing this for the first time.\"",
        "\"Drive {lemma},\" she warned, \"the bridge is still icy after sunset.\"",
        "\"Answer {lemma},\" the lawyer whispered, \"the judge is watching your reaction.\"",
        "\"Move {lemma},\" the medic said, \"he is in shock and barely standing.\"",
    ]

    if normalized_pos == "verb":
        complex_templates = verb_complex
        question_templates = verb_question
        dialogue_templates = verb_dialogue
    elif normalized_pos == "adjective":
        complex_templates = adjective_complex
        question_templates = adjective_question
        dialogue_templates = adjective_dialogue
    elif normalized_pos == "adverb":
        complex_templates = adverb_complex
        question_templates = adverb_question
        dialogue_templates = adverb_dialogue
    else:
        concrete = is_probably_concrete_noun(definition_text)
        if concrete:
            complex_templates = noun_complex_concrete
            question_templates = noun_question_concrete
            dialogue_templates = noun_dialogue_concrete
        else:
            complex_templates = noun_complex_abstract
            question_templates = noun_question_abstract
            dialogue_templates = noun_dialogue_abstract

    templates = [
        complex_templates[stable_index(f"{lemma_text}:complex", len(complex_templates))],
        question_templates[stable_index(f"{lemma_text}:question", len(question_templates))],
        dialogue_templates[stable_index(f"{lemma_text}:dialogue", len(dialogue_templates))],
    ]

    return [
        {
            "text": text.format(lemma=lemma_text),
            "cloze_index": cloze_index_for(lemma_text, text.format(lemma=lemma_text)),
        }
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
        sentences = generate_sentence_pack(lemma, pos, definition=definition, cefr=cefr)

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
