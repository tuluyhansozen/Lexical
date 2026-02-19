#!/usr/bin/env python3
"""Improve existing seed example sentences with minimal edits and strict validation."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import re
import sys
import time
import urllib.error
import urllib.request
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any

from tools.text_utils import diversity_signature, find_cloze_index, validate_sentence, validate_set

DEFAULT_INPUT = Path("/Users/tuluyhan/projects/Lexical/Lexical/Resources/Seeds/seed_data.json")
DEFAULT_MODEL = "qwen2.5:14b"
DEFAULT_OLLAMA_URL = "http://127.0.0.1:11434"
SEVERITY_RANK = {"none": 0, "minor": 1, "major": 2, "fatal": 3}
STYLE_ORDER = ["question", "dialogue", "complex"]
COMPLEX_CLAUSE_HINT = "although/while/because/unless/since/if/when/after/before/though/whereas"
MAX_GENERATION_RETRIES = 5
TEXTBOOK_PATTERNS = [
    r"\bwe practiced the word\b",
    r"\bin class today\b",
    r"\bthis sentence\b",
    r"\bexample sentence\b",
    r"\bin a clear context\b",
]
FIXED_SHIFT_RULES: dict[str, list[tuple[str, str]]] = {
    "management": [
        ("executive", "time management"),
        ("executive", "project management"),
        ("executive", "risk management"),
    ],
}
MODAL_LEMMAS = {"can", "could", "may", "might", "must", "shall", "should", "will", "would"}
AUXILIARY_LEMMAS = {"be", "am", "is", "are", "was", "were", "been", "being", "have", "has", "had", "do", "does", "did"}


def normalize_pos_tag(pos: str) -> str:
    lowered = normalize_text(pos).lower()
    if "adj" in lowered:
        return "adjective"
    if "adv" in lowered:
        return "adverb"
    if "verb" in lowered:
        return "verb"
    if "noun" in lowered:
        return "noun"
    return "other"


def parse_args() -> argparse.Namespace:
    def str_to_bool(value: str | bool) -> bool:
        if isinstance(value, bool):
            return value
        lowered = str(value).strip().lower()
        if lowered in {"1", "true", "yes", "y", "on"}:
            return True
        if lowered in {"0", "false", "no", "n", "off"}:
            return False
        raise argparse.ArgumentTypeError(f"Invalid boolean value: {value}")

    parser = argparse.ArgumentParser(description="Improve seed sentence quality in-place with resume support")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--checkpoint", type=Path, default=None)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--chunk-size", type=int, default=200)
    parser.add_argument("--mode", type=str, choices=["strict_llm", "turbo_deterministic"], default="strict_llm")
    parser.add_argument("--model", type=str, default=DEFAULT_MODEL)
    parser.add_argument("--ollama-url", type=str, default=DEFAULT_OLLAMA_URL)
    parser.add_argument("--fallback-stop-pct", type=float, default=5.0)
    parser.add_argument("--fallback-max-pct", type=float, default=10.0)
    parser.add_argument("--qa-sample-rate", type=float, default=0.02)
    parser.add_argument("--qa-model", type=str, default=DEFAULT_MODEL)
    parser.add_argument("--qa-fail-threshold", type=float, default=0.05)
    parser.add_argument("--strip-sentences-old-final", type=str_to_bool, default=True)
    parser.add_argument("--workers", type=int, default=1)
    return parser.parse_args()


def load_json_array(path: Path) -> list[dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise ValueError(f"Expected JSON array at {path}")
    return payload


def write_json_array(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def partial_output_path(output_path: Path) -> Path:
    return output_path.with_name(f"{output_path.stem}.partial{output_path.suffix}")


def normalize_text(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def normalize_sentence_texts(raw_sentences: Any) -> list[str]:
    texts: list[str] = []
    if isinstance(raw_sentences, list):
        for sentence in raw_sentences[:3]:
            if isinstance(sentence, dict):
                texts.append(normalize_text(sentence.get("text", "")))
            else:
                texts.append(normalize_text(sentence))
    while len(texts) < 3:
        texts.append("")
    return texts[:3]


def read_processed_ids(checkpoint_path: Path) -> set[int]:
    processed: set[int] = set()
    if not checkpoint_path.exists():
        return processed

    for line in checkpoint_path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        try:
            record = json.loads(stripped)
            processed_id = int(record.get("id"))
            processed.add(processed_id)
        except Exception as exc:  # pragma: no cover - defensive guard
            raise ValueError(f"Invalid checkpoint line: {stripped[:160]}") from exc
    return processed


def append_checkpoint(checkpoint_path: Path, record: dict[str, Any]) -> None:
    checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
    with checkpoint_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")


def extract_json_object(text: str) -> dict[str, Any]:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?", "", cleaned).strip()
        cleaned = re.sub(r"```$", "", cleaned).strip()

    try:
        payload = json.loads(cleaned)
        if isinstance(payload, dict):
            return payload
    except json.JSONDecodeError:
        pass

    start = cleaned.find("{")
    end = cleaned.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise ValueError("No JSON object found in model response")

    payload = json.loads(cleaned[start : end + 1])
    if not isinstance(payload, dict):
        raise ValueError("Model response JSON must be an object")
    return payload


def ollama_generate_json(
    *,
    ollama_url: str,
    model: str,
    prompt: str,
    temperature: float,
    timeout_s: int = 150,
    num_predict: int | None = None,
) -> dict[str, Any]:
    endpoint = ollama_url.rstrip("/") + "/api/generate"
    options: dict[str, Any] = {
        "temperature": temperature,
    }
    if num_predict is not None:
        options["num_predict"] = int(num_predict)

    body = {
        "model": model,
        "prompt": prompt,
        "format": "json",
        "stream": False,
        "keep_alive": "30m",
        "options": options,
    }
    request = urllib.request.Request(
        endpoint,
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )

    try:
        with urllib.request.urlopen(request, timeout=timeout_s) as response:
            response_payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Ollama request failed: {exc}") from exc

    if not isinstance(response_payload, dict) or "response" not in response_payload:
        raise RuntimeError("Malformed Ollama response payload")

    raw_response = str(response_payload.get("response", ""))
    return extract_json_object(raw_response)


def build_review_prompt(
    *,
    lemma: str,
    definition: str,
    pos: str,
    cefr: str,
    sentences: list[str],
) -> str:
    sentence_block = "\n".join(f"{idx}) {text}" for idx, text in enumerate(sentences))
    return f"""
Evaluate 3 sentences for lemma "{lemma}".
Definition: "{definition}"
POS: {pos}
CEFR: {cefr}
Sentences:
{sentence_block}

Rules:
- Fatal: exact lemma token missing OR word-like count outside 8..25.
- Major: meaning mismatch (including fixed-phrase shift), awkward English, or trivial textbook style.
- KEEP only if score >= 75 and no fatal/major.
- If action is REWRITE, output one natural sentence (8-25 words) with exact lemma token.

Output STRICT JSON only:
{{
  "sentences": [
    {{"index": 0, "score": 0, "severity": "none|minor|major|fatal", "action": "KEEP|REWRITE", "reasons": ["code"], "rewrite": ""}},
    {{"index": 1, "score": 0, "severity": "none|minor|major|fatal", "action": "KEEP|REWRITE", "reasons": ["code"], "rewrite": ""}},
    {{"index": 2, "score": 0, "severity": "none|minor|major|fatal", "action": "KEEP|REWRITE", "reasons": ["code"], "rewrite": ""}}
  ]
}}
Use short reason codes only, no prose.
""".strip()


def normalize_review_payload(payload: dict[str, Any]) -> dict[int, dict[str, Any]]:
    normalized: dict[int, dict[str, Any]] = {
        idx: {
            "index": idx,
            "score": 0.0,
            "severity": "none",
            "reasons": [],
            "action": "KEEP",
            "rewrite": "",
        }
        for idx in range(3)
    }

    rows = payload.get("sentences", [])
    if not isinstance(rows, list):
        rows = []

    for row in rows:
        if not isinstance(row, dict):
            continue
        idx_raw = row.get("index")
        if not isinstance(idx_raw, int) or idx_raw not in {0, 1, 2}:
            continue

        score_raw = row.get("score", 0)
        try:
            score = max(0.0, min(100.0, float(score_raw)))
        except Exception:
            score = 0.0

        severity = str(row.get("severity", "none")).strip().lower()
        if severity not in SEVERITY_RANK:
            severity = "none"

        action = str(row.get("action", "KEEP")).strip().upper()
        if action not in {"KEEP", "REWRITE"}:
            action = "KEEP"

        reasons_raw = row.get("reasons", [])
        reasons = [str(x).strip() for x in reasons_raw] if isinstance(reasons_raw, list) else []
        reasons = [x for x in reasons if x]

        rewrite = normalize_text(row.get("rewrite", ""))

        normalized[idx_raw] = {
            "index": idx_raw,
            "score": score,
            "severity": severity,
            "reasons": reasons,
            "action": action,
            "rewrite": rewrite,
        }

    return normalized


def deterministic_major_reasons(*, text: str, lemma: str, definition: str) -> list[str]:
    lowered = normalize_text(text).lower()
    lemma_lower = lemma.lower()
    definition_lower = definition.lower()
    reasons: list[str] = []

    for pattern in TEXTBOOK_PATTERNS:
        if re.search(pattern, lowered):
            reasons.append("textbook_style")
            break

    simple_tokens = re.findall(r"\w+(?:'\w+)?", lowered)
    if simple_tokens:
        if (
            len(simple_tokens) <= 10
            and simple_tokens[0] in {"he", "she", "they", "i", "we", "you"}
            and "?" not in lowered
            and '"' not in lowered
            and not any(marker in simple_tokens for marker in COMPLEX_CLAUSE_HINT.split("/"))
        ):
            reasons.append("trivial_no_context")

    if re.search(rf"\bword {re.escape(lemma_lower)}\b", lowered):
        reasons.append("meta_mention")

    if re.search(r"\bto\s+(might|may|can|could|must|should|would|will|shall)\b", lowered):
        reasons.append("awkward_modal_infinitive")

    for def_hint, phrase in FIXED_SHIFT_RULES.get(lemma_lower, []):
        if def_hint in definition_lower and phrase in lowered:
            reasons.append("meaning_shift_fixed_expression")
            break

    return list(dict.fromkeys(reasons))


def deterministic_review_item_once(
    *,
    lemma: str,
    definition: str,
    sentences: list[str],
) -> dict[int, dict[str, Any]]:
    review: dict[int, dict[str, Any]] = {}
    for idx, text in enumerate(sentences):
        ok, fatal_reasons = validate_sentence(text, lemma)
        major_reasons = deterministic_major_reasons(text=text, lemma=lemma, definition=definition)

        severity = "none"
        action = "KEEP"
        score = 85.0
        reasons: list[str] = []

        if not ok:
            severity = "fatal"
            action = "REWRITE"
            score = 0.0
            reasons = list(fatal_reasons)
        elif major_reasons:
            severity = "major"
            action = "REWRITE"
            score = 60.0
            reasons = list(major_reasons)

        review[idx] = {
            "index": idx,
            "score": score,
            "severity": severity,
            "reasons": reasons,
            "action": action,
            "rewrite": "",
        }

    return review


def review_item_once(
    *,
    ollama_url: str,
    model: str,
    lemma: str,
    definition: str,
    pos: str,
    cefr: str,
    sentences: list[str],
) -> dict[int, dict[str, Any]]:
    prompt = build_review_prompt(
        lemma=lemma,
        definition=definition,
        pos=pos,
        cefr=cefr,
        sentences=sentences,
    )
    payload = ollama_generate_json(
        ollama_url=ollama_url,
        model=model,
        prompt=prompt,
        temperature=0.0,
        timeout_s=90,
        num_predict=180,
    )
    return normalize_review_payload(payload)


def style_presence(sentences: list[str]) -> dict[str, bool]:
    has_question = any(diversity_signature(sentence)["has_question"] for sentence in sentences)
    has_dialogue = any(diversity_signature(sentence)["has_quote"] for sentence in sentences)
    has_complex = any(diversity_signature(sentence)["has_complex_clause"] for sentence in sentences)
    return {
        "question": has_question,
        "dialogue": has_dialogue,
        "complex": has_complex,
    }


def sentence_matches_style(text: str, style: str) -> bool:
    signature = diversity_signature(text)
    if style == "question":
        return bool(signature["has_question"])
    if style == "dialogue":
        return bool(signature["has_quote"])
    if style == "complex":
        return bool(signature["has_complex_clause"])
    return True


def repair_style_mismatch(text: str, style: str) -> str:
    candidate = normalize_text(text)
    if not candidate:
        return ""

    if style == "dialogue" and '"' not in candidate:
        payload = candidate.rstrip(" .!?")
        return f'"{payload}," she said during the review.'

    if style == "question" and "?" not in candidate:
        payload = candidate.rstrip(" .!?")
        if payload:
            return f"{payload}?"

    if style == "complex":
        signature = diversity_signature(candidate)
        if not signature["has_complex_clause"]:
            lowered = candidate[0].lower() + candidate[1:] if len(candidate) > 1 else candidate.lower()
            return f"Although pressure rose overnight, {lowered}"

    return ""


def stable_pick(options: list[str], key: str) -> str:
    digest = hashlib.sha1(key.encode("utf-8")).digest()
    value = int.from_bytes(digest[:4], byteorder="big", signed=False)
    return options[value % len(options)]


def fallback_sentence(lemma: str, style: str, key: str, pos: str, definition: str = "") -> str:
    pos_tag = normalize_pos_tag(pos)
    lemma_lower = lemma.lower()
    definition_lower = normalize_text(definition).lower()

    # Definition-informed POS correction for noisy source tags.
    if definition_lower.startswith(("a ", "an ", "the ", "one of", "someone", "something")):
        if pos_tag in {"verb", "other", "modal"}:
            pos_tag = "noun"
    elif definition_lower.startswith("to "):
        pos_tag = "verb"
    elif definition_lower.startswith(("of or", "relating to", "having to do with")):
        if pos_tag == "other":
            pos_tag = "adjective"

    if pos_tag == "verb" and lemma_lower in MODAL_LEMMAS:
        pos_tag = "modal"
    if pos_tag == "verb" and lemma_lower in AUXILIARY_LEMMAS:
        pos_tag = "other"
    pos_templates: dict[str, dict[str, list[str]]] = {
        "noun": {
            "question": [
                "When deadlines collide at work, what {lemma} keeps your team focused and moving together?",
                "If the rollout derails overnight, what {lemma} helps everyone recover without blame?",
                "When two managers disagree in public, what {lemma} keeps the project from stalling?",
            ],
            "dialogue": [
                '"Without {lemma}," the producer said, "this project would have stalled before the first review."',
                '"Better {lemma} starts now," she said, "or this client will walk by Friday."',
                '"That {lemma} saved us," he said, "when the vendor changed terms at midnight."',
            ],
            "complex": [
                "Although the budget looked stable, weak {lemma} turned a routine launch into a costly delay.",
                "Because the handoff notes were incomplete, better {lemma} became urgent before the next shift.",
                "While the team had enough talent, poor {lemma} kept small issues from being resolved quickly.",
            ],
            "contextual": [
                "After the audit escalated, stronger {lemma} helped the team rebuild trust with anxious clients.",
                "During a tense handoff, clear {lemma} prevented one small mistake from becoming a public failure.",
                "In a late-night planning call, steady {lemma} kept the launch from slipping again.",
            ],
        },
        "adjective": {
            "question": [
                "When the board split into camps overnight, how did they stay {lemma} through the final vote?",
                "After the merger rumors spread, why did the team remain {lemma} during that tense meeting?",
                "When negotiations stalled at midnight, how could the delegates still appear {lemma} to reporters?",
            ],
            "dialogue": [
                '"We must stay {lemma}," the captain said, "or this fragile coalition will collapse by dawn."',
                '"Keep everyone {lemma}," she said, "because investors are reading every signal today."',
                '"If we look {lemma}," he whispered, "the staff will trust this transition plan."',
            ],
            "complex": [
                "Although rumors spread all morning, the staff remained {lemma} until leadership explained the plan.",
                "Because the panel stayed {lemma}, the audience accepted a difficult compromise by evening.",
                "While online reactions were harsh, the delegates sounded {lemma} during the final briefing.",
            ],
            "contextual": [
                "After two heated meetings, the normally divided committee sounded surprisingly {lemma} on budget priorities.",
                "During the crisis update, a {lemma} response helped calm parents waiting outside the school.",
                "In the newsroom, their {lemma} message prevented a minor error from becoming a public panic.",
            ],
        },
        "verb": {
            "question": [
                "When priorities drifted after lunch, how did the team {lemma} before the launch window closed?",
                "After legal flagged the draft, who decided to {lemma} before sending it to partners?",
                "When support tickets spiked overnight, why did they {lemma} before announcing any timeline?",
            ],
            "dialogue": [
                '"We should {lemma} now," he said, "before reviewers reopen every unresolved comment."',
                '"Can you {lemma} this today," she asked, "so finance can close the quarter cleanly?"',
                '"Let us {lemma} first," the director said, "then we can face the press together."',
            ],
            "complex": [
                "Although the schedule was tight, they chose to {lemma} before sending the contract.",
                "Because the vendor changed terms again, we had to {lemma} before publishing updates.",
                "While the room grew louder, she managed to {lemma} and keep the discussion productive.",
            ],
            "contextual": [
                "After the warning alert, she had to {lemma} quickly to avoid another outage.",
                "During a tense handoff, they paused to {lemma} before escalating the incident report.",
                "In the postmortem call, he promised to {lemma} so the same bug would not return.",
            ],
        },
        "modal": {
            "question": [
                "If the forecast shifts after midnight, what {lemma} happen before the morning commute begins?",
                "When the legal memo changes again, how {lemma} that affect tomorrow's launch decision?",
                "If investors panic at opening bell, what {lemma} leadership announce before noon?",
            ],
            "dialogue": [
                '"Traffic {lemma} ease later," she said, "if the storm moves east before sunset."',
                '"Costs {lemma} rise next quarter," he said, "unless we renegotiate the vendor contract."',
                '"The issue {lemma} return," they said, "so keep the rollback plan ready tonight."',
            ],
            "complex": [
                "Although demand looked stable, analysts warned prices {lemma} swing after the announcement.",
                "Because key data was delayed, the board said approval {lemma} wait until Friday.",
                "While the servers recovered quickly, support noted tickets {lemma} spike again overnight.",
            ],
            "contextual": [
                "During the briefing, legal explained that penalties {lemma} apply if deadlines slip again.",
                "In the night shift handoff, supervisors agreed repairs {lemma} continue through dawn.",
                "After the outage, leaders admitted similar failures {lemma} happen without stricter reviews.",
            ],
        },
        "adverb": {
            "question": [
                "When the press conference turned hostile, why did the spokesperson respond so {lemma}?",
                "After that tense hearing, how did she argue so {lemma} without sounding defensive?",
                "When the audit questions became aggressive, why did he answer so {lemma} on camera?",
            ],
            "dialogue": [
                '"Answer {lemma}," the editor said, "because readers will compare every claim tomorrow."',
                '"Speak {lemma}," she said, "or this misunderstanding will keep expanding online."',
                '"Write {lemma}," he warned, "so compliance can approve the memo before noon."',
            ],
            "complex": [
                "Although critics were loud online, she spoke {lemma} and corrected each detail.",
                "Because the committee listened closely, he responded {lemma} and avoided another argument.",
                "While tension rose in the room, the mediator replied {lemma} and reset expectations.",
            ],
            "contextual": [
                "During the hearing, he argued {lemma}, which shifted the panel's attention to evidence.",
                "At the town hall, she answered {lemma} and turned a rumor into a productive question.",
                "In the follow-up memo, they explained the delay {lemma} and regained stakeholder trust.",
            ],
        },
        "other": {
            "question": [
                "When the project derailed overnight, how did {lemma} become central to the recovery plan?",
                "After that tense review, why did everyone mention {lemma} in the follow-up notes?",
                "When the team lost momentum, how did {lemma} shape the next week's decisions?",
            ],
            "dialogue": [
                '"We need {lemma} right now," she said, "or this rollout will fail again."',
                '"Without {lemma}," he said, "we cannot explain this decision to the board."',
                '"Keep {lemma} visible," the manager said, "so nobody forgets the actual goal."',
            ],
            "complex": [
                "Although the timeline was stable, {lemma} became the deciding factor in that outcome.",
                "Because stakeholders disagreed early, {lemma} shaped the final compromise by Friday.",
                "While pressure increased all week, {lemma} still guided the team's final call.",
            ],
            "contextual": [
                "After the audit meeting, {lemma} emerged as the one issue nobody could ignore.",
                "During a difficult launch, {lemma} quietly influenced every major decision on the call.",
                "In a tense debrief, {lemma} helped explain why the plan succeeded late.",
            ],
        },
    }
    style_templates = pos_templates.get(pos_tag, pos_templates["other"])
    choices = style_templates.get(style, style_templates["contextual"])
    return stable_pick(choices, key).format(lemma=lemma)


def build_generation_prompt(
    *,
    lemma: str,
    definition: str,
    pos: str,
    cefr: str,
    style: str,
    used_sentences: list[str],
) -> str:
    pos_tag = normalize_pos_tag(pos)
    lemma_anchor_map = {
        "noun": f'"one {lemma}" or "the {lemma}"',
        "adjective": f'"stay {lemma}" or "be {lemma}"',
        "verb": f'"to {lemma}"',
        "adverb": f'"so {lemma}"',
        "other": f'"{lemma}"',
    }
    lemma_anchor = lemma_anchor_map.get(pos_tag, lemma_anchor_map["other"])
    style_instruction_map = {
        "question": "Write a question sentence ending with '?'.",
        "dialogue": "Write a dialogue sentence with quoted speech using double quotes.",
        "complex": "Write a complex sentence with a subordinate clause.",
        "contextual": "Write a contextual scenario sentence.",
    }
    style_hard_rule_map = {
        "question": "Must end with '?' and contain exactly one question mark.",
        "dialogue": 'Must include quoted speech with at least two double quote characters (").',
        "complex": f"Must include one clause marker token from: {COMPLEX_CLAUSE_HINT}.",
        "contextual": "Must describe a concrete mini-scenario.",
    }
    style_instruction = style_instruction_map.get(style, style_instruction_map["contextual"])
    style_hard_rule = style_hard_rule_map.get(style, style_hard_rule_map["contextual"])

    avoid_block = "\n".join(f"- {text}" for text in used_sentences if text)

    return f"""
Write exactly one natural English sentence for vocabulary learning.
Lemma: {lemma}
Definition: {definition}
Part of speech: {pos}
CEFR: {cefr}

Constraints:
- Must contain lemma exactly as written at least once: "{lemma}".
- Do not inflect, paraphrase, or replace the lemma token.
- Include this anchor phrase naturally: {lemma_anchor}.
- 8-25 words.
- Contextual/incidental learning style, not dictionary-style.
- Avoid trivial "He/She + verb + object" templates.
- Keep grammar aligned with the part of speech: {pos}.
- Avoid copying or closely paraphrasing these existing sentences:
{avoid_block}
- {style_instruction}
- Style hard rule: {style_hard_rule}

Return ONLY JSON: {{"sentence": "..."}}
""".strip()


def generate_sentence_with_llm(
    *,
    ollama_url: str,
    model: str,
    lemma: str,
    definition: str,
    pos: str,
    cefr: str,
    style: str,
    used_sentences: list[str],
) -> str:
    prompt = build_generation_prompt(
        lemma=lemma,
        definition=definition,
        pos=pos,
        cefr=cefr,
        style=style,
        used_sentences=used_sentences,
    )
    payload = ollama_generate_json(
        ollama_url=ollama_url,
        model=model,
        prompt=prompt,
        temperature=0.2,
        timeout_s=60,
        num_predict=120,
    )
    sentence = normalize_text(payload.get("sentence", ""))
    if not sentence:
        raise ValueError("Empty generated sentence")
    return sentence


def build_batch_generation_prompt(
    *,
    lemma: str,
    definition: str,
    pos: str,
    cefr: str,
    style_targets: dict[int, str],
    used_sentences: list[str],
) -> str:
    style_label = {
        "question": "question ending with '?'",
        "dialogue": 'dialogue with double quotes',
        "complex": f"complex clause sentence using one of {COMPLEX_CLAUSE_HINT}",
        "contextual": "contextual scenario sentence",
    }
    targets = ", ".join(
        f"{idx}:{style_label.get(style, style_label['contextual'])}"
        for idx, style in sorted(style_targets.items())
    )
    avoid_block = "\n".join(f"- {text}" for text in used_sentences if text)

    return f"""
Write rewritten English vocabulary sentences.
Lemma: {lemma}
Definition: {definition}
POS: {pos}
CEFR: {cefr}

Targets by index:
{targets}

Global constraints:
- Exact lemma token "{lemma}" must appear in each sentence.
- 8-25 words each.
- Natural contextual style; no dictionary-style wording.
- Avoid close copies of:
{avoid_block}

Return STRICT JSON only:
{{
  "sentences": [
    {{"index": 0, "sentence": "..."}},
    {{"index": 1, "sentence": "..."}},
    {{"index": 2, "sentence": "..."}}
  ]
}}
Include only requested target indices.
""".strip()


def generate_batch_sentences_with_llm(
    *,
    ollama_url: str,
    model: str,
    lemma: str,
    definition: str,
    pos: str,
    cefr: str,
    style_targets: dict[int, str],
    used_sentences: list[str],
) -> dict[int, str]:
    if not style_targets:
        return {}

    prompt = build_batch_generation_prompt(
        lemma=lemma,
        definition=definition,
        pos=pos,
        cefr=cefr,
        style_targets=style_targets,
        used_sentences=used_sentences,
    )
    payload = ollama_generate_json(
        ollama_url=ollama_url,
        model=model,
        prompt=prompt,
        temperature=0.2,
        timeout_s=75,
        num_predict=260,
    )

    rows = payload.get("sentences", [])
    if not isinstance(rows, list):
        return {}

    output: dict[int, str] = {}
    for row in rows:
        if not isinstance(row, dict):
            continue
        idx = row.get("index")
        if not isinstance(idx, int) or idx not in style_targets:
            continue
        sentence = normalize_text(row.get("sentence", ""))
        if sentence:
            output[idx] = sentence
    return output


def compute_style_targets(
    *,
    texts: list[str],
    rewrite_indices: set[int],
    sentence_scores: dict[int, float],
    review: dict[int, dict[str, Any]] | None = None,
) -> tuple[set[int], dict[int, str]]:
    changed = bool(rewrite_indices)
    if not changed:
        return rewrite_indices, {}

    keep_indices = [idx for idx in range(3) if idx not in rewrite_indices]
    keep_presence = style_presence([texts[idx] for idx in keep_indices])
    missing = [style for style in STYLE_ORDER if not keep_presence[style]]

    if len(rewrite_indices) < len(missing):
        candidates = sorted(keep_indices, key=lambda idx: (sentence_scores.get(idx, 0.0), idx))
        for idx in candidates:
            rewrite_indices.add(idx)
            if len(rewrite_indices) >= len(missing):
                break

    keep_indices = [idx for idx in range(3) if idx not in rewrite_indices]
    keep_presence = style_presence([texts[idx] for idx in keep_indices])
    missing = [style for style in STYLE_ORDER if not keep_presence[style]]

    ordered_rewrites = sorted(rewrite_indices, key=lambda idx: (sentence_scores.get(idx, 0.0), idx))
    unused_rewrites = list(ordered_rewrites)
    style_targets: dict[int, str] = {}

    # Prefer review-proposed rewrites that already match required styles to avoid extra generations.
    for style in missing:
        if review is None:
            continue
        match_idx = None
        for idx in unused_rewrites:
            candidate = normalize_text(review.get(idx, {}).get("rewrite", ""))
            if candidate and sentence_matches_style(candidate, style):
                match_idx = idx
                break
        if match_idx is not None:
            style_targets[match_idx] = style
            unused_rewrites.remove(match_idx)

    for style in missing:
        if style in style_targets.values():
            continue
        if not unused_rewrites:
            break
        pick = unused_rewrites.pop(0)
        style_targets[pick] = style

    while unused_rewrites:
        pick = unused_rewrites.pop(0)
        style_targets[pick] = "contextual"

    return rewrite_indices, style_targets


def choose_rewrite_indices(
    *,
    texts: list[str],
    local_reasons: dict[int, list[str]],
    review: dict[int, dict[str, Any]],
) -> tuple[set[int], dict[int, float], list[str]]:
    rewrite_indices: set[int] = set()
    sentence_scores: dict[int, float] = {}

    for idx in range(3):
        analysis = review.get(idx, {})
        score = float(analysis.get("score", 0.0))
        sentence_scores[idx] = score

        severity = str(analysis.get("severity", "none")).lower()
        action = str(analysis.get("action", "KEEP")).upper()

        must_rewrite = bool(local_reasons[idx])
        must_rewrite = must_rewrite or severity in {"fatal", "major"}
        must_rewrite = must_rewrite or score < 75.0
        must_rewrite = must_rewrite or action == "REWRITE"

        if must_rewrite:
            rewrite_indices.add(idx)

    set_ok, set_reasons = validate_set(texts)
    if not set_ok and not rewrite_indices:
        extra_idx = min(range(3), key=lambda idx: (sentence_scores.get(idx, 0.0), idx))
        rewrite_indices.add(extra_idx)

    rewrite_indices, _ = compute_style_targets(
        texts=texts,
        rewrite_indices=rewrite_indices,
        sentence_scores=sentence_scores,
        review=review,
    )
    return rewrite_indices, sentence_scores, set_reasons


def enforce_sentence_generation(
    *,
    idx: int,
    lemma: str,
    definition: str,
    pos: str,
    cefr: str,
    style: str,
    review_rewrite: str,
    current_texts: list[str],
    model: str,
    ollama_url: str,
    deterministic: bool = False,
) -> tuple[str, list[str]]:
    errors: list[str] = []

    if deterministic:
        candidate = fallback_sentence(
            lemma,
            style,
            key=f"deterministic:{lemma}:{idx}:{style}:{definition}:{pos}",
            pos=pos,
            definition=definition,
        )
        ok, reasons = validate_sentence(candidate, lemma)
        if ok and sentence_matches_style(candidate, style):
            errors.append(f"deterministic_rewrite_used:{style}")
            return candidate, errors
        # Deterministic hard guard sentence if style template fails.
        if style == "question":
            hard = f"When pressure rises at midnight, what {lemma} keeps the project moving?"
        elif style == "dialogue":
            hard = f'"Without {lemma}," she said, "this rollout would have failed by morning."'
        elif style == "complex":
            hard = f"Although the timeline looked stable, {lemma} still shaped the final decision."
        else:
            hard = f"During the urgent handoff, {lemma} became the key factor in every decision."
        hard_ok, hard_reasons = validate_sentence(hard, lemma)
        if hard_ok and sentence_matches_style(hard, style):
            errors.append(f"deterministic_rewrite_guard:{style}")
            return hard, errors
        raise RuntimeError(f"Deterministic rewrite invalid for lemma={lemma}: {reasons or hard_reasons}")

    candidate = normalize_text(review_rewrite)
    if candidate:
        ok, reasons = validate_sentence(candidate, lemma)
        if ok and sentence_matches_style(candidate, style):
            return candidate, errors
        errors.append(f"review_candidate_invalid:{','.join(reasons) or 'style'}")

    for attempt in range(1, MAX_GENERATION_RETRIES + 1):
        try:
            generated = generate_sentence_with_llm(
                ollama_url=ollama_url,
                model=model,
                lemma=lemma,
                definition=definition,
                pos=pos,
                cefr=cefr,
                style=style,
                used_sentences=current_texts,
            )
        except Exception as exc:
            errors.append(f"llm_generation_attempt_{attempt}_error:{exc}")
            continue

        ok, reasons = validate_sentence(generated, lemma)
        if not ok:
            errors.append(f"llm_generation_attempt_{attempt}_invalid:{','.join(reasons)}")
            continue

        if not sentence_matches_style(generated, style):
            repaired = repair_style_mismatch(generated, style)
            if repaired:
                repaired_ok, repaired_reasons = validate_sentence(repaired, lemma)
                if repaired_ok and sentence_matches_style(repaired, style):
                    errors.append(f"llm_generation_attempt_{attempt}_style_repaired:{style}")
                    return repaired, errors
                errors.append(
                    "llm_generation_attempt_"
                    f"{attempt}_style_repair_invalid:{','.join(repaired_reasons) or style}"
                )
            errors.append(f"llm_generation_attempt_{attempt}_style_mismatch:{style}")
            continue

        return generated, errors

    fallback = fallback_sentence(
        lemma,
        style,
        key=f"{lemma}:{idx}:{style}:{definition}",
        pos=pos,
        definition=definition,
    )
    ok, reasons = validate_sentence(fallback, lemma)
    if not ok:
        # Final hard guard: stable safe question sentence.
        fallback = f"When a crisis hits after midnight, what {lemma} keeps the team aligned and calm?"
        ok, reasons = validate_sentence(fallback, lemma)
    if not ok:
        raise RuntimeError(f"Fallback sentence invalid for lemma={lemma}: {reasons}")

    errors.append(f"fallback_used:{style}")
    return fallback, errors


def ensure_set_constraints(
    *,
    texts: list[str],
    lemma: str,
    definition: str,
    pos: str,
    cefr: str,
    review: dict[int, dict[str, Any]],
    review_scores: dict[int, float],
    rewritten_records: dict[int, dict[str, Any]],
    rewrite_indices: set[int],
    model: str,
    ollama_url: str,
    error_log: list[str],
    deterministic: bool = False,
) -> tuple[list[str], set[int], dict[int, dict[str, Any]]]:
    # Guarantee full mix on changed sets and set-level diversity constraints.
    max_rounds = 8
    rounds = 0

    while rounds < max_rounds:
        changed_set = bool(rewrite_indices)
        set_ok, set_reasons = validate_set(texts)
        mix = style_presence(texts)
        mix_ok = True if not changed_set else all(mix.values())

        if set_ok and mix_ok:
            return texts, rewrite_indices, rewritten_records

        if changed_set and not all(mix.values()):
            missing_styles = [style for style in STYLE_ORDER if not mix[style]]
            target_style = missing_styles[0]
        elif "set_all_same_punctuation_pattern" in set_reasons:
            target_style = "question" if not mix["question"] else "dialogue"
        elif "set_all_same_start_token" in set_reasons:
            target_style = "dialogue" if not mix["dialogue"] else "complex"
        else:
            target_style = "contextual"

        candidate_order = sorted(
            range(3),
            key=lambda idx: (
                0 if idx in rewrite_indices else 1,
                review_scores.get(idx, 0.0),
                idx,
            ),
        )
        target_idx = candidate_order[0]
        review_rewrite = ""
        if target_idx in review:
            review_rewrite = str(review[target_idx].get("rewrite", ""))

        new_text, generation_errors = enforce_sentence_generation(
            idx=target_idx,
            lemma=lemma,
            definition=definition,
            pos=pos,
            cefr=cefr,
            style=target_style,
            review_rewrite=review_rewrite,
            current_texts=texts,
            model=model,
            ollama_url=ollama_url,
            deterministic=deterministic,
        )
        error_log.extend(generation_errors)

        old_text = texts[target_idx]
        texts[target_idx] = new_text
        rewrite_indices.add(target_idx)

        existing = rewritten_records.get(target_idx)
        if existing is None:
            rewritten_records[target_idx] = {
                "index": target_idx,
                "before": old_text,
                "after": new_text,
                "reasons": ["set_diversity_adjustment", f"style:{target_style}"],
            }
        else:
            existing["after"] = new_text
            if f"style:{target_style}" not in existing["reasons"]:
                existing["reasons"].append(f"style:{target_style}")

        rounds += 1

    # Hard guarantee path: rewrite to deterministic trio if constraints still fail.
    forced_styles = {0: "complex", 1: "question", 2: "dialogue"}
    for idx, style in forced_styles.items():
        old_text = texts[idx]
        forced = fallback_sentence(
            lemma,
            style,
            key=f"force:{lemma}:{idx}",
            pos=pos,
            definition=definition,
        )
        texts[idx] = forced
        rewrite_indices.add(idx)
        existing = rewritten_records.get(idx)
        if existing is None:
            rewritten_records[idx] = {
                "index": idx,
                "before": old_text,
                "after": forced,
                "reasons": ["forced_full_mix_fallback", f"style:{style}"],
            }
        else:
            existing["after"] = forced
            if "forced_full_mix_fallback" not in existing["reasons"]:
                existing["reasons"].append("forced_full_mix_fallback")
            if f"style:{style}" not in existing["reasons"]:
                existing["reasons"].append(f"style:{style}")

    return texts, rewrite_indices, rewritten_records


def process_item(
    *,
    row: dict[str, Any],
    model: str,
    ollama_url: str,
    mode: str = "strict_llm",
) -> tuple[dict[str, Any], dict[str, Any]]:
    lemma = normalize_text(row.get("lemma", ""))
    definition = normalize_text(row.get("definition", ""))
    pos = normalize_text(row.get("pos", ""))
    cefr = normalize_text(row.get("cefr", ""))

    if not lemma:
        raise ValueError(f"Missing lemma for id={row.get('id')}")

    original_texts = normalize_sentence_texts(row.get("sentences", []))

    if "sentences_old" not in row:
        row["sentences_old"] = copy.deepcopy(row.get("sentences", []))

    texts = list(original_texts)

    local_reasons: dict[int, list[str]] = {}
    for idx, text in enumerate(texts):
        ok, reasons = validate_sentence(text, lemma)
        local_reasons[idx] = [] if ok else list(reasons)

    error_log: list[str] = []
    if mode == "turbo_deterministic":
        review = deterministic_review_item_once(
            lemma=lemma,
            definition=definition,
            sentences=texts,
        )
    else:
        try:
            review = review_item_once(
                ollama_url=ollama_url,
                model=model,
                lemma=lemma,
                definition=definition,
                pos=pos,
                cefr=cefr,
                sentences=texts,
            )
        except Exception as exc:
            review = {
                idx: {
                    "index": idx,
                    "score": 0.0 if local_reasons[idx] else 80.0,
                    "severity": "fatal" if local_reasons[idx] else "minor",
                    "reasons": ["review_fallback_local"] + local_reasons[idx],
                    "action": "REWRITE" if local_reasons[idx] else "KEEP",
                    "rewrite": "",
                }
                for idx in range(3)
            }
            error_log.append(f"review_error:{exc}")

    rewrite_indices, review_scores, set_reasons = choose_rewrite_indices(
        texts=texts,
        local_reasons=local_reasons,
        review=review,
    )
    if set_reasons:
        error_log.append("set_reasons:" + ",".join(set_reasons))

    rewrite_indices, style_targets = compute_style_targets(
        texts=texts,
        rewrite_indices=set(rewrite_indices),
        sentence_scores=review_scores,
        review=review,
    )

    rewritten_records: dict[int, dict[str, Any]] = {}
    batch_candidates: dict[int, str] = {}
    if mode == "strict_llm" and len(rewrite_indices) >= 2:
        try:
            batch_candidates = generate_batch_sentences_with_llm(
                ollama_url=ollama_url,
                model=model,
                lemma=lemma,
                definition=definition,
                pos=pos,
                cefr=cefr,
                style_targets={idx: style_targets.get(idx, "contextual") for idx in rewrite_indices},
                used_sentences=texts,
            )
        except Exception as exc:
            error_log.append(f"batch_generation_error:{exc}")

    for idx in sorted(rewrite_indices):
        target_style = style_targets.get(idx, "contextual")
        analysis = review.get(idx, {})
        review_rewrite = batch_candidates.get(idx, str(analysis.get("rewrite", "")))

        new_text, generation_errors = enforce_sentence_generation(
            idx=idx,
            lemma=lemma,
            definition=definition,
            pos=pos,
            cefr=cefr,
            style=target_style,
            review_rewrite=review_rewrite,
            current_texts=texts,
            model=model,
            ollama_url=ollama_url,
            deterministic=(mode == "turbo_deterministic"),
        )
        error_log.extend(generation_errors)

        rewritten_records[idx] = {
            "index": idx,
            "before": texts[idx],
            "after": new_text,
            "reasons": list(dict.fromkeys(
                local_reasons[idx]
                + list(analysis.get("reasons", []))
                + [f"style:{target_style}"]
            )),
        }
        texts[idx] = new_text

    texts, rewrite_indices, rewritten_records = ensure_set_constraints(
        texts=texts,
        lemma=lemma,
        definition=definition,
        pos=pos,
        cefr=cefr,
        review=review,
        review_scores=review_scores,
        rewritten_records=rewritten_records,
        rewrite_indices=set(rewrite_indices),
        model=model,
        ollama_url=ollama_url,
        error_log=error_log,
        deterministic=(mode == "turbo_deterministic"),
    )

    final_sentences: list[dict[str, Any]] = []
    validation_errors: list[str] = []
    for idx, text in enumerate(texts):
        ok, reasons = validate_sentence(text, lemma)
        if not ok:
            validation_errors.append(f"final_sentence_{idx}_invalid:{','.join(reasons)}")

        cloze = find_cloze_index(text, lemma)
        if cloze is None:
            validation_errors.append(f"final_sentence_{idx}_cloze_missing")
            cloze = 0

        final_sentences.append({"text": text, "cloze_index": cloze})

    set_ok, set_errors = validate_set(texts)
    if not set_ok:
        validation_errors.extend(f"final_set_invalid:{reason}" for reason in set_errors)

    row["sentences"] = final_sentences

    changed = any(texts[idx] != original_texts[idx] for idx in range(3))
    kept = [texts[idx] for idx in range(3) if texts[idx] == original_texts[idx]]
    rewritten = [rewritten_records[idx] for idx in sorted(rewritten_records.keys())]

    errors_unique = list(dict.fromkeys(error_log + validation_errors))
    checkpoint_record = {
        "id": row.get("id"),
        "lemma": lemma,
        "changed": changed,
        "kept": kept,
        "rewritten": rewritten,
        "errors": errors_unique,
        "metrics": {
            "rewritten_count": len(rewritten),
            "fallback_count": sum(
                1 for token in errors_unique
                if str(token).startswith("fallback_used:")
            ),
            "review_error": any(
                str(token).startswith("review_error:")
                for token in errors_unique
            ),
        },
    }
    return row, checkpoint_record


def verify_rows(
    rows: list[dict[str, Any]],
    ids_subset: set[int] | None = None,
    *,
    require_sentences_old: bool = True,
) -> tuple[bool, list[str]]:
    errors: list[str] = []

    for row in rows:
        row_id = int(row.get("id", -1))
        if ids_subset is not None and row_id not in ids_subset:
            continue

        if require_sentences_old and "sentences_old" not in row:
            errors.append(f"id={row_id}:missing_sentences_old")

        sentences = row.get("sentences", [])
        if not isinstance(sentences, list) or len(sentences) != 3:
            errors.append(f"id={row_id}:sentences_not_exactly_3")
            continue

        lemma = normalize_text(row.get("lemma", ""))
        texts: list[str] = []
        for idx, sentence in enumerate(sentences):
            if not isinstance(sentence, dict):
                errors.append(f"id={row_id}:sentence_{idx}_not_object")
                continue

            text = normalize_text(sentence.get("text", ""))
            texts.append(text)
            ok, reasons = validate_sentence(text, lemma)
            if not ok:
                errors.append(f"id={row_id}:sentence_{idx}_invalid:{','.join(reasons)}")

            cloze = find_cloze_index(text, lemma)
            if cloze is None:
                errors.append(f"id={row_id}:sentence_{idx}_cloze_missing")
            elif sentence.get("cloze_index") != cloze:
                errors.append(
                    f"id={row_id}:sentence_{idx}_cloze_mismatch:expected={cloze}:actual={sentence.get('cloze_index')}"
                )

        set_ok, set_reasons = validate_set(texts)
        if not set_ok:
            errors.append(f"id={row_id}:set_invalid:{','.join(set_reasons)}")

        if len(errors) >= 200:
            break

    return (len(errors) == 0, errors)


def choose_example_pairs(changed_examples: list[dict[str, Any]]) -> list[dict[str, Any]]:
    picked: list[dict[str, Any]] = []
    management = [ex for ex in changed_examples if str(ex.get("lemma", "")).lower() == "management"]
    if management:
        picked.append(management[0])

    for ex in changed_examples:
        if ex in picked:
            continue
        picked.append(ex)
        if len(picked) >= 2:
            break

    return picked[:2]


def record_fallback_count(record: dict[str, Any]) -> int:
    return sum(1 for error in record.get("errors", []) if str(error).startswith("fallback_used:"))


def load_checkpoint_metrics(checkpoint_path: Path) -> tuple[int, int]:
    if not checkpoint_path.exists():
        return 0, 0

    rewritten_total = 0
    fallback_total = 0
    for line in checkpoint_path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        try:
            record = json.loads(stripped)
        except Exception:
            continue

        metrics = record.get("metrics", {})
        if isinstance(metrics, dict) and "rewritten_count" in metrics:
            rewritten_count = int(metrics.get("rewritten_count", 0))
            fallback_count = int(metrics.get("fallback_count", 0))
        else:
            rewritten_count = len(record.get("rewritten", []))
            fallback_count = record_fallback_count(record)

        rewritten_total += max(0, rewritten_count)
        fallback_total += max(0, fallback_count)

    return rewritten_total, fallback_total


def summarize_fallback_issues(records: list[dict[str, Any]]) -> tuple[list[tuple[str, int]], list[tuple[str, int]]]:
    style_counter: Counter[str] = Counter()
    issue_counter: Counter[str] = Counter()

    for record in records:
        for error in record.get("errors", []):
            token = str(error).strip()
            if not token:
                continue
            if token.startswith("fallback_used:"):
                style_counter[token.split(":", 1)[-1]] += 1
                continue
            if token.startswith("llm_generation_attempt_"):
                if ":" in token:
                    issue_counter[token.split(":", 1)[1]] += 1
                else:
                    issue_counter[token] += 1
                continue
            if token.startswith("review_error:"):
                issue_counter["review_error"] += 1

    return style_counter.most_common(5), issue_counter.most_common(8)


def sample_modulus(sample_rate: float) -> int:
    if sample_rate <= 0:
        return 0
    return max(1, int(round(1.0 / sample_rate)))


def is_sampled_id(row_id: int, sample_rate: float) -> bool:
    modulus = sample_modulus(sample_rate)
    if modulus <= 0:
        return False
    return hash(int(row_id)) % modulus == 0


def review_fail_indices(review: dict[int, dict[str, Any]]) -> list[int]:
    failed: list[int] = []
    for idx in range(3):
        cell = review.get(idx, {})
        severity = str(cell.get("severity", "none")).lower()
        action = str(cell.get("action", "KEEP")).upper()
        if severity in {"fatal", "major"} or action == "REWRITE":
            failed.append(idx)
    return failed


def qa_review_sample_item(
    *,
    row: dict[str, Any],
    ollama_url: str,
    qa_model: str,
) -> dict[str, Any]:
    lemma = normalize_text(row.get("lemma", ""))
    definition = normalize_text(row.get("definition", ""))
    pos = normalize_text(row.get("pos", ""))
    cefr = normalize_text(row.get("cefr", ""))
    texts = normalize_sentence_texts(row.get("sentences", []))

    try:
        review = review_item_once(
            ollama_url=ollama_url,
            model=qa_model,
            lemma=lemma,
            definition=definition,
            pos=pos,
            cefr=cefr,
            sentences=texts,
        )
    except Exception:
        return {
            "audit_error": True,
            "fail_indices": [],
            "reasons": [],
        }

    fail_indices = review_fail_indices(review)
    reasons: list[str] = []
    for idx in fail_indices:
        for reason in review.get(idx, {}).get("reasons", []):
            reasons.append(str(reason))

    return {
        "audit_error": False,
        "fail_indices": fail_indices,
        "reasons": reasons,
    }


def apply_deterministic_fix(
    *,
    row: dict[str, Any],
    failing_indices: list[int],
    ollama_url: str,
    model: str,
) -> tuple[dict[str, Any], dict[str, Any]]:
    lemma = normalize_text(row.get("lemma", ""))
    definition = normalize_text(row.get("definition", ""))
    pos = normalize_text(row.get("pos", ""))
    cefr = normalize_text(row.get("cefr", ""))
    texts = normalize_sentence_texts(row.get("sentences", []))
    original_texts = list(texts)

    if "sentences_old" not in row:
        row["sentences_old"] = copy.deepcopy(row.get("sentences", []))

    local_reasons: dict[int, list[str]] = {}
    for idx, text in enumerate(texts):
        ok, reasons = validate_sentence(text, lemma)
        local_reasons[idx] = [] if ok else list(reasons)

    review = deterministic_review_item_once(
        lemma=lemma,
        definition=definition,
        sentences=texts,
    )
    for idx in failing_indices:
        if idx not in {0, 1, 2}:
            continue
        review[idx]["severity"] = "major"
        review[idx]["action"] = "REWRITE"
        review[idx]["score"] = min(float(review[idx].get("score", 60.0)), 60.0)
        reasons = list(review[idx].get("reasons", []))
        if "qa_fix_required" not in reasons:
            reasons.append("qa_fix_required")
        review[idx]["reasons"] = reasons

    rewrite_indices, review_scores, set_reasons = choose_rewrite_indices(
        texts=texts,
        local_reasons=local_reasons,
        review=review,
    )
    rewrite_indices.update(idx for idx in failing_indices if idx in {0, 1, 2})
    rewrite_indices, style_targets = compute_style_targets(
        texts=texts,
        rewrite_indices=set(rewrite_indices),
        sentence_scores=review_scores,
        review=review,
    )

    rewritten_records: dict[int, dict[str, Any]] = {}
    error_log: list[str] = []
    if set_reasons:
        error_log.append("set_reasons:" + ",".join(set_reasons))

    for idx in sorted(rewrite_indices):
        target_style = style_targets.get(idx, "contextual")
        new_text, generation_errors = enforce_sentence_generation(
            idx=idx,
            lemma=lemma,
            definition=definition,
            pos=pos,
            cefr=cefr,
            style=target_style,
            review_rewrite="",
            current_texts=texts,
            model=model,
            ollama_url=ollama_url,
            deterministic=True,
        )
        error_log.extend(generation_errors)
        rewritten_records[idx] = {
            "index": idx,
            "before": texts[idx],
            "after": new_text,
            "reasons": list(dict.fromkeys(
                local_reasons[idx]
                + list(review[idx].get("reasons", []))
                + ["qa_fix_applied", f"style:{target_style}"]
            )),
        }
        texts[idx] = new_text

    texts, rewrite_indices, rewritten_records = ensure_set_constraints(
        texts=texts,
        lemma=lemma,
        definition=definition,
        pos=pos,
        cefr=cefr,
        review=review,
        review_scores=review_scores,
        rewritten_records=rewritten_records,
        rewrite_indices=set(rewrite_indices),
        model=model,
        ollama_url=ollama_url,
        error_log=error_log,
        deterministic=True,
    )

    final_sentences: list[dict[str, Any]] = []
    validation_errors: list[str] = []
    for idx, text in enumerate(texts):
        ok, reasons = validate_sentence(text, lemma)
        if not ok:
            validation_errors.append(f"qa_final_sentence_{idx}_invalid:{','.join(reasons)}")
        cloze = find_cloze_index(text, lemma)
        if cloze is None:
            validation_errors.append(f"qa_final_sentence_{idx}_cloze_missing")
            cloze = 0
        final_sentences.append({"text": text, "cloze_index": cloze})

    set_ok, set_errors = validate_set(texts)
    if not set_ok:
        validation_errors.extend(f"qa_final_set_invalid:{reason}" for reason in set_errors)

    row["sentences"] = final_sentences
    changed = any(texts[idx] != original_texts[idx] for idx in range(3))
    rewritten = [rewritten_records[idx] for idx in sorted(rewritten_records)]
    kept = [texts[idx] for idx in range(3) if texts[idx] == original_texts[idx]]

    errors_unique = list(dict.fromkeys(error_log + validation_errors + ["qa_fix_applied"]))
    checkpoint_record = {
        "id": row.get("id"),
        "lemma": lemma,
        "changed": changed,
        "kept": kept,
        "rewritten": rewritten,
        "errors": errors_unique,
        "metrics": {
            "rewritten_count": len(rewritten),
            "fallback_count": sum(
                1 for token in errors_unique if str(token).startswith("fallback_used:")
            ),
            "review_error": False,
            "qa_fix_applied": True,
        },
    }
    return row, checkpoint_record


def run_spot_audit(
    *,
    rows: list[dict[str, Any]],
    ids_scope: list[int],
    id_to_index: dict[int, int],
    ollama_url: str,
    qa_model: str,
    sample_rate: float,
    qa_fail_threshold: float,
    checkpoint_path: Path,
    workers: int = 1,
) -> tuple[bool, dict[str, Any]]:
    sampled_ids = [row_id for row_id in ids_scope if is_sampled_id(row_id, sample_rate)]
    if not sampled_ids:
        return True, {
            "sampled": 0,
            "failures": 0,
            "unresolved": 0,
            "fixed": 0,
            "audit_errors": 0,
            "failure_ratio": 0.0,
            "reasons": [],
        }

    failures = 0
    unresolved = 0
    fixed = 0
    audit_errors = 0
    reason_counter: Counter[str] = Counter()

    sampled_results: dict[int, dict[str, Any]] = {}
    qa_workers = max(1, int(workers or 1))
    if qa_workers == 1:
        for row_id in sampled_ids:
            sampled_results[row_id] = qa_review_sample_item(
                row=rows[id_to_index[row_id]],
                ollama_url=ollama_url,
                qa_model=qa_model,
            )
    else:
        with ThreadPoolExecutor(max_workers=min(qa_workers, len(sampled_ids))) as executor:
            futures = {
                executor.submit(
                    qa_review_sample_item,
                    row=copy.deepcopy(rows[id_to_index[row_id]]),
                    ollama_url=ollama_url,
                    qa_model=qa_model,
                ): row_id
                for row_id in sampled_ids
            }
            for future in as_completed(futures):
                row_id = futures[future]
                try:
                    sampled_results[row_id] = future.result()
                except Exception:
                    sampled_results[row_id] = {
                        "audit_error": True,
                        "fail_indices": [],
                        "reasons": [],
                    }

    for row_id in sampled_ids:
        review_result = sampled_results.get(row_id, {})
        if review_result.get("audit_error"):
            audit_errors += 1
            unresolved += 1
            reason_counter["qa_review_error"] += 1
            continue

        fail_indices = [idx for idx in review_result.get("fail_indices", []) if idx in {0, 1, 2}]
        if not fail_indices:
            continue

        failures += 1
        for reason in review_result.get("reasons", []):
            reason_counter[str(reason)] += 1

        fixed_row, checkpoint_record = apply_deterministic_fix(
            row=copy.deepcopy(rows[id_to_index[row_id]]),
            failing_indices=fail_indices,
            ollama_url=ollama_url,
            model=qa_model,
        )
        rows[id_to_index[row_id]] = fixed_row
        append_checkpoint(checkpoint_path, checkpoint_record)
        fixed += 1
        if any(str(token).startswith("qa_final_") for token in checkpoint_record.get("errors", [])):
            unresolved += 1

    failure_ratio = unresolved / len(sampled_ids)
    stats = {
        "sampled": len(sampled_ids),
        "failures": failures,
        "unresolved": unresolved,
        "fixed": fixed,
        "audit_errors": audit_errors,
        "failure_ratio": failure_ratio,
        "reasons": reason_counter.most_common(8),
    }
    ok = failure_ratio <= qa_fail_threshold
    return ok, stats


def parse_failed_ids(verify_errors: list[str]) -> list[int]:
    ids: set[int] = set()
    for entry in verify_errors:
        match = re.match(r"^id=(\d+):", str(entry))
        if match:
            ids.add(int(match.group(1)))
    return sorted(ids)


def main() -> int:
    args = parse_args()

    if not args.input.exists():
        print(f"Input file not found: {args.input}", file=sys.stderr)
        return 1

    output_path = args.output or args.input.with_name("seed_data_updated.json")
    checkpoint_path = args.checkpoint or args.input.with_name("checkpoint.jsonl")
    partial_path = partial_output_path(output_path)

    processed_ids = read_processed_ids(checkpoint_path)

    if checkpoint_path.exists() and processed_ids:
        if partial_path.exists():
            rows = load_json_array(partial_path)
        elif output_path.exists():
            rows = load_json_array(output_path)
        else:
            print(
                "Checkpoint exists but no resumable dataset snapshot was found "
                f"({partial_path.name} or {output_path.name}).",
                file=sys.stderr,
            )
            return 1
    else:
        rows = load_json_array(args.input)

    id_to_index: dict[int, int] = {}
    for idx, row in enumerate(rows):
        row_id = row.get("id")
        if isinstance(row_id, int):
            id_to_index[row_id] = idx

    pending_ids = [row_id for row_id in id_to_index if row_id not in processed_ids]
    pending_ids.sort(key=lambda rid: id_to_index[rid])
    if args.limit is not None:
        pending_ids = pending_ids[: args.limit]
    run_start = time.perf_counter()
    total_items_count = len(id_to_index)

    run_processed = 0
    run_changed = 0
    chunk_counter = 0
    changed_examples: list[dict[str, Any]] = []
    processed_this_run_ids: set[int] = set()
    run_records: list[dict[str, Any]] = []
    prior_rewritten_total, prior_fallback_total = load_checkpoint_metrics(checkpoint_path)
    total_rewritten_total = prior_rewritten_total
    total_fallback_total = prior_fallback_total
    workers = max(1, int(args.workers or 1))

    def process_completed_item(
        *,
        row_id: int,
        updated_row: dict[str, Any],
        checkpoint_record: dict[str, Any],
    ) -> int | None:
        nonlocal run_processed
        nonlocal run_changed
        nonlocal chunk_counter
        nonlocal total_rewritten_total
        nonlocal total_fallback_total

        rows[id_to_index[row_id]] = updated_row
        append_checkpoint(checkpoint_path, checkpoint_record)

        run_processed += 1
        processed_ids.add(row_id)
        processed_this_run_ids.add(row_id)
        chunk_counter += 1
        run_records.append(checkpoint_record)

        metrics = checkpoint_record.get("metrics", {})
        if isinstance(metrics, dict):
            rewritten_count = int(metrics.get("rewritten_count", len(checkpoint_record.get("rewritten", []))))
            fallback_count = int(metrics.get("fallback_count", record_fallback_count(checkpoint_record)))
        else:
            rewritten_count = len(checkpoint_record.get("rewritten", []))
            fallback_count = record_fallback_count(checkpoint_record)

        total_rewritten_total += max(0, rewritten_count)
        total_fallback_total += max(0, fallback_count)

        if total_rewritten_total > 0:
            fallback_pct = (total_fallback_total / total_rewritten_total) * 100.0
            if fallback_pct > args.fallback_stop_pct:
                write_json_array(partial_path, rows)
                style_top, issue_top = summarize_fallback_issues(run_records)
                print("\nFallback threshold exceeded; stopping for diagnosis.", file=sys.stderr)
                print(
                    f"fallback rate: {total_fallback_total}/{total_rewritten_total} "
                    f"({fallback_pct:.2f}%) > stop threshold {args.fallback_stop_pct:.2f}%",
                    file=sys.stderr,
                )
                if style_top:
                    print("fallback style distribution:", file=sys.stderr)
                    for style, count in style_top:
                        print(f"- {style}: {count}", file=sys.stderr)
                if issue_top:
                    print("top generation/review issues:", file=sys.stderr)
                    for issue, count in issue_top:
                        print(f"- {issue}: {count}", file=sys.stderr)
                return 3

        if checkpoint_record["changed"]:
            run_changed += 1
            changed_examples.append(
                {
                    "id": updated_row.get("id"),
                    "lemma": updated_row.get("lemma"),
                    "definition": updated_row.get("definition"),
                    "before": normalize_sentence_texts(updated_row.get("sentences_old", [])),
                    "after": [entry.get("text", "") for entry in updated_row.get("sentences", [])],
                    "rewritten": checkpoint_record.get("rewritten", []),
                }
            )

        if chunk_counter >= args.chunk_size:
            write_json_array(partial_path, rows)
            print(
                f"Chunk checkpoint written: processed={run_processed} changed={run_changed} file={partial_path}",
                flush=True,
            )
            chunk_counter = 0

        return None

    if workers == 1:
        for row_id in pending_ids:
            row = rows[id_to_index[row_id]]
            updated_row, checkpoint_record = process_item(
                row=row,
                model=args.model,
                ollama_url=args.ollama_url,
                mode=args.mode,
            )
            stop_code = process_completed_item(
                row_id=row_id,
                updated_row=updated_row,
                checkpoint_record=checkpoint_record,
            )
            if stop_code is not None:
                return stop_code
    else:
        print(f"Using parallel workers: {workers}")
        cursor = 0
        with ThreadPoolExecutor(max_workers=workers) as executor:
            while cursor < len(pending_ids):
                window_ids = pending_ids[cursor : cursor + workers]
                cursor += len(window_ids)

                futures = {
                    executor.submit(
                        process_item,
                        row=copy.deepcopy(rows[id_to_index[row_id]]),
                        model=args.model,
                        ollama_url=args.ollama_url,
                        mode=args.mode,
                    ): row_id
                    for row_id in window_ids
                }

                stop_code_window: int | None = None
                for future in as_completed(futures):
                    row_id = futures[future]
                    try:
                        updated_row, checkpoint_record = future.result()
                    except Exception as exc:
                        write_json_array(partial_path, rows)
                        print(f"Processing failed for id={row_id}: {exc}", file=sys.stderr)
                        return 5

                    stop_code = process_completed_item(
                        row_id=row_id,
                        updated_row=updated_row,
                        checkpoint_record=checkpoint_record,
                    )
                    if stop_code is not None:
                        stop_code_window = stop_code

                if stop_code_window is not None:
                    return stop_code_window

    all_ids = {int(row.get("id")) for row in rows if isinstance(row.get("id"), int)}
    full_completion = len(processed_ids.intersection(all_ids)) == len(all_ids)
    qa_stats: dict[str, Any] = {
        "sampled": 0,
        "failures": 0,
        "unresolved": 0,
        "fixed": 0,
        "audit_errors": 0,
        "failure_ratio": 0.0,
        "reasons": [],
    }

    if args.mode == "turbo_deterministic":
        qa_scope_ids = sorted(all_ids) if full_completion else sorted(processed_this_run_ids)
        qa_ok, qa_stats = run_spot_audit(
            rows=rows,
            ids_scope=qa_scope_ids,
            id_to_index=id_to_index,
            ollama_url=args.ollama_url,
            qa_model=args.qa_model,
            sample_rate=args.qa_sample_rate,
            qa_fail_threshold=args.qa_fail_threshold,
            checkpoint_path=checkpoint_path,
            workers=args.workers,
        )
        total_rewritten_total, total_fallback_total = load_checkpoint_metrics(checkpoint_path)
        if not qa_ok:
            write_json_array(output_path, rows)
            write_json_array(partial_path, rows)
            print("\nQA spot-audit failed quality gate.", file=sys.stderr)
            print(
                f"sampled={qa_stats['sampled']} failures={qa_stats['failures']} "
                f"unresolved={qa_stats['unresolved']} "
                f"failure_ratio={(qa_stats['failure_ratio'] * 100.0):.2f}% "
                f"threshold={(args.qa_fail_threshold * 100.0):.2f}%",
                file=sys.stderr,
            )
            if qa_stats["reasons"]:
                print("top QA failure reasons:", file=sys.stderr)
                for reason, count in qa_stats["reasons"]:
                    print(f"- {reason}: {count}", file=sys.stderr)
            return 6

    require_sentences_old = not args.strip_sentences_old_final
    if full_completion:
        ok, verify_errors = verify_rows(rows, ids_subset=None, require_sentences_old=require_sentences_old)
    else:
        ok, verify_errors = verify_rows(
            rows,
            ids_subset=processed_this_run_ids,
            require_sentences_old=require_sentences_old,
        )

    if not ok and full_completion and args.mode == "turbo_deterministic":
        failed_ids = parse_failed_ids(verify_errors)
        if failed_ids:
            print(
                f"Auto-repair pass: processing {len(failed_ids)} verification-failed IDs deterministically...",
                flush=True,
            )
            for row_id in failed_ids:
                idx = id_to_index.get(row_id)
                if idx is None:
                    continue
                repaired_row, repair_record = process_item(
                    row=rows[idx],
                    model=args.model,
                    ollama_url=args.ollama_url,
                    mode="turbo_deterministic",
                )
                metrics = repair_record.get("metrics")
                if isinstance(metrics, dict):
                    metrics["post_verify_repair"] = True
                errors = repair_record.get("errors")
                if isinstance(errors, list):
                    errors.append("post_verify_repair")
                append_checkpoint(checkpoint_path, repair_record)
                rows[idx] = repaired_row
            ok, verify_errors = verify_rows(rows, ids_subset=None, require_sentences_old=require_sentences_old)

    if full_completion and args.strip_sentences_old_final:
        for row in rows:
            row.pop("sentences_old", None)
        ok_strip, strip_errors = verify_rows(rows, ids_subset=None, require_sentences_old=False)
        if not ok_strip:
            verify_errors.extend(strip_errors)
            ok = False

    write_json_array(output_path, rows)
    write_json_array(partial_path, rows)
    canonical_path = args.input.parent / "seed_data.json"
    if full_completion:
        write_json_array(canonical_path, rows)

    print("\nRun report")
    print(f"processed count: {run_processed}")
    print(f"changed count: {run_changed}")
    kept_count = sum(len(record.get("kept", [])) for record in run_records)
    maintained_pct = (kept_count / (run_processed * 3) * 100.0) if run_processed > 0 else 0.0
    print(f"maintained-old-sentences: {kept_count}/{run_processed * 3 if run_processed else 0} ({maintained_pct:.2f}%)")
    if total_rewritten_total > 0:
        print(
            "fallback usage: "
            f"{total_fallback_total}/{total_rewritten_total} "
            f"({(total_fallback_total / total_rewritten_total) * 100.0:.2f}%)"
        )
    if args.mode == "turbo_deterministic":
        print(
            "qa spot-audit: "
            f"sampled={qa_stats['sampled']} failures={qa_stats['failures']} "
            f"unresolved={qa_stats['unresolved']} "
            f"fixed={qa_stats['fixed']} audit_errors={qa_stats['audit_errors']} "
            f"ratio={(qa_stats['failure_ratio'] * 100.0):.2f}%"
        )
    runtime_s = time.perf_counter() - run_start
    items_per_sec = (run_processed / runtime_s) if runtime_s > 0 else 0.0
    remaining_items = max(0, total_items_count - len(processed_ids))
    eta_seconds = (remaining_items / items_per_sec) if items_per_sec > 0 else float("inf")
    print(f"runtime_seconds: {runtime_s:.2f}")
    print(f"items_per_second: {items_per_sec:.4f}")
    if math.isfinite(eta_seconds):
        print(f"eta_seconds: {eta_seconds:.2f}")

    example_pairs = choose_example_pairs(changed_examples)
    for idx, example in enumerate(example_pairs, start=1):
        print(f"\nExample {idx} | id={example['id']} lemma={example['lemma']}")
        print(f"definition: {example['definition']}")
        print("before:")
        for sentence in example["before"]:
            print(f"- {sentence}")
        print("after:")
        for sentence in example["after"]:
            print(f"- {sentence}")

    if verify_errors:
        print("\nverification errors (first 20):")
        for line in verify_errors[:20]:
            print(f"- {line}")

    if not ok:
        print("\nRun failed verification.", file=sys.stderr)
        return 2

    if total_rewritten_total > 0:
        final_fallback_pct = (total_fallback_total / total_rewritten_total) * 100.0
        if final_fallback_pct > args.fallback_max_pct:
            print(
                f"\nRun failed fallback ceiling: {final_fallback_pct:.2f}% > {args.fallback_max_pct:.2f}%",
                file=sys.stderr,
            )
            return 4

    if full_completion:
        print("\nFull dataset verification passed.")
        # Once complete, keep canonical output and remove partial snapshot.
        try:
            partial_path.unlink(missing_ok=True)
        except Exception:
            pass
    else:
        print("\nPartial-run verification passed for processed subset.")

    print(f"Output written: {output_path}")
    print(f"Checkpoint: {checkpoint_path}")
    if full_completion:
        print(f"Canonical dataset written: {canonical_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
