#!/bin/bash

# scripts/download_sources.sh
# Downloads and validates the raw datasets required for the seed database.

DATA_DIR="data/raw"
mkdir -p "$DATA_DIR/word_list"

echo "==========================================="
echo "📂 Lexical Seed Data: Source Manager"
echo "==========================================="

# 1. Frequency Data (Norvig preferred, Google 10K fallback)
if [ -f "count_1w.txt" ]; then
    echo "✅ [Found] Norvig 1w Frequency List (repo root count_1w.txt)"
elif [ -f "$DATA_DIR/count_1w.txt" ]; then
    echo "✅ [Found] Norvig 1w Frequency List ($DATA_DIR/count_1w.txt)"
elif [ -f "$DATA_DIR/google_10k.txt" ]; then
    echo "✅ [Found] Google 10K Frequency List (fallback)"
else
    echo "⚠️ [Missing] Frequency List"
    echo "   Preferred: count_1w.txt from https://norvig.com/ngrams/count_1w.txt"
    echo "   Fallback:  $DATA_DIR/google_10k.txt"
fi

# 2. Oxford Lists (CEFR)
if [ -f "$DATA_DIR/word_list/oxford_5000.csv" ]; then
    echo "✅ [Found] Oxford 5000 CSV"
elif [ -f "$DATA_DIR/oxford_5000.csv" ]; then
    echo "✅ [Found] Oxford 5000 CSV (in root raw dir)"
    mv "$DATA_DIR/oxford_5000.csv" "$DATA_DIR/word_list/oxford_5000.csv"
else
    echo "⚠️ [Missing] Oxford 5000 CSV"
    echo "   Action: Download from https://github.com/Berehulia/Oxford-3000-5000"
fi

# 3. Wiktionary (Kaikki)
KAIKKI_FILE="$DATA_DIR/kaikki_english.jsonl.gz"
KAIKKI_URL="https://kaikki.org/dictionary/English/kaikki.org-dictionary-English.jsonl.gz"

if [ -f "$KAIKKI_FILE" ]; then
    echo "✅ [Found] Kaikki Dictionary"
else
    echo "⬇️ [Downloading] Kaikki Dictionary (Large File)..."
    curl -L -o "$KAIKKI_FILE" "$KAIKKI_URL"
fi

# 4. Tatoeba Sentences
TATOEBA_FILE="$DATA_DIR/sentences_detailed.tar.bz2"
TATOEBA_URL="https://downloads.tatoeba.org/exports/sentences_detailed.tar.bz2"

if [ -f "$TATOEBA_FILE" ]; then
    echo "✅ [Found] Tatoeba Sentences"
else
    echo "⬇️ [Downloading] Tatoeba Sentences..."
    curl -L -o "$TATOEBA_FILE" "$TATOEBA_URL"
fi

# 5. Roots Data
if [ -f "roots1.json" ] && [ -f "roots2.json" ]; then
    echo "✅ [Found] Roots Data (roots1.json, roots2.json)"
else
    echo "⚠️ [Missing] Roots Data files in project root."
fi

echo "==========================================="
echo "🎉 Source check complete."
