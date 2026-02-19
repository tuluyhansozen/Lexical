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
