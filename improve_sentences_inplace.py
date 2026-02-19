#!/usr/bin/env python3
"""Improve existing seed example sentences with minimal edits and strict validation."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from tools.text_utils import diversity_signature, find_cloze_index, validate_sentence, validate_set

DEFAULT_INPUT = Path("/Users/tuluyhan/projects/Lexical/Lexical/Resources/Seeds/seed_data.json")
DEFAULT_MODEL = "qwen2.5:14b"
DEFAULT_OLLAMA_URL = "http://127.0.0.1:11434"
SEVERITY_RANK = {"none": 0, "minor": 1, "major": 2, "fatal": 3}
STYLE_ORDER = ["question", "dialogue", "complex"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Improve seed sentence quality in-place with resume support")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--checkpoint", type=Path, default=None)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--chunk-size", type=int, default=200)
    parser.add_argument("--model", type=str, default=DEFAULT_MODEL)
    parser.add_argument("--ollama-url", type=str, default=DEFAULT_OLLAMA_URL)
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
) -> dict[str, Any]:
    endpoint = ollama_url.rstrip("/") + "/api/generate"
    body = {
        "model": model,
        "prompt": prompt,
        "format": "json",
        "stream": False,
        "options": {
            "temperature": temperature,
        },
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
    sentence_block = "\n".join(f"{idx}. {text}" for idx, text in enumerate(sentences))
    return f"""
You are an English sentence quality auditor and rewriter.
Task: Evaluate exactly 3 existing example sentences for lemma "{lemma}".
Definition: "{definition}"
Part of speech: {pos}
CEFR: {cefr}

Current sentences:
{sentence_block}

Rules:
- Keep good sentences unchanged.
- Rewrite only low-quality or meaning-mismatched ones.
- Fatal issues: lemma exact-token missing OR word count not in [8,25].
- Major issues: meaning mismatch with definition (including fixed-phrase meaning shift), unnatural/awkward English, trivial textbook sentence, or no context.
- Keep threshold: score >= 75 and no fatal/major issues.
- Use natural contextual scenarios.
- If action is REWRITE, provide one rewritten sentence.

Return ONLY JSON with this schema:
{{
  "sentences": [
    {{"index": 0, "score": 0, "severity": "none|minor|major|fatal", "reasons": ["..."], "action": "KEEP|REWRITE", "rewrite": "..."}},
    {{"index": 1, "score": 0, "severity": "none|minor|major|fatal", "reasons": ["..."], "action": "KEEP|REWRITE", "rewrite": "..."}},
    {{"index": 2, "score": 0, "severity": "none|minor|major|fatal", "reasons": ["..."], "action": "KEEP|REWRITE", "rewrite": "..."}}
  ],
  "set_notes": {{"issues": ["..."]}}
}}
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
        temperature=0.1,
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


def stable_pick(options: list[str], key: str) -> str:
    digest = hashlib.sha1(key.encode("utf-8")).digest()
    value = int.from_bytes(digest[:4], byteorder="big", signed=False)
    return options[value % len(options)]


def fallback_sentence(lemma: str, style: str, key: str) -> str:
    templates: dict[str, list[str]] = {
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
    }
    choices = templates.get(style, templates["contextual"])
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
    style_instruction = {
        "question": "Write a question sentence ending with '?'.",
        "dialogue": "Write a dialogue sentence with quoted speech using double quotes.",
        "complex": "Write a complex sentence with a subordinate clause using markers like although/while/because/unless/since/if/when.",
        "contextual": "Write a contextual scenario sentence.",
    }.get(style, "Write a contextual scenario sentence.")

    avoid_block = "\n".join(f"- {text}" for text in used_sentences if text)

    return f"""
Write exactly one natural English sentence for vocabulary learning.
Lemma: {lemma}
Definition: {definition}
Part of speech: {pos}
CEFR: {cefr}

Constraints:
- Must contain lemma as exact token match (case-insensitive).
- 8-25 words.
- Contextual/incidental learning style, not dictionary-style.
- Avoid trivial "He/She + verb + object" templates.
- Avoid copying or closely paraphrasing these existing sentences:
{avoid_block}
- {style_instruction}

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
    )
    sentence = normalize_text(payload.get("sentence", ""))
    if not sentence:
        raise ValueError("Empty generated sentence")
    return sentence


def compute_style_targets(
    *,
    texts: list[str],
    rewrite_indices: set[int],
    sentence_scores: dict[int, float],
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
    style_targets: dict[int, str] = {}
    pointer = 0
    for style in missing:
        if pointer >= len(ordered_rewrites):
            break
        style_targets[ordered_rewrites[pointer]] = style
        pointer += 1
    while pointer < len(ordered_rewrites):
        style_targets[ordered_rewrites[pointer]] = "contextual"
        pointer += 1

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
) -> tuple[str, list[str]]:
    errors: list[str] = []

    candidate = normalize_text(review_rewrite)
    if candidate:
        ok, reasons = validate_sentence(candidate, lemma)
        if ok and sentence_matches_style(candidate, style):
            return candidate, errors
        errors.append(f"review_candidate_invalid:{','.join(reasons) or 'style'}")

    for attempt in range(1, 4):
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
            errors.append(f"llm_generation_attempt_{attempt}_style_mismatch:{style}")
            continue

        return generated, errors

    fallback = fallback_sentence(lemma, style, key=f"{lemma}:{idx}:{style}:{definition}")
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
        forced = fallback_sentence(lemma, style, key=f"force:{lemma}:{idx}")
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
    )

    rewritten_records: dict[int, dict[str, Any]] = {}

    for idx in sorted(rewrite_indices):
        target_style = style_targets.get(idx, "contextual")
        analysis = review.get(idx, {})
        review_rewrite = str(analysis.get("rewrite", ""))

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

    checkpoint_record = {
        "id": row.get("id"),
        "lemma": lemma,
        "changed": changed,
        "kept": kept,
        "rewritten": rewritten,
        "errors": list(dict.fromkeys(error_log + validation_errors)),
    }
    return row, checkpoint_record


def verify_rows(rows: list[dict[str, Any]], ids_subset: set[int] | None = None) -> tuple[bool, list[str]]:
    errors: list[str] = []

    for row in rows:
        row_id = int(row.get("id", -1))
        if ids_subset is not None and row_id not in ids_subset:
            continue

        if "sentences_old" not in row:
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

    run_processed = 0
    run_changed = 0
    chunk_counter = 0
    changed_examples: list[dict[str, Any]] = []
    processed_this_run_ids: set[int] = set()

    for row_id in pending_ids:
        row = rows[id_to_index[row_id]]
        updated_row, checkpoint_record = process_item(
            row=row,
            model=args.model,
            ollama_url=args.ollama_url,
        )

        rows[id_to_index[row_id]] = updated_row
        append_checkpoint(checkpoint_path, checkpoint_record)

        run_processed += 1
        processed_ids.add(row_id)
        processed_this_run_ids.add(row_id)
        chunk_counter += 1

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

    write_json_array(output_path, rows)
    write_json_array(partial_path, rows)

    all_ids = {int(row.get("id")) for row in rows if isinstance(row.get("id"), int)}
    full_completion = len(processed_ids.intersection(all_ids)) == len(all_ids)

    if full_completion:
        ok, verify_errors = verify_rows(rows, ids_subset=None)
    else:
        ok, verify_errors = verify_rows(rows, ids_subset=processed_this_run_ids)

    print("\nRun report")
    print(f"processed count: {run_processed}")
    print(f"changed count: {run_changed}")

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
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
