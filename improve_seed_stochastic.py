#!/usr/bin/env python3
"""Non-deterministic full seed refactor for sentences and synonyms.

Pipeline goals:
- Full lemma-specific sentence rewrite (3 sentences per lemma) without reranker.
- Conservative synonym cleanup/regeneration.
- Local Ollama generation first, optional Gemini CLI escalation on failures.
- Sensitive lemma exclusion, ID resequencing, and roots remap.
- Resume-safe checkpointing with reason/error codes only (no sentence history).
"""

from __future__ import annotations

import argparse
import copy
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path
from typing import Any

from tools.text_utils import (
    diversity_signature,
    find_cloze_index,
    has_near_duplicates,
    sentence_skeleton,
    validate_sentence,
)

DEFAULT_SEED_PATH = Path("/Users/tuluyhan/projects/Lexical/Lexical/Resources/Seeds/seed_data.json")
DEFAULT_ROOTS_PATH = Path("/Users/tuluyhan/projects/Lexical/Lexical/Resources/Seeds/roots.json")
DEFAULT_OLLAMA_URL = "http://127.0.0.1:11434"
DEFAULT_LOCAL_MODEL = "qwen2.5:14b"
DEFAULT_GEMINI_BIN = "/opt/homebrew/bin/gemini"
DEFAULT_GEMINI_MODEL = "gemini-2.0-flash"
GEMINI_INVOKE_MODES = ("auto", "prompt", "positional")

TOKEN_RE = re.compile(r"\w+(?:'\w+)?|[^\w\s]")
WORDLIKE_RE = re.compile(r"\w+(?:'\w+)?")
PLACEHOLDER_RE = re.compile(
    r"<[^>]+>|\{\{[^}]+\}\}|\b(?:scenario|placeholder|sample|template)_word_\d+\b|lorem ipsum",
    re.IGNORECASE,
)
SYN_SYMBOLIC_RE = re.compile(r"[\[\]{}<>$€£¥§|~]+")

# Moderate safety block (aligned with existing repository policy).
BLOCKED_PATTERNS = [
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
    r"\bporn(?:o|ographic)?\b",
    r"\bmasturbat(?:e|es|ed|ion|ing)?\b",
]

# Explicit sensitive lemma exclusion set.
SENSITIVE_LEMMA_EXACT = {
    "rape",
    "suicide",
    "terrorist",
    "terrorism",
    "nazi",
    "porn",
    "pornography",
    "masturbation",
    "masturbate",
}

ADVERB_ALLOWED_NON_LY = {"well", "fast", "hard", "late", "early", "straight"}
DEFINITION_STOPWORDS = {
    "a",
    "an",
    "and",
    "are",
    "as",
    "at",
    "be",
    "by",
    "for",
    "from",
    "having",
    "in",
    "is",
    "it",
    "its",
    "more",
    "of",
    "on",
    "or",
    "that",
    "the",
    "to",
    "with",
}


def normalize_text(value: Any) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def definition_anchor_terms(definition: str, lemma: str, max_terms: int = 8) -> list[str]:
    lemma_key = normalize_text(lemma).lower()
    terms: list[str] = []
    seen: set[str] = set()
    for token in TOKEN_RE.findall(normalize_text(definition).lower()):
        if not WORDLIKE_RE.fullmatch(token):
            continue
        if token in DEFINITION_STOPWORDS:
            continue
        if token == lemma_key:
            continue
        if len(token) < 3:
            continue
        if token in seen:
            continue
        seen.add(token)
        terms.append(token)
        if len(terms) >= max_terms:
            break
    return terms


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def timestamp_token() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")


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

    parser = argparse.ArgumentParser(description="Stochastic full refactor for seed sentences and synonyms")
    parser.add_argument("--input-seed", type=Path, default=DEFAULT_SEED_PATH)
    parser.add_argument("--input-roots", type=Path, default=DEFAULT_ROOTS_PATH)
    parser.add_argument("--output-seed", type=Path, default=None)
    parser.add_argument("--output-roots", type=Path, default=None)
    parser.add_argument("--checkpoint", type=Path, default=None)
    parser.add_argument("--exclusion-report", type=Path, default=None)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--chunk-size", type=int, default=100)
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--cloud-workers", type=int, default=1)
    parser.add_argument("--ollama-url", type=str, default=DEFAULT_OLLAMA_URL)
    parser.add_argument("--local-model", type=str, default=DEFAULT_LOCAL_MODEL)
    parser.add_argument("--gemini-bin", type=str, default=DEFAULT_GEMINI_BIN)
    parser.add_argument("--gemini-model", type=str, default=DEFAULT_GEMINI_MODEL)
    parser.add_argument("--gemini-invoke-mode", type=str, default="auto", choices=GEMINI_INVOKE_MODES)
    parser.add_argument("--local-retries", type=int, default=2)
    parser.add_argument("--cloud-retries", type=int, default=1)
    parser.add_argument("--temperature", type=float, default=0.8)
    parser.add_argument("--local-timeout-s", type=int, default=45)
    parser.add_argument("--local-num-predict", type=int, default=180)
    parser.add_argument("--local-keep-alive", type=str, default="30m")
    parser.add_argument("--cloud-timeout-s", type=int, default=60)
    parser.add_argument("--batch-size", type=int, default=0)
    parser.add_argument("--near-dup-threshold", type=float, default=0.9)
    parser.add_argument("--global-skeleton-cap", type=int, default=24)
    parser.add_argument("--progress-interval-s", type=int, default=20)
    parser.add_argument("--apply", type=str_to_bool, default=True)
    parser.add_argument("--backup", type=str_to_bool, default=True)
    return parser.parse_args()


def partial_seed_path(output_seed: Path) -> Path:
    return output_seed.with_name(f"{output_seed.stem}.partial{output_seed.suffix}")


def read_checkpoint(path: Path) -> dict[int, dict[str, Any]]:
    records: dict[int, dict[str, Any]] = {}
    if not path.exists():
        return records

    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        payload = json.loads(line)
        row_id = payload.get("id")
        if isinstance(row_id, int):
            records[row_id] = payload
    return records


def append_checkpoint(path: Path, record: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")


def extract_json_object(text: str) -> dict[str, Any]:
    cleaned = normalize_text(text)
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
        raise ValueError("No JSON object found")

    payload = json.loads(cleaned[start : end + 1])
    if not isinstance(payload, dict):
        raise ValueError("JSON payload must be an object")
    return payload


def call_ollama_json(
    *,
    ollama_url: str,
    model: str,
    prompt: str,
    temperature: float,
    timeout_s: int = 45,
    num_predict: int = 180,
    keep_alive: str = "30m",
) -> dict[str, Any]:
    endpoint = ollama_url.rstrip("/") + "/api/generate"
    body = {
        "model": model,
        "prompt": prompt,
        "format": "json",
        "stream": False,
        "keep_alive": keep_alive,
        "options": {
            "temperature": float(temperature),
            "num_predict": int(num_predict),
        },
    }
    request = urllib.request.Request(
        endpoint,
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout_s) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.URLError as exc:
        raise RuntimeError(f"ollama_request_failed:{exc}") from exc

    if not isinstance(payload, dict) or "response" not in payload:
        raise RuntimeError("ollama_response_malformed")
    return extract_json_object(str(payload.get("response", "")))


def call_gemini_json(
    *,
    gemini_bin: str,
    model: str,
    prompt: str,
    invoke_mode: str = "auto",
    timeout_s: int = 180,
) -> dict[str, Any]:
    def run_cmd(cmd: list[str]) -> subprocess.CompletedProcess[str]:
        try:
            return subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout_s,
                check=False,
            )
        except subprocess.TimeoutExpired as exc:  # pragma: no cover - runtime edge
            raise RuntimeError("gemini_timeout") from exc

    def parse_stdout(stdout: str) -> dict[str, Any]:
        lines = stdout.splitlines()
        json_start = None
        for idx, line in enumerate(lines):
            if line.lstrip().startswith("{"):
                json_start = idx
                break
        candidate = "\n".join(lines[json_start:]) if json_start is not None else stdout
        outer = extract_json_object(candidate)
        response_text = normalize_text(outer.get("response", ""))

        # Some Gemini CLI builds can return an agent readiness preamble for -p mode.
        if re.search(r"\bready for (?:your|the) command\b", response_text, re.IGNORECASE):
            raise ValueError("gemini_ready_preamble")

        return extract_json_object(response_text)

    mode = invoke_mode if invoke_mode in GEMINI_INVOKE_MODES else "auto"

    primary: subprocess.CompletedProcess[str] | None = None
    if mode in {"auto", "prompt"}:
        primary = run_cmd([gemini_bin, "-p", prompt, "-m", model, "--output-format", "json"])
        if primary.returncode == 0:
            try:
                return parse_stdout(primary.stdout)
            except Exception:
                if mode == "prompt":
                    raise RuntimeError("gemini_prompt_parse_failed")
        elif mode == "prompt":
            stderr = normalize_text(primary.stderr)
            raise RuntimeError(f"gemini_returncode_{primary.returncode}:{stderr[:200]}")

    if mode in {"auto", "positional"}:
        fallback = run_cmd([gemini_bin, prompt, "-m", model, "--output-format", "json", "-e", ""])
        if fallback.returncode == 0:
            return parse_stdout(fallback.stdout)
        stderr = normalize_text(fallback.stderr or (primary.stderr if primary is not None else ""))
        code = fallback.returncode
        raise RuntimeError(f"gemini_returncode_{code}:{stderr[:200]}")

    raise RuntimeError("gemini_invoke_mode_unhandled")


def is_sensitive_lemma(lemma: str) -> bool:
    key = normalize_text(lemma).lower()
    return key in SENSITIVE_LEMMA_EXACT


def compile_blocked_patterns() -> list[re.Pattern[str]]:
    return [re.compile(pattern, re.IGNORECASE) for pattern in BLOCKED_PATTERNS]


def is_text_blocked(text: str, blocked: list[re.Pattern[str]]) -> bool:
    normalized = normalize_text(text)
    if not normalized:
        return False
    if PLACEHOLDER_RE.search(normalized):
        return True
    return any(regex.search(normalized) for regex in blocked)


def normalize_synonym(term: Any) -> str:
    text = normalize_text(term)
    text = text.strip('"\'`.,;:!?()[]{}')
    text = re.sub(r"\s+", " ", text)
    return text


def is_pos_compatible_synonym(term: str, pos: str) -> bool:
    lowered = term.lower()
    pos_key = normalize_text(pos).lower()

    if pos_key in {"adverb", "adv"}:
        return lowered.endswith("ly") or lowered in ADVERB_ALLOWED_NON_LY

    if pos_key in {"verb"}:
        if lowered.endswith("ly"):
            return False
        if lowered.startswith("to "):
            return False
        return True

    if pos_key in {"adjective", "adj"}:
        if lowered.startswith("to "):
            return False
        return True

    if pos_key in {"noun"}:
        words = lowered.split()
        if len(words) > 3:
            return False
        return True

    return True


def clean_synonyms_conservative(
    *,
    synonyms: list[str],
    lemma: str,
    pos: str,
    max_count: int = 6,
) -> list[str]:
    blocked = compile_blocked_patterns()
    lemma_key = normalize_text(lemma).lower()
    output: list[str] = []
    seen: set[str] = set()

    for raw in synonyms:
        term = normalize_synonym(raw)
        if not term:
            continue
        key = term.lower()

        if key == lemma_key:
            continue
        if key in seen:
            continue
        if len(term) < 2 or len(term) > 32:
            continue
        if SYN_SYMBOLIC_RE.search(term):
            continue
        if any(ch.isdigit() for ch in term):
            continue
        if not any(ch.isalpha() for ch in term):
            continue
        if len(term.split()) > 4:
            continue
        if "." in term:
            continue
        if is_text_blocked(term, blocked):
            continue
        if not is_pos_compatible_synonym(term, pos):
            continue

        seen.add(key)
        output.append(term)
        if len(output) >= max_count:
            break

    return output


def first_word(text: str) -> str:
    for token in TOKEN_RE.findall(text):
        if WORDLIKE_RE.fullmatch(token):
            return token.lower()
    return ""


def sentence_terminal(text: str) -> str:
    tokens = TOKEN_RE.findall(text)
    for token in reversed(tokens):
        if token.strip():
            return token
    return ""


def validate_sentence_set_quality(
    *,
    sentences: list[str],
    lemma: str,
    near_dup_threshold: float,
) -> tuple[bool, list[str]]:
    reasons: list[str] = []
    if len(sentences) != 3:
        reasons.append("invalid_sentence_count")
        return False, reasons

    normalized = [normalize_text(text) for text in sentences]
    if any(not text for text in normalized):
        reasons.append("empty_sentence")

    for idx, text in enumerate(normalized):
        ok, sentence_reasons = validate_sentence(text, lemma)
        if not ok:
            reasons.extend(f"sentence_{idx}_{code}" for code in sentence_reasons)

    lowered = [text.lower() for text in normalized]
    if len(set(lowered)) != len(lowered):
        reasons.append("duplicate_sentences")

    if has_near_duplicates(normalized, threshold=near_dup_threshold):
        reasons.append("near_duplicate_sentences")

    starts = [first_word(text) for text in normalized]
    same_start = bool(starts and len(set(starts)) == 1)

    terminals = [sentence_terminal(text) for text in normalized]
    same_terminal = bool(terminals and len(set(terminals)) == 1)

    # Soft structure diversity (no hard trio): only fail when all diversity signals collapse.
    signatures = [diversity_signature(text) for text in normalized]
    structure_keys = [
        (
            bool(sig["has_question"]),
            bool(sig["has_quote"]),
            bool(sig["has_complex_clause"]),
        )
        for sig in signatures
    ]
    same_structure = len(set(structure_keys)) == 1
    if same_start and same_terminal and same_structure:
        reasons.append("insufficient_set_variety")

    return len(reasons) == 0, sorted(set(reasons))


def build_generation_prompt(
    *,
    lemma: str,
    definition: str,
    pos: str,
    cefr: str,
    existing_synonyms: list[str],
    banned_terms: list[str],
    recent_skeleton_hints: list[str],
) -> str:
    synonym_text = ", ".join(existing_synonyms) if existing_synonyms else "(none)"
    banned_text = ", ".join(banned_terms)
    hint_text = "\n".join(f"- {hint}" for hint in recent_skeleton_hints) if recent_skeleton_hints else "- (none)"
    anchors = definition_anchor_terms(definition, lemma)
    anchor_text = ", ".join(anchors) if anchors else "(none)"
    pos_key = normalize_text(pos).lower()
    if pos_key == "noun":
        pos_guidance = 'Use the lemma as a noun phrase head (entity/concept), not as a verb.'
    elif pos_key == "verb":
        pos_guidance = "Use the lemma as an action/event in the clause, not as a plain noun label."
    elif pos_key in {"adjective", "adj"}:
        pos_guidance = "Use the lemma to modify a noun naturally; avoid turning it into a noun."
    elif pos_key in {"adverb", "adv"}:
        pos_guidance = "Use the lemma to modify a verb/adjective/clause naturally."
    else:
        pos_guidance = "Keep grammatical role consistent with the POS value."

    return f"""
You are generating production vocabulary seed data for ONE lemma.

Inputs:
- lemma: "{lemma}"
- definition: "{definition}"
- pos: "{pos}"
- cefr: "{cefr}"
- existing_synonyms: {synonym_text}

Return STRICT JSON only:
{{"sentences":["...","...","..."],"synonyms":["..."],"notes":["reason_code"]}}

Hard constraints:
1) Output exactly 3 sentences.
2) Every sentence must contain "{lemma}" as a standalone token (case-insensitive exact token match).
3) Each sentence length must be 8-14 words.
4) Meaning must align with the definition and POS.
4b) POS enforcement: {pos_guidance}
4c) Sense anchors (use at least one anchor idea across the set): {anchor_text}
5) Avoid banned terms: {banned_text}
6) Avoid overused skeleton hints:
{hint_text}

Quality bar (important):
- Write vivid, specific mini-scenarios (work email, travel delay, family disagreement, policy debate, billing issue).
- Use concrete details and natural collocations; avoid vague abstractions.
- Vary rhythm and syntax across the 3 lines (do not clone one pattern).
- Make each sentence do a different communicative job: observation, interaction/response, consequence or decision.
- Keep modern, conversational but grammatically clean English.

Anti-patterns to avoid:
- Dictionary style: "X means ..." / "X is ..."
- Generic templates to avoid:
  - "The {lemma} is important."
  - "This {lemma} is very good."
  - "People use {lemma} every day."
- Empty praise words without context ("important", "good", "bad", "useful") as the main predicate.
- Repeating the same frame across all 3 sentences.
- Using {lemma} only inside a fixed phrase that shifts away from the target sense.
- If lemma is polysemous, choose context cues that clearly lock the intended sense from the definition.

Calibration examples:
- weak: "The management is important for every company."
- strong: "After two missed deadlines, management moved the launch and explained the tradeoff to investors."

Synonyms policy:
- Provide 3-6 concise, same-POS lexical synonyms only if confident.
- Never include the lemma itself.
- No symbols, markup, numerals, profanity, or explanations.
""".strip()


def normalized_candidate(payload: dict[str, Any]) -> tuple[list[str], list[str], list[str]]:
    raw_sentences = payload.get("sentences", [])
    raw_synonyms = payload.get("synonyms", [])
    raw_notes = payload.get("notes", [])

    sentences = [normalize_text(text) for text in raw_sentences] if isinstance(raw_sentences, list) else []
    synonyms = [normalize_text(text) for text in raw_synonyms] if isinstance(raw_synonyms, list) else []
    notes = [normalize_text(text) for text in raw_notes] if isinstance(raw_notes, list) else []

    sentences = [text for text in sentences if text]
    synonyms = [text for text in synonyms if text]
    notes = [text for text in notes if text]
    return sentences, synonyms, notes


def sentence_entries_from_texts(sentences: list[str], lemma: str) -> tuple[list[dict[str, Any]], list[str]]:
    entries: list[dict[str, Any]] = []
    errors: list[str] = []
    for idx, text in enumerate(sentences):
        cloze = find_cloze_index(text, lemma)
        if cloze is None:
            errors.append(f"sentence_{idx}_cloze_missing")
            cloze = 0
        entries.append({"text": text, "cloze_index": cloze})
    return entries, errors


def candidate_skeletons(sentences: list[str], lemma: str) -> list[str]:
    return [sentence_skeleton(text, lemma) for text in sentences]


def violates_global_skeleton_cap(
    *,
    sentences: list[str],
    lemma: str,
    counter: Counter[str],
    cap: int,
) -> tuple[bool, list[str], list[str]]:
    skeletons = candidate_skeletons(sentences, lemma)
    offenders: list[str] = []
    for skeleton in skeletons:
        if counter[skeleton] + 1 > cap:
            offenders.append(skeleton)
    return (len(offenders) > 0, offenders, skeletons)


def init_blocked_terms() -> list[str]:
    terms: list[str] = []
    for pattern in BLOCKED_PATTERNS:
        term = re.sub(r"\\b", "", pattern)
        term = re.sub(r"\(\?:[^\)]*\)", "", term)
        term = term.replace("\\", "")
        term = term.strip("^$")
        if term:
            terms.append(term)
    return sorted(set(terms))


def row_prompt_context(row: dict[str, Any]) -> tuple[str, str, str, str, list[str]]:
    lemma = normalize_text(row.get("lemma", ""))
    definition = normalize_text(row.get("definition", ""))
    pos = normalize_text(row.get("pos", ""))
    cefr = normalize_text(row.get("cefr", ""))
    existing_synonyms = row.get("synonym", [])
    if not isinstance(existing_synonyms, list):
        existing_synonyms = []
    cleaned_existing = clean_synonyms_conservative(
        synonyms=[normalize_text(x) for x in existing_synonyms],
        lemma=lemma,
        pos=pos,
        max_count=6,
    )
    return lemma, definition, pos, cefr, cleaned_existing


def generate_one_candidate_local(
    *,
    row: dict[str, Any],
    ollama_url: str,
    local_model: str,
    temperature: float,
    timeout_s: int,
    num_predict: int,
    keep_alive: str,
    banned_terms: list[str],
    recent_hints: list[str],
) -> tuple[list[str], list[str], list[str], list[str]]:
    lemma, definition, pos, cefr, cleaned_existing = row_prompt_context(row)
    prompt = build_generation_prompt(
        lemma=lemma,
        definition=definition,
        pos=pos,
        cefr=cefr,
        existing_synonyms=cleaned_existing,
        banned_terms=banned_terms,
        recent_skeleton_hints=recent_hints,
    )
    payload = call_ollama_json(
        ollama_url=ollama_url,
        model=local_model,
        prompt=prompt,
        temperature=temperature,
        timeout_s=timeout_s,
        num_predict=num_predict,
        keep_alive=keep_alive,
    )
    return (*normalized_candidate(payload), cleaned_existing)


def generate_one_candidate_cloud(
    *,
    row: dict[str, Any],
    gemini_bin: str,
    gemini_model: str,
    gemini_invoke_mode: str,
    timeout_s: int,
    banned_terms: list[str],
    recent_hints: list[str],
) -> tuple[list[str], list[str], list[str], list[str]]:
    lemma, definition, pos, cefr, cleaned_existing = row_prompt_context(row)
    prompt = build_generation_prompt(
        lemma=lemma,
        definition=definition,
        pos=pos,
        cefr=cefr,
        existing_synonyms=cleaned_existing,
        banned_terms=banned_terms,
        recent_skeleton_hints=recent_hints,
    )
    payload = call_gemini_json(
        gemini_bin=gemini_bin,
        model=gemini_model,
        prompt=prompt,
        invoke_mode=gemini_invoke_mode,
        timeout_s=timeout_s,
    )
    return (*normalized_candidate(payload), cleaned_existing)


def merge_synonyms(
    *,
    generated_synonyms: list[str],
    cleaned_existing_synonyms: list[str],
    lemma: str,
    pos: str,
) -> list[str]:
    candidate = clean_synonyms_conservative(
        synonyms=generated_synonyms,
        lemma=lemma,
        pos=pos,
        max_count=6,
    )
    existing = clean_synonyms_conservative(
        synonyms=cleaned_existing_synonyms,
        lemma=lemma,
        pos=pos,
        max_count=6,
    )

    merged: list[str] = []
    seen: set[str] = set()
    for term in candidate + existing:
        key = term.lower()
        if key in seen:
            continue
        seen.add(key)
        merged.append(term)
        if len(merged) >= 6:
            break

    if len(merged) >= 3:
        return merged[:6]
    if len(merged) >= 1:
        return merged
    return []


def process_candidate(
    *,
    row: dict[str, Any],
    sentences: list[str],
    generated_synonyms: list[str],
    cleaned_existing_synonyms: list[str],
    notes: list[str],
    blocked_regexes: list[re.Pattern[str]],
    near_dup_threshold: float,
    skeleton_counter: Counter[str],
    skeleton_cap: int,
) -> tuple[bool, dict[str, Any], list[str], list[str], list[str]]:
    lemma = normalize_text(row.get("lemma", ""))
    pos = normalize_text(row.get("pos", ""))
    reason_codes: list[str] = []
    error_codes: list[str] = []

    ok, reasons = validate_sentence_set_quality(
        sentences=sentences,
        lemma=lemma,
        near_dup_threshold=near_dup_threshold,
    )
    if not ok:
        error_codes.extend(reasons)
        return False, row, reason_codes, error_codes, []

    for idx, sentence in enumerate(sentences):
        if is_text_blocked(sentence, blocked_regexes):
            error_codes.append(f"sentence_{idx}_blocked")
            return False, row, reason_codes, error_codes, []

    violates_cap, offenders, skeletons = violates_global_skeleton_cap(
        sentences=sentences,
        lemma=lemma,
        counter=skeleton_counter,
        cap=skeleton_cap,
    )
    if violates_cap:
        error_codes.append("global_skeleton_cap_exceeded")
        error_codes.extend(f"skeleton_cap:{value[:120]}" for value in offenders[:2])
        return False, row, reason_codes, error_codes, []

    merged_synonyms = merge_synonyms(
        generated_synonyms=generated_synonyms,
        cleaned_existing_synonyms=cleaned_existing_synonyms,
        lemma=lemma,
        pos=pos,
    )
    if not merged_synonyms:
        error_codes.append("synonyms_empty_after_cleanup")
        return False, row, reason_codes, error_codes, []

    entries, cloze_errors = sentence_entries_from_texts(sentences, lemma)
    if cloze_errors:
        error_codes.extend(cloze_errors)
        return False, row, reason_codes, error_codes, []

    updated = copy.deepcopy(row)
    updated["sentences"] = entries
    updated["synonym"] = merged_synonyms

    if notes:
        reason_codes.extend(f"model_note:{note}" for note in notes[:3])

    return True, updated, sorted(set(reason_codes)), sorted(set(error_codes)), skeletons


def resequence_rows(rows: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], dict[int, int]]:
    remapped: list[dict[str, Any]] = []
    id_map: dict[int, int] = {}

    for new_id, row in enumerate(rows, start=1):
        item = copy.deepcopy(row)
        old_id = item.get("id")
        if isinstance(old_id, int):
            id_map[old_id] = new_id
        item["id"] = new_id
        remapped.append(item)

    return remapped, id_map


def remap_roots_word_ids(
    roots: list[dict[str, Any]],
    id_map: dict[int, int],
) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []

    for root in roots:
        candidate = copy.deepcopy(root)
        word_ids = candidate.get("word_ids", [])
        if not isinstance(word_ids, list):
            word_ids = []

        remapped_ids: list[int] = []
        seen: set[int] = set()
        for word_id in word_ids:
            if not isinstance(word_id, int):
                continue
            mapped = id_map.get(word_id)
            if mapped is None:
                continue
            if mapped in seen:
                continue
            seen.add(mapped)
            remapped_ids.append(mapped)

        if not remapped_ids:
            continue

        candidate["word_ids"] = remapped_ids
        output.append(candidate)

    return output


def audit_rows(
    *,
    rows: list[dict[str, Any]],
    blocked_regexes: list[re.Pattern[str]],
    near_dup_threshold: float,
    skeleton_cap: int,
) -> tuple[bool, list[str]]:
    errors: list[str] = []
    skeleton_counter: Counter[str] = Counter()

    for row in rows:
        row_id = row.get("id")
        lemma = normalize_text(row.get("lemma", ""))

        if is_sensitive_lemma(lemma):
            errors.append(f"id={row_id}:sensitive_lemma_present")

        if is_text_blocked(lemma, blocked_regexes):
            errors.append(f"id={row_id}:lemma_blocked")

        sentences = row.get("sentences", [])
        if not isinstance(sentences, list) or len(sentences) != 3:
            errors.append(f"id={row_id}:invalid_sentence_count")
            continue

        sentence_texts: list[str] = []
        for idx, sentence in enumerate(sentences):
            if not isinstance(sentence, dict):
                errors.append(f"id={row_id}:sentence_{idx}_not_object")
                continue
            text = normalize_text(sentence.get("text", ""))
            sentence_texts.append(text)
            ok, reasons = validate_sentence(text, lemma)
            if not ok:
                errors.extend(f"id={row_id}:sentence_{idx}:{reason}" for reason in reasons)
            cloze = sentence.get("cloze_index")
            expected = find_cloze_index(text, lemma)
            if not isinstance(cloze, int) or expected is None or cloze != expected:
                errors.append(f"id={row_id}:sentence_{idx}:cloze_mismatch")
            if is_text_blocked(text, blocked_regexes):
                errors.append(f"id={row_id}:sentence_{idx}:blocked")

        ok_set, reasons_set = validate_sentence_set_quality(
            sentences=sentence_texts,
            lemma=lemma,
            near_dup_threshold=near_dup_threshold,
        )
        if not ok_set:
            errors.extend(f"id={row_id}:set:{reason}" for reason in reasons_set)

        synonyms = row.get("synonym", [])
        if not isinstance(synonyms, list):
            errors.append(f"id={row_id}:synonym_not_list")
            synonyms = []
        pos = normalize_text(row.get("pos", ""))
        cleaned = clean_synonyms_conservative(
            synonyms=[normalize_text(term) for term in synonyms],
            lemma=lemma,
            pos=pos,
            max_count=6,
        )
        if len(cleaned) < 1:
            errors.append(f"id={row_id}:synonym_empty")

        for skeleton in candidate_skeletons(sentence_texts, lemma):
            skeleton_counter[skeleton] += 1
            if skeleton_counter[skeleton] > skeleton_cap:
                errors.append(f"id={row_id}:skeleton_cap_exceeded")

    return len(errors) == 0, errors


def audit_roots(roots: list[dict[str, Any]], rows: list[dict[str, Any]]) -> tuple[bool, list[str]]:
    errors: list[str] = []
    valid_ids = {row.get("id") for row in rows if isinstance(row.get("id"), int)}

    for idx, root in enumerate(roots):
        word_ids = root.get("word_ids", [])
        if not isinstance(word_ids, list) or not word_ids:
            errors.append(f"root_index={idx}:empty_word_ids")
            continue
        seen: set[int] = set()
        for word_id in word_ids:
            if not isinstance(word_id, int):
                errors.append(f"root_index={idx}:non_int_word_id")
                continue
            if word_id not in valid_ids:
                errors.append(f"root_index={idx}:word_id_missing:{word_id}")
            if word_id in seen:
                errors.append(f"root_index={idx}:duplicate_word_id:{word_id}")
            seen.add(word_id)

    return len(errors) == 0, errors


def make_checkpoint_record(
    *,
    row_id: int,
    status: str,
    attempts_local: int,
    attempts_cloud: int,
    changed: bool,
    reason_codes: list[str],
    error_codes: list[str],
) -> dict[str, Any]:
    return {
        "id": row_id,
        "status": status,
        "attempts_local": attempts_local,
        "attempts_cloud": attempts_cloud,
        "changed": bool(changed),
        "reason_codes": sorted(set(reason_codes)),
        "error_codes": sorted(set(error_codes)),
    }


def build_backup_paths(seed_path: Path, roots_path: Path) -> tuple[Path, Path]:
    stamp = timestamp_token()
    seed_backup = seed_path.with_name(f"{seed_path.stem}.backup_{stamp}{seed_path.suffix}")
    roots_backup = roots_path.with_name(f"{roots_path.stem}.backup_{stamp}{roots_path.suffix}")
    return seed_backup, roots_backup


def write_exclusion_report(path: Path, excluded: list[dict[str, Any]]) -> None:
    report = {
        "removed_count": len(excluded),
        "removed": excluded,
    }
    write_json(path, report)


def top_recent_skeletons(counter: Counter[str], limit: int = 8) -> list[str]:
    return [skeleton for skeleton, _ in counter.most_common(limit)]


def main() -> int:
    args = parse_args()

    if not args.input_seed.exists():
        print(f"Seed input not found: {args.input_seed}", file=sys.stderr)
        return 1
    if not args.input_roots.exists():
        print(f"Roots input not found: {args.input_roots}", file=sys.stderr)
        return 1

    output_seed = args.output_seed or args.input_seed.with_name("seed_data_refined.json")
    output_roots = args.output_roots or args.input_roots.with_name("roots_refined.json")
    checkpoint = args.checkpoint or args.input_seed.with_name("stochastic_checkpoint.jsonl")
    exclusion_report = args.exclusion_report or args.input_seed.with_name("sensitive_exclusions.report.json")
    partial_seed = partial_seed_path(output_seed)

    checkpoint_records = read_checkpoint(checkpoint)
    processed_ids = set(checkpoint_records.keys())

    if checkpoint.exists() and processed_ids:
        if partial_seed.exists():
            rows = load_json(partial_seed)
        elif output_seed.exists():
            rows = load_json(output_seed)
        else:
            print(
                "Checkpoint exists but no resumable snapshot found "
                f"({partial_seed.name} or {output_seed.name}).",
                file=sys.stderr,
            )
            return 1
    else:
        rows = load_json(args.input_seed)

    if not isinstance(rows, list):
        raise ValueError("Seed payload must be a JSON array")

    roots_payload = load_json(args.input_roots)
    if not isinstance(roots_payload, list):
        raise ValueError("Roots payload must be a JSON array")

    blocked_regexes = compile_blocked_patterns()
    banned_terms = init_blocked_terms()

    # Sensitive exclusion (tracked once in checkpoint as processed status).
    excluded_report_rows: list[dict[str, Any]] = []
    filtered_rows: list[dict[str, Any]] = []
    for row in rows:
        row_id = row.get("id")
        lemma = normalize_text(row.get("lemma", ""))
        if is_sensitive_lemma(lemma):
            if isinstance(row_id, int) and row_id not in processed_ids:
                record = make_checkpoint_record(
                    row_id=row_id,
                    status="excluded_sensitive",
                    attempts_local=0,
                    attempts_cloud=0,
                    changed=False,
                    reason_codes=["sensitive_lemma_excluded"],
                    error_codes=[],
                )
                append_checkpoint(checkpoint, record)
                checkpoint_records[row_id] = record
                processed_ids.add(row_id)
            excluded_report_rows.append({"id": row_id, "lemma": lemma})
            continue
        filtered_rows.append(row)

    rows = filtered_rows
    write_exclusion_report(exclusion_report, excluded_report_rows)

    id_to_index: dict[int, int] = {}
    for idx, row in enumerate(rows):
        row_id = row.get("id")
        if isinstance(row_id, int):
            id_to_index[row_id] = idx

    pending_ids = [row_id for row_id in id_to_index if row_id not in processed_ids]
    pending_ids.sort(key=lambda x: id_to_index[x])
    if args.limit is not None:
        pending_ids = pending_ids[: args.limit]

    skeleton_counter: Counter[str] = Counter()
    for row_id in sorted(set(id_to_index) - set(pending_ids)):
        row = rows[id_to_index[row_id]]
        lemma = normalize_text(row.get("lemma", ""))
        for sentence in row.get("sentences", []):
            if isinstance(sentence, dict):
                text = normalize_text(sentence.get("text", ""))
                if text:
                    skeleton_counter[sentence_skeleton(text, lemma)] += 1

    start = time.perf_counter()
    processed_now = 0
    changed_now = 0
    escalated_now = 0

    def local_task(row_id: int) -> tuple[int, Any, str | None]:
        row = rows[id_to_index[row_id]]
        try:
            payload = generate_one_candidate_local(
                row=row,
                ollama_url=args.ollama_url,
                local_model=args.local_model,
                temperature=args.temperature,
                timeout_s=args.local_timeout_s,
                num_predict=args.local_num_predict,
                keep_alive=args.local_keep_alive,
                banned_terms=banned_terms,
                recent_hints=top_recent_skeletons(skeleton_counter),
            )
            return row_id, payload, None
        except Exception as exc:  # pragma: no cover - network/runtime edge
            return row_id, None, str(exc)

    def cloud_task(row_id: int) -> tuple[int, Any, str | None]:
        row = rows[id_to_index[row_id]]
        try:
            payload = generate_one_candidate_cloud(
                row=row,
                gemini_bin=args.gemini_bin,
                gemini_model=args.gemini_model,
                gemini_invoke_mode=args.gemini_invoke_mode,
                timeout_s=args.cloud_timeout_s,
                banned_terms=banned_terms,
                recent_hints=top_recent_skeletons(skeleton_counter),
            )
            return row_id, payload, None
        except Exception as exc:  # pragma: no cover - network/runtime edge
            return row_id, None, str(exc)

    batch_size = args.batch_size if args.batch_size > 0 else max(args.workers * 2, 4)

    last_progress_at = start

    for cursor in range(0, len(pending_ids), batch_size):
        batch_ids = pending_ids[cursor : cursor + batch_size]

        states: dict[int, dict[str, Any]] = {
            row_id: {
                "row_id": row_id,
                "accepted": False,
                "local_attempts": 0,
                "cloud_attempts": 0,
                "changed": False,
                "reason_codes": [],
                "error_codes": [],
                "candidate": None,
                "candidate_payload": None,
            }
            for row_id in batch_ids
        }

        # Local attempts wave(s)
        unresolved = list(batch_ids)
        for local_round in range(max(0, args.local_retries)):
            if not unresolved:
                break

            results: dict[int, tuple[Any, str | None]] = {}
            with ThreadPoolExecutor(max_workers=max(1, args.workers)) as pool:
                futures = {pool.submit(local_task, row_id): row_id for row_id in unresolved}
                for future in as_completed(futures):
                    row_id = futures[future]
                    result_row_id, payload, err = future.result()
                    if row_id != result_row_id:
                        err = "row_id_mismatch"
                        payload = None
                    results[row_id] = (payload, err)

            next_unresolved: list[int] = []
            for row_id in unresolved:
                state = states[row_id]
                state["local_attempts"] += 1
                payload, err = results.get(row_id, (None, "missing_local_result"))
                if err is not None:
                    state["error_codes"].append(f"local_attempt_{local_round + 1}:{err}")
                    next_unresolved.append(row_id)
                    continue

                sentences, synonyms, notes, cleaned_existing = payload
                ok, updated, reasons, errors, skeletons = process_candidate(
                    row=rows[id_to_index[row_id]],
                    sentences=sentences,
                    generated_synonyms=synonyms,
                    cleaned_existing_synonyms=cleaned_existing,
                    notes=notes,
                    blocked_regexes=blocked_regexes,
                    near_dup_threshold=args.near_dup_threshold,
                    skeleton_counter=skeleton_counter,
                    skeleton_cap=args.global_skeleton_cap,
                )
                if not ok:
                    state["error_codes"].extend(f"local_attempt_{local_round + 1}:{code}" for code in errors)
                    next_unresolved.append(row_id)
                    continue

                state["accepted"] = True
                state["changed"] = True
                state["candidate"] = updated
                state["candidate_payload"] = (reasons, errors, skeletons)

            unresolved = next_unresolved

        # Cloud attempt wave(s)
        for cloud_round in range(max(0, args.cloud_retries)):
            if not unresolved:
                break

            results: dict[int, tuple[Any, str | None]] = {}
            with ThreadPoolExecutor(max_workers=max(1, args.cloud_workers)) as pool:
                futures = {pool.submit(cloud_task, row_id): row_id for row_id in unresolved}
                for future in as_completed(futures):
                    row_id = futures[future]
                    result_row_id, payload, err = future.result()
                    if row_id != result_row_id:
                        err = "row_id_mismatch"
                        payload = None
                    results[row_id] = (payload, err)

            next_unresolved: list[int] = []
            for row_id in unresolved:
                state = states[row_id]
                state["cloud_attempts"] += 1
                escalated_now += 1
                payload, err = results.get(row_id, (None, "missing_cloud_result"))
                if err is not None:
                    state["error_codes"].append(f"cloud_attempt_{cloud_round + 1}:{err}")
                    next_unresolved.append(row_id)
                    continue

                sentences, synonyms, notes, cleaned_existing = payload
                ok, updated, reasons, errors, skeletons = process_candidate(
                    row=rows[id_to_index[row_id]],
                    sentences=sentences,
                    generated_synonyms=synonyms,
                    cleaned_existing_synonyms=cleaned_existing,
                    notes=notes,
                    blocked_regexes=blocked_regexes,
                    near_dup_threshold=args.near_dup_threshold,
                    skeleton_counter=skeleton_counter,
                    skeleton_cap=args.global_skeleton_cap,
                )
                if not ok:
                    state["error_codes"].extend(f"cloud_attempt_{cloud_round + 1}:{code}" for code in errors)
                    next_unresolved.append(row_id)
                    continue

                state["accepted"] = True
                state["changed"] = True
                state["candidate"] = updated
                state["candidate_payload"] = (reasons, errors, skeletons)

            unresolved = next_unresolved

        # Commit batch in stable row order.
        for row_id in batch_ids:
            state = states[row_id]
            original_row = rows[id_to_index[row_id]]

            if state["accepted"] and isinstance(state["candidate"], dict):
                reasons, errors, skeletons = state["candidate_payload"]
                rows[id_to_index[row_id]] = state["candidate"]
                for skeleton in skeletons:
                    skeleton_counter[skeleton] += 1

                record = make_checkpoint_record(
                    row_id=row_id,
                    status="changed",
                    attempts_local=state["local_attempts"],
                    attempts_cloud=state["cloud_attempts"],
                    changed=True,
                    reason_codes=reasons,
                    error_codes=errors,
                )
                changed_now += 1
            else:
                # Keep row unchanged on hard failure.
                rows[id_to_index[row_id]] = original_row
                record = make_checkpoint_record(
                    row_id=row_id,
                    status="unchanged_failed_generation",
                    attempts_local=state["local_attempts"],
                    attempts_cloud=state["cloud_attempts"],
                    changed=False,
                    reason_codes=["keep_existing_after_attempt_budget"],
                    error_codes=state["error_codes"],
                )

            append_checkpoint(checkpoint, record)
            checkpoint_records[row_id] = record
            processed_ids.add(row_id)
            processed_now += 1

        now = time.perf_counter()
        should_print_progress = (
            processed_now > 0
            and (
                processed_now % args.chunk_size == 0
                or (now - last_progress_at) >= max(1, args.progress_interval_s)
            )
        )
        if should_print_progress:
            write_json(partial_seed, rows)
            elapsed = now - start
            rate = processed_now / elapsed if elapsed > 0 else 0.0
            remaining = max(0, len(pending_ids) - processed_now)
            eta = (remaining / rate) if rate > 0 else float("inf")
            eta_text = f"{eta:.1f}s" if eta != float("inf") else "inf"
            print(
                f"Progress: processed={processed_now}/{len(pending_ids)} "
                f"changed={changed_now} escalations={escalated_now} rate={rate:.2f}/s eta={eta_text}",
                flush=True,
            )
            last_progress_at = now

    full_completion = len(processed_ids.intersection(set(id_to_index.keys()))) == len(id_to_index)

    # Persist current working snapshot regardless of completion.
    write_json(partial_seed, rows)

    if not full_completion:
        write_json(output_seed, rows)
        print("Partial run completed (limit or resume subset).")
        print(f"processed_now={processed_now} changed_now={changed_now} escalations={escalated_now}")
        print(f"partial_seed={partial_seed}")
        print(f"checkpoint={checkpoint}")
        return 0

    # Full completion gates + resequence + roots remap.
    ok_rows_pre, row_errors_pre = audit_rows(
        rows=rows,
        blocked_regexes=blocked_regexes,
        near_dup_threshold=args.near_dup_threshold,
        skeleton_cap=args.global_skeleton_cap,
    )
    if not ok_rows_pre:
        write_json(output_seed, rows)
        print("Row audit failed before resequence.", file=sys.stderr)
        for token in row_errors_pre[:30]:
            print(f"- {token}", file=sys.stderr)
        return 2

    resequenced_rows, id_map = resequence_rows(rows)
    remapped_roots = remap_roots_word_ids(roots_payload, id_map)

    ok_rows, row_errors = audit_rows(
        rows=resequenced_rows,
        blocked_regexes=blocked_regexes,
        near_dup_threshold=args.near_dup_threshold,
        skeleton_cap=args.global_skeleton_cap,
    )
    ok_roots, root_errors = audit_roots(remapped_roots, resequenced_rows)

    if not ok_rows or not ok_roots:
        write_json(output_seed, resequenced_rows)
        write_json(output_roots, remapped_roots)
        print("Final audits failed; staged outputs written but canonical not promoted.", file=sys.stderr)
        for token in (row_errors + root_errors)[:40]:
            print(f"- {token}", file=sys.stderr)
        return 3

    write_json(output_seed, resequenced_rows)
    write_json(output_roots, remapped_roots)

    if args.apply:
        if args.backup:
            seed_backup, roots_backup = build_backup_paths(args.input_seed, args.input_roots)
            shutil.copy2(args.input_seed, seed_backup)
            shutil.copy2(args.input_roots, roots_backup)
            print(f"Backup created: {seed_backup}")
            print(f"Backup created: {roots_backup}")

        os.replace(output_seed, args.input_seed)
        os.replace(output_roots, args.input_roots)

    # cleanup partial snapshot after successful full completion
    try:
        partial_seed.unlink(missing_ok=True)
    except Exception:
        pass

    elapsed = time.perf_counter() - start
    print("Run report")
    print(f"processed_now={processed_now}")
    print(f"changed_now={changed_now}")
    print(f"escalations={escalated_now}")
    print(f"runtime_seconds={elapsed:.2f}")
    print(f"checkpoint={checkpoint}")
    print(f"exclusion_report={exclusion_report}")
    if args.apply:
        print(f"canonical_seed={args.input_seed}")
        print(f"canonical_roots={args.input_roots}")
    else:
        print(f"staged_seed={output_seed}")
        print(f"staged_roots={output_roots}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
