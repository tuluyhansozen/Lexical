# Seed Sentence Improvement Pipeline

This repository now includes an LLM-assisted, resume-safe sentence improvement workflow for:

- `/Users/tuluyhan/projects/Lexical/Lexical/Resources/Seeds/seed_data.json`

## Prerequisites (Local Ollama)

```bash
brew install ollama
ollama serve
ollama pull qwen2.5:14b
curl -s http://127.0.0.1:11434/api/tags
```

## Dry Run (20-item smoke test)

```bash
python3 /Users/tuluyhan/projects/Lexical/improve_sentences_inplace.py --limit 20
```

## Resume Full Processing

```bash
python3 /Users/tuluyhan/projects/Lexical/improve_sentences_inplace.py
```

## Turbo Deterministic Mode (Fastest)

Turbo mode skips per-item LLM generation and uses deterministic rewrites, then runs sampled QA review with `qwen2.5:14b`.

```bash
python3 /Users/tuluyhan/projects/Lexical/improve_sentences_inplace.py \
  --mode turbo_deterministic \
  --qa-sample-rate 0.02 \
  --qa-model qwen2.5:14b \
  --qa-fail-threshold 0.05
```

Benchmark command (200 items):

```bash
python3 /Users/tuluyhan/projects/Lexical/improve_sentences_inplace.py \
  --mode turbo_deterministic \
  --limit 200
```

Fallback controls:

- `--fallback-stop-pct` default `5.0`: stop run early for diagnosis if fallback usage exceeds this rate
- `--fallback-max-pct` default `10.0`: hard-fail final run if fallback usage exceeds this ceiling
- `--strip-sentences-old-final` default `true`: remove `sentences_old` only after final full-dataset verification

The script is resume-safe:

- Uses checkpoint file: `checkpoint.jsonl`
- Uses partial snapshot: `seed_data_updated.partial.json`
- On resume, it loads partial snapshot first, then output snapshot fallback

## What checkpoint fields mean

Each line in `checkpoint.jsonl` contains:

- `changed`: `true` if at least one sentence text changed for that item
- `kept`: final sentences that remained text-identical to their originals
- `rewritten`: index-level before/after entries with rewrite reasons
- `errors`: validation, review, generation, or fallback notes observed while processing
- `metrics`: counts and flags (`rewritten_count`, `fallback_count`, `review_error`, optional QA flags)

## Outputs

Default outputs are written alongside input seed data:

- `seed_data_updated.json`
- `checkpoint.jsonl`
- `seed_data_updated.partial.json` (during chunked processing)

At full completion, final validation runs and the partial snapshot is removed.

## Stochastic Full Refactor (Lemma-Specific, Non-Deterministic)

This repository also includes a full non-deterministic refactor pipeline:

- `/Users/tuluyhan/projects/Lexical/improve_seed_stochastic.py`

Design highlights:

- full rewrite of sentence sets (3 per lemma) with local Ollama generation
- conservative synonym cleanup/regeneration
- no separate LLM reranker/review stage
- local-first retries (`2`) then Gemini CLI escalation (`1`) on failures
- sensitive lemma exclusion, ID resequencing, and `roots.json` remap
- automated gates before canonical replacement

Prerequisite for cloud escalation:

```bash
gemini --help
```

Example smoke run (limited subset, no canonical apply):

```bash
python3 /Users/tuluyhan/projects/Lexical/improve_seed_stochastic.py \
  --limit 50 \
  --apply false
```

Example full run (with atomic canonical apply and backup):

```bash
python3 /Users/tuluyhan/projects/Lexical/improve_seed_stochastic.py \
  --workers 2 \
  --cloud-workers 1 \
  --local-retries 2 \
  --cloud-retries 1 \
  --global-skeleton-cap 24 \
  --apply true \
  --backup true
```

If local Ollama generation is too slow on your machine, use a cloud-heavy profile
that keeps the same validation gates and resume/checkpoint behavior:

```bash
python3 /Users/tuluyhan/projects/Lexical/improve_seed_stochastic.py \
  --workers 1 \
  --local-retries 0 \
  --cloud-retries 1 \
  --cloud-workers 12 \
  --cloud-timeout-s 90 \
  --batch-size 24 \
  --chunk-size 50 \
  --gemini-invoke-mode auto \
  --apply true \
  --backup true
```

Observed benchmark in this repo context:

- `--limit 50` with cloud-heavy profile: ~`0.32 items/sec` (about 3.1s/item)
- practical full-run ETA: roughly `4.5-6 hours` depending on failure/escalation mix

Useful tuning flags for throughput:

- `--local-timeout-s`, `--local-num-predict`, `--local-keep-alive`
- `--cloud-timeout-s`, `--gemini-invoke-mode` (`auto|prompt|positional`)
- `--batch-size`, `--workers`, `--cloud-workers`
- `--progress-interval-s`

Key outputs:

- staged seed: `seed_data_refined.json` (or custom `--output-seed`)
- staged roots: `roots_refined.json` (or custom `--output-roots`)
- checkpoint: `stochastic_checkpoint.jsonl`
- exclusion report: `sensitive_exclusions.report.json`
- partial snapshot during resume-safe processing: `seed_data_refined.partial.json`

Stochastic checkpoint fields:

- `id`
- `status` (`changed`, `unchanged_failed_generation`, `excluded_sensitive`, etc.)
- `attempts_local`
- `attempts_cloud`
- `changed`
- `reason_codes`
- `error_codes`

## Project Verification (Simulator-first)

For app/runtime verification, use simulator-backed `xcodebuild` commands:

```bash
xcodebuild -scheme Lexical-Package \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -derivedDataPath /Users/tuluyhan/projects/Lexical/build/derived_data \
  test
```

```bash
xcodebuild -scheme Lexical \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -derivedDataPath /Users/tuluyhan/projects/Lexical/build/derived_data \
  build
```

`swift test` is not the authoritative path for this project’s SwiftData-backed app verification; prefer simulator `xcodebuild` commands.
