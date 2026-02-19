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

## Outputs

Default outputs are written alongside input seed data:

- `seed_data_updated.json`
- `checkpoint.jsonl`
- `seed_data_updated.partial.json` (during chunked processing)

At full completion, final validation runs and the partial snapshot is removed.
