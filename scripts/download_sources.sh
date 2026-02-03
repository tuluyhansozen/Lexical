#!/bin/bash

# scripts/download_sources.sh
# Lexical Seed Database Source Downloader

DATA_DIR="data/raw"
mkdir -p "$DATA_DIR"

echo "📥 Starting Download Sequence..."

# 1. Frequency List (Google 10k - Fallback for COCA)
if [ ! -f "$DATA_DIR/google_10k.txt" ]; then
    echo "⬇️ Downloading Google 10k Frequency Data..."
    curl -L -o "$DATA_DIR/google_10k.txt" "https://raw.githubusercontent.com/first20hours/google-10000-english/master/google-10000-english-no-swears.txt"
else
    echo "✅ Google 10k already exists."
fi

# 2. Kaikki Dictionary (The Flesh)
if [ ! -f "$DATA_DIR/kaikki_english.jsonl.gz" ]; then
    echo "⬇️ Downloading Kaikki English Dictionary (~430MB)..."
    curl -L -o "$DATA_DIR/kaikki_english.jsonl.gz" "https://kaikki.org/dictionary/English/kaikki.org-dictionary-English.jsonl.gz"
else
    echo "✅ Kaikki dictionary already exists."
fi

# 3. Tatoeba Sentences (Context Injection)
if [ ! -f "$DATA_DIR/sentences_detailed.tar.bz2" ]; then
    echo "⬇️ Downloading Tatoeba Sentences (~150MB)..."
    curl -L -o "$DATA_DIR/sentences_detailed.tar.bz2" "https://downloads.tatoeba.org/exports/sentences_detailed.tar.bz2"
else
    echo "✅ Tatoeba Sentences already exists."
fi

# 4. Oxford 5000 (Placeholder/Mock)
# Since we don't have a direct link to the copyrighted Oxford list, we will assume it exists or use a placeholder if missing.
if [ ! -f "$DATA_DIR/oxford_5000.csv" ]; then
    echo "⚠️ Oxford 5000 CSV missing. Please place 'oxford_5000.csv' in $DATA_DIR manually."
    # We won't download a fake one to avoid overwriting user's potential data, 
    # but we can create a dummy if absolutely needed.
fi

echo "🎉 Download sequence complete."
