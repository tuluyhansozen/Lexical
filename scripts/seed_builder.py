#!/usr/bin/env python3
"""
Lexical Seed Database Builder v1.0.0 (StdLib Edition)
=====================================================
Implements the 5-Stage ETL Pipeline for the Lexical iOS App.
Zero-dependency version (runs on standard Python 3).

1. Master Pool Generation (Oxford + Roots)
2. Metadata Enrichment (Kaikki)
3. FSRS Initialization (Cold Start)
4. Context Injection (Tatoeba)
5. Output Generation (SwiftData JSON)

Usage:
    python3 scripts/seed_builder.py
"""

import json
import gzip
import tarfile
import csv
import io
import re
import sys
import time
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import Optional, List, Dict, Set

# =============================================================================
# Configuration
# =============================================================================

DATA_DIR = Path("data/raw")
WORDLIST_DIR = DATA_DIR / "word_list"
OUTPUT_DIR = Path("Lexical/Resources/Seeds")
OUTPUT_FILE = OUTPUT_DIR / "seed_data.json"
ROOTS_OUTPUT_FILE = OUTPUT_DIR / "roots.json"

# Source Files
OXFORD_5000 = WORDLIST_DIR / "oxford_5000.csv"
GOOGLE_10K = DATA_DIR / "google_10k.txt"
NORVIG_1W_CANDIDATES = [Path("count_1w.txt"), DATA_DIR / "count_1w.txt"]
KAIKKI_FILE = DATA_DIR / "kaikki_english.jsonl.gz"
TATOEBA_FILE = DATA_DIR / "sentences_detailed.tar.bz2"
ROOTS_1 = Path("roots1.json")
ROOTS_2 = Path("roots2.json")

# Constants
TARGET_SIZE = 8000 # Flexible cap

# =============================================================================
# Data Structures
# =============================================================================

@dataclass
class FSRSState:
    d: float = 0.0
    s: float = 0.0
    r: float = 0.0

@dataclass
class ContextSentence:
    text: str
    cloze_index: int

@dataclass
class VocabularyEntry:
    id: int
    lemma: str
    rank: int
    cefr: str
    pos: str
    ipa: Optional[str] = None
    definition: Optional[str] = None
    fsrs_initial: FSRSState = field(default_factory=FSRSState)
    sentences: List[ContextSentence] = field(default_factory=list)

# =============================================================================
# Utils
# =============================================================================

def print_progress(current, total, prefix="Progress"):
    percent = (current / total) * 100
    bar_length = 30
    filled = int(bar_length * current // total)
    bar = '█' * filled + '-' * (bar_length - filled)
    sys.stdout.write(f'\r{prefix}: |{bar}| {percent:.1f}% ({current}/{total})')
    sys.stdout.flush()

# =============================================================================
# Stage 1: Master Pool Generation
# =============================================================================

def load_roots_lemmas() -> tuple[Set[str], List[dict]]:
    merged_roots = []
    root_lemmas = set()
    
    for path in [ROOTS_1, ROOTS_2]:
        if path.exists():
            print(f"   Loading {path}...")
            try:
                with open(path, 'r') as f:
                    data = json.load(f)
                    merged_roots.extend(data)
                    for root in data:
                        items = root.get('matrix_items') or root.get('matrix_words', [])
                        for item in items:
                            if 'lemma' in item:
                                root_lemmas.add(item['lemma'].lower().strip())
            except Exception as e:
                print(f"   ❌ Error loading {path}: {e}")
        else:
            print(f"   ⚠️ {path} missing!")

    # Re-assign IDs sequentially
    for i, root in enumerate(merged_roots, 1):
        root['root_id'] = i

    return root_lemmas, merged_roots

def load_frequency_ranking() -> Dict[str, int]:
    ranking = {}
    norvig_path = next((path for path in NORVIG_1W_CANDIDATES if path.exists()), None)
    if norvig_path is not None:
        with open(norvig_path, "r", encoding="utf-8") as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) < 2:
                    continue
                word = parts[0].lower()
                if word and word not in ranking:
                    ranking[word] = len(ranking) + 1
        print(f"   Loaded {len(ranking)} words from Norvig 1w ({norvig_path})")
        return ranking

    if GOOGLE_10K.exists():
        with open(GOOGLE_10K, "r", encoding="utf-8") as f:
            for rank, line in enumerate(f, 1):
                word = line.strip().lower()
                if word and word not in ranking:
                    ranking[word] = rank
        print(f"   Loaded {len(ranking)} words from Google 10K ({GOOGLE_10K})")
    else:
        print("   ⚠️ No frequency source found (Norvig/Google10K).")
    return ranking

def load_oxford_cefr() -> Dict[str, str]:
    cefr_map = {}
    paths = [OXFORD_5000, DATA_DIR / "oxford_5000.csv"]
    target_path = next((p for p in paths if p.exists()), None)
    
    if target_path:
        with open(target_path, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                word = row.get('word', '').lower().strip()
                cefr = row.get('cefr', '').upper()
                if word and cefr:
                     if word not in cefr_map:
                         cefr_map[word] = cefr
    else:
        print("   ⚠️ Oxford 5000 CSV not found.")
        
    return cefr_map

def load_awl() -> Set[str]:
    """Loads Academic Word List from converted text file."""
    awl_words = set()
    possible_paths = [Path("AWL.txt"), DATA_DIR / "word_list/AWL.txt"]
    path = next((p for p in possible_paths if p.exists()), None)
    
    if path:
        print(f"   Loading AWL from {path}...")
        try:
            with open(path, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if not line: continue
                    # heuristic: ignore headers
                    if "Sublist" in line or "This sublist" in line: continue
                    # assume words are single tokens, mostly
                    words = line.split()
                    if len(words) == 1 and words[0].isalpha():
                        awl_words.add(words[0].lower())
        except Exception as e:
            print(f"   ❌ Error reading AWL: {e}")
            
    else:
        print("   ⚠️ AWL.txt not found (Run textutil conversion for .doc).")
        
    return awl_words

def load_vocabso() -> Set[str]:
    """Loads Vocabso list from extracted text (Regex extraction)."""
    vocabso_words = set()
    path = DATA_DIR / "word_list/vocabso.txt"
    
    if path.exists():
        print(f"   Loading Vocabso from {path}...")
        try:
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
                # Extract TitleCase words (length > 2)
                # Filter out likely noise words later if needed
                candidates = re.findall(r'\b[A-Z][a-z]{2,}\b', content)
                
                # Filter out obvious non-vocab (Months, Days if strictly academic?)
                # Actually, just taking them all is saftest.
                for w in candidates:
                    vocabso_words.add(w.lower())
        except Exception as e:
             print(f"   ❌ Error reading Vocabso: {e}")
    else:
        print("   ⚠️ Vocabso text not found.")
        
    return vocabso_words

def generate_master_pool() -> tuple[List[VocabularyEntry], List[dict]]:
    print("\n🏊 STAGE 1: Master Pool Generation")
    
    cefr_map = load_oxford_cefr()
    ranking = load_frequency_ranking()
    root_lemmas, merged_roots = load_roots_lemmas()
    awl_words = load_awl()
    vocabso_words = load_vocabso()
    
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    # roots.json writing deferred to Stage 5

    pool = {}
    
    # 1. Add Oxford Words
    for word, level in cefr_map.items():
        if word not in pool:
            pool[word] = {
                "lemma": word,
                "cefr": level,
                "rank": ranking.get(word, 60001),
                "source": "oxford"
            }
            
    # 2. Add Roots Lemmas
    for word in root_lemmas:
        if word in pool:
            pool[word]["source"] += "+root"
        else:
            pool[word] = {
                "lemma": word,
                "cefr": "B2",
                "rank": ranking.get(word, 60001),
                "source": "root"
            }

    # 3. Add AWL Words
    for word in awl_words:
        if word in pool:
            pool[word]["source"] += "+AWL"
        else:
            pool[word] = {
                "lemma": word,
                "cefr": "C1",
                "rank": ranking.get(word, 60001),
                "source": "AWL"
            }
            
    # 4. Add Vocabso Words
    for word in vocabso_words:
        if word in pool:
            pool[word]["source"] += "+Vocabso"
        else:
             pool[word] = {
                "lemma": word,
                "cefr": "C2", # Vocabso is likely GRE/Advanced
                "rank": ranking.get(word, 60001),
                "source": "Vocabso"
            }

    entries = []
    sorted_words = sorted(pool.values(), key=lambda x: x['rank'])
    
    for idx, item in enumerate(sorted_words, 1):
        entries.append(VocabularyEntry(
            id=idx,
            lemma=item['lemma'],
            rank=item['rank'],
            cefr=item['cefr'],
            pos="word"
        ))
        
    print(f"   ✅ Master Pool Size: {len(entries)}")
    return entries, merged_roots

# =============================================================================
# Stage 2: Metadata Enrichment (Kaikki)
# =============================================================================

def clean_definition(text: str, lemma: str) -> str:
    # Remove parens
    text = re.sub(r'^\([^)]+\)\s*', '', text)
    # Remove prefixes
    prefixes = ["The act of", "A state of", "Relating to", "Of or pertaining to"]
    for p in prefixes:
        if text.startswith(p + " "):
            text = text[len(p)+1:].strip()
            if text: text = text[0].upper() + text[1:]
            
    return text

def stage_enrichment(entries: List[VocabularyEntry]):
    print("\n💎 STAGE 2: Metadata Enrichment (Kaikki)")
    
    if not KAIKKI_FILE.exists():
        print("   ⚠️ Kaikki file missing. Skipping enrichment.")
        return

    lemma_map = {e.lemma: e for e in entries}
    needed = set(lemma_map.keys())
    
    found_count = 0
    start_time = time.time()
    
    # Estimate total lines (rough check)
    total_lines = 1000000 
    processed = 0
    
    with gzip.open(KAIKKI_FILE, 'rt', encoding='utf-8') as f:
        for line in f:
            processed += 1
            if processed % 5000 == 0:
                print_progress(processed, total_lines, prefix="   Scanning")
                
            try:
                data = json.loads(line)
                original_word = data.get('word', '')
                word = original_word.lower()
                
                if word in needed:
                    entry = lemma_map[word]
                    
                    # 1. POS
                    entry.pos = data.get('pos', 'word')
                    
                    # 2. IPA (US)
                    sounds = data.get('sounds', [])
                    if sounds:
                        for s in sounds:
                            if 'ipa' in s and 'tags' in s:
                                if 'US' in s['tags'] or 'American' in s['tags']:
                                    entry.ipa = s['ipa']
                                    break
                        if not entry.ipa:
                             for s in sounds:
                                 if 'ipa' in s:
                                     entry.ipa = s['ipa']
                                     break

                    # 3. Definition Candidates
                    best_def = None
                    
                    senses = data.get('senses', [])
                    for sense in senses:
                        glosses = sense.get('glosses', [])
                        if glosses:
                            raw_def = glosses[0]
                            examples = sense.get('examples', [])
                            for ex in examples:
                                text = ex.get('text', '')
                                tokens = re.findall(r'\b\w+\b', text.lower())
                            if not best_def:
                                best_def = clean_definition(raw_def, original_word)
                    
                    entry.definition = best_def
                    found_count += 1
                    
            except Exception:
                continue
    
    print() # Newline after progress
    print(f"   ✅ Enriched {found_count} entries.")

# =============================================================================
# Stage 3: FSRS Initialization
# =============================================================================

def stage_fsrs_init(entries: List[VocabularyEntry]):
    print("\n🧠 STAGE 3: FSRS Initialization (Cold Start)")
    for e in entries:
        r = min(e.rank, 60000)
        d = 2.0 + (r / 60000.0) * 8.0
        e.fsrs_initial = FSRSState(
            d=round(d, 2),
            s=0.0,
            r=0.0
        )

# =============================================================================
# Stage 4: Context Injection
# =============================================================================

def stage_context_injection(entries: List[VocabularyEntry]):
    print("\n💬 STAGE 4: Context Injection (Tatoeba)")
    if not TATOEBA_FILE.exists():
        print("   ⚠️ Tatoeba file missing.")
        return

    lemma_map = {e.lemma: e for e in entries}
    targets = set(lemma_map.keys())
    count = 0
    processed = 0
    
    with tarfile.open(TATOEBA_FILE, "r:bz2") as tar:
        member = next((m for m in tar.getmembers() if "sentences_detailed" in m.name), None)
        if member:
            f = tar.extractfile(member)
            wrapper = io.TextIOWrapper(f, encoding='utf-8')
            
            for line in wrapper:
                processed += 1
                if processed % 10000 == 0:
                     print_progress(processed, 5000000, prefix="   Scanning Sentences")
                
                try:
                    parts = line.split('\t')
                    if len(parts) >= 3 and parts[1] == 'eng':
                        text = parts[2]
                        words = text.split()
                        if 5 <= len(words) <= 15:
                            tokens = set(re.findall(r'\b[a-z]+\b', text.lower()))
                            common = tokens.intersection(targets)
                            
                            for word in common:
                                entry = lemma_map[word]
                                if len(entry.sentences) < 3:
                                    split_words = text.split()
                                    idx = -1
                                    for i, w in enumerate(split_words):
                                        if word in w.lower():
                                            idx = i
                                            break
                                    
                                    if idx != -1:
                                        entry.sentences.append(ContextSentence(text, idx))
                                        count += 1
                except:
                    continue
    print()
    print(f"   ✅ Injected {count} contexts.")

# =============================================================================
# Stage 5: Finalization & Output
# =============================================================================

def stage_output(entries: List[VocabularyEntry], roots: List[dict]):
    print("\n💾 STAGE 5: Generating SwiftData Formatting")
    
    lemma_to_id = {e.lemma: e.id for e in entries}
    
    # 1. Process Words
    # (Collocations removed per user request)
            
    # Serialize Words
    data = [asdict(e) for e in entries]
    
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"   ✅ Written {len(data)} entries to {OUTPUT_FILE}")

    # 2. Process Roots (Relational)
    final_roots = []
    for root in roots:
        # Extract IDs
        items = root.get('matrix_items') or root.get('matrix_words', [])
        word_ids = []
        for item in items:
            l = item.get('lemma', '').lower().strip()
            if l in lemma_to_id:
                word_ids.append(lemma_to_id[l])
        
        # Create normalized root object
        new_root = {
            "root_id": root['root_id'],
            "root": root['root'],
            "basic_meaning": root.get('basic_meaning', ''),
            "word_ids": sorted(list(set(word_ids))) # Dedupe and sort
        }
        final_roots.append(new_root)

    with open(ROOTS_OUTPUT_FILE, 'w') as f:
        json.dump(final_roots, f, indent=2)
    print(f"   ✅ Written {len(final_roots)} relational roots to {ROOTS_OUTPUT_FILE}")

# =============================================================================
# Main
# =============================================================================

def main():
    entries, roots = generate_master_pool()
    stage_enrichment(entries)
    stage_fsrs_init(entries)
    stage_context_injection(entries)
    stage_output(entries, roots)

if __name__ == "__main__":
    main()
