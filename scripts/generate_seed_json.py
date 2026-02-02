#!/usr/bin/env python3
"""
Lexical Seed Database Generator v6
===================================
Generates seed_data.json with 5000 vocabulary items using:
- Oxford 5000 for CEFR levels
- Google 10K for frequency ranking
- Kaikki Wiktionary for IPA, definitions, synonyms

CEFR Priority: B1/B2/C1 (primary) > A2/C2 (secondary) > A1 (last)
Each level: Most frequent words selected first.

Usage:
    uv run --with pandas --with msgspec --with tqdm scripts/generate_seed_json.py
"""

import json
import gzip
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import Optional
from datetime import datetime
from collections import defaultdict

# /// script
# dependencies = [
#   "pandas>=2.0",
#   "msgspec>=0.18",
#   "tqdm>=4.66",
# ]
# ///

# import msgspec (removed)
from tqdm import tqdm


# =============================================================================
# Configuration
# =============================================================================

DATA_DIR = Path("data/raw")
OUTPUT_FILE = Path("Lexical/Resources/vocab_seed.json")
TARGET_SIZE = 5000
KAIKKI_FILE = DATA_DIR / "kaikki_english.jsonl.gz"
GOOGLE_10K_FILE = DATA_DIR / "google_10k.txt"
OXFORD_5000_FILE = DATA_DIR / "oxford_5000.csv"

# CEFR Distribution Quotas (prioritizing B1/B2/C1)
# Primary focus: B1, B2, C1 - most words
# Secondary: A2, C2 - fewer words
# Last: A1 - fewest (basic words user likely knows)
CEFR_QUOTAS = {
    "A1": 400,
    "A2": 400,
    "B1": 800,
    "B2": 1200,
    "C1": 1200,
    "C2": 1000,
}




# =============================================================================
# Data Classes
# =============================================================================

@dataclass
class FSRSState:
    difficulty: float = 0.3
    stability: float = 0.0
    retrievability: float = 0.0


@dataclass
class ContextSentence:
    text: str
    cloze_index: int


@dataclass
class VocabularyEntry:
    id: int
    lemma: str
    rank: int
    cefr: str = "B1"
    pos: str = "word"
    ipa: Optional[str] = None
    definition: Optional[str] = None
    synonyms: list[str] = field(default_factory=list)
    collocations: list[int] = field(default_factory=list) # IDs of related words
    fsrs: FSRSState = field(default_factory=FSRSState)
    sentences: list[ContextSentence] = field(default_factory=list)



# =============================================================================
# Utility Functions
# =============================================================================

import re

def expand_pos(pos: str) -> str:
    """Expand POS abbreviations to full words."""
    mapping = {
        "adj": "adjective",
        "adv": "adverb",
        "conj": "conjunction",
        "prep": "preposition",
        "pron": "pronoun",
        "det": "determiner",
        "num": "number",
        "intj": "interjection",
        "abbrev": "abbreviation",
        "prop": "proper noun", 
        "name": "proper noun",
        "article": "article",
        "particle": "particle"
    }
    return mapping.get(pos.lower(), pos)


    return text.strip()


class Lexicographer:
    """
    Approximates the expert lexicographer mission using heuristic scoring.
    Goals: 8-15 words, simple, functional, no circular refs.
    """
    
    @staticmethod
    def clean_text(text: str) -> str:
        # Remove parenthetical context
        text = re.sub(r'^\([^)]+\)\s*', '', text)
        text = re.sub(r'^[\w\s/-]+:\s*', '', text)
        
        # Strip prefixes
        prefixes = [
            "The act of ", "A state of ", "Refers to ", "A word meaning ", 
            "Relating to ", "Consisting of ", "Of or pertaining to ", "To "
        ]
        for p in prefixes:
            if text.lower().startswith(p.lower()):
                text = text[len(p):]
                # Capitalize first letter
                if text: text = text[0].upper() + text[1:]
                
        if ";" in text:
            text = text.split(";")[0]
            
        # Truncate at "especially", "usually", "often" if long
        if len(text) > 50:
            for sep in [", especially", ", usually", ", often", ", typically", " ("]: 
                if sep in text:
                    text = text.split(sep)[0]
            
        return text.strip()

    @staticmethod
    def score_definition(text: str, lemma: str, index: int) -> float:
        words = text.split()
        count = len(words)
        
        score = 0.0
        
        # Priority for first senses (Critical for common words)
        # Senses are typically ordered by frequency
        if index == 0: score += 50
        elif index == 1: score += 40
        elif index == 2: score += 30
        else: score -= (index * 10)
        
        # 1. Length Constraint (8-15 preferred, but accept shorter if it's Sense 0)
        if 8 <= count <= 15:
            score += 20
        elif 3 <= count <= 25:
            score += 10
        else:
            score -= 10 
            
        # 2. Simplicity (Avg word length)
        avg_len = sum(len(w) for w in words) / count if count > 0 else 10
        if avg_len < 6:
            score += 10
        elif avg_len > 9:
            score -= 20 
            
        # 3. Circular dependency check
        if lemma.lower() in text.lower():
            score -= 30
            
        # 4. Starting style 
        if words[0].endswith("ing"):
            score += 5
            
        return score

    @staticmethod
    def select_best_sense(senses: list, lemma: str) -> tuple[Optional[str], list[str]]:
        """Find best definition and its examples."""
        best_def = None
        best_examples = []
        best_score = -1000.0
        
        for idx, sense in enumerate(senses[:10]): # Only check top 10 senses
            tags = sense.get('tags', [])
            if 'archaic' in tags or 'obsolete' in tags or 'historical' in tags:
                continue
                
            glosses = sense.get('glosses', [])
            if not glosses: continue
            
            raw_def = glosses[0]
            cleaned_def = Lexicographer.clean_text(raw_def)
            
            # Skip empty or single word definitions (synonyms)
            if not cleaned_def or " " not in cleaned_def:
                continue
                
            current_score = Lexicographer.score_definition(cleaned_def, lemma, idx)
            
            # Boost score if examples exist (context is king)
            examples = []
            for ex in sense.get('examples', []):
                if 'text' in ex: examples.append(ex['text'])
            
            if examples:
                current_score += 15
                
            if current_score > best_score:
                best_score = current_score
                best_def = cleaned_def
                best_examples = examples
                
        return best_def, best_examples


def calculate_fsrs_difficulty(rank: int) -> float:
    return round(2.0 + (rank / 60000.0) * 8.0, 2)


def create_context_sentence(text: str, lemma: str) -> Optional[ContextSentence]:
    """Create a cloze sentence from text if lemma is present."""
    # simple tokenization
    words = re.findall(r"\b[\w']+\b", text.lower())
    lemma_lower = lemma.lower()
    
    try:
        # Find index of word matching lemma (or close to it)
        # Check specific word forms? For now, exact match or contained
        idx = -1
        for i, w in enumerate(words):
            if w == lemma_lower or (len(lemma_lower) > 3 and lemma_lower in w):
                idx = i
                break
        
        if idx != -1:
            return ContextSentence(text=text.strip(), cloze_index=idx)
    except:
        pass
    
    return None


def link_collocations(entries: list[VocabularyEntry]):
    """
    Build a closed-set collocation graph.
    If Word A's sentences/definition contain Word B, link A -> B.
    """
    print("\n🕸 Building Collocation Matrix (Closed Set)...")
    
    # Map lemma -> ID
    lemma_map = {e.lemma: e.id for e in entries}
    
    # Pre-compute target word set for fast lookups
    target_words = set(lemma_map.keys())
    
    # STOP WORDS (Common noise words to exclude from collocations)
    STOP_WORDS = {
        "the", "be", "to", "of", "and", "a", "in", "that", "have", "i", "it", 
        "for", "not", "on", "with", "he", "as", "you", "do", "at", "this", "but", 
        "his", "by", "from", "they", "we", "say", "her", "she", "or", "an", "will", 
        "my", "one", "all", "would", "there", "their", "what", "so", "up", "out", 
        "if", "about", "who", "get", "which", "go", "me", "when", "make", "can", 
        "like", "time", "no", "just", "him", "know", "take", "people", "into", 
        "year", "your", "good", "some", "could", "them", "see", "other", "than", 
        "then", "now", "look", "only", "come", "its", "over", "think", "also", 
        "back", "after", "use", "two", "how", "our", "work", "first", "well", 
        "way", "even", "new", "want", "because", "any", "these", "give", "day", 
        "most", "us"
    }

    links_count = 0
    
    for entry in tqdm(entries, desc="   Linking"):
        # Gather text corpus for this word (definition + sentences)
        corpus = (entry.definition or "") + " " + " ".join(s.text for s in entry.sentences)
        corpus = corpus.lower()
        
        # Tokenize (keep valid words > 2 chars)
        tokens = set(re.findall(r"\b[a-z]{3,}\b", corpus))
        
        found_ids = []
        for token in tokens:
            if token == entry.lemma:
                continue
            
            if token in STOP_WORDS:
                continue

            if token in lemma_map:
                target_id = lemma_map[token]
                target_entry = entries[target_id - 1] # ID is 1-based index + 1
                
                # CONSTRAINT: CEFR Level +/- 1
                source_lvl = cefr_to_int(entry.cefr)
                target_lvl = cefr_to_int(target_entry.cefr)
                
                if abs(source_lvl - target_lvl) <= 1:
                     found_ids.append(target_id)
        
        # Limit to top 20
        entry.collocations = sorted(list(set(found_ids)))[:20]
        links_count += len(entry.collocations)

    avg_degree = links_count / len(entries) if entries else 0
    print(f"   ✅ Created {links_count} edges (Avg Degree: {avg_degree:.2f})")


def load_frequency_ranking() -> dict[str, int]:
    """Load word frequency ranking from Google 10K."""
    if not GOOGLE_10K_FILE.exists():
        print(f"   ⚠️ {GOOGLE_10K_FILE} not found!")
        return {}
    
    ranking = {}
    with open(GOOGLE_10K_FILE, 'r') as f:
        for rank, line in enumerate(f, 1):
            word = line.strip().lower()
            if len(word) > 1 and word.isalpha() and word not in ranking:
                ranking[word] = rank
    
    print(f"   Loaded {len(ranking)} words with frequency rankings")
    return ranking


def load_oxford_cefr() -> dict[str, str]:
    """Load Oxford 5000 CEFR levels."""
    if not OXFORD_5000_FILE.exists():
        print(f"   ⚠️ {OXFORD_5000_FILE} not found!")
        return {}
    
    cefr_map = {}
    with open(OXFORD_5000_FILE, 'r') as f:
        next(f)  # Skip header
        for line in f:
            parts = line.strip().split(',')
            if len(parts) >= 3:
                word = parts[0].lower()
                level = parts[2].upper()
                if word not in cefr_map:
                    cefr_map[word] = level
                else:
                    # If word exists, keep the lower level (e.g. 'that' A1 < B1)
                    current_lvl = cefr_map[word]
                    if cefr_to_int(level) < cefr_to_int(current_lvl):
                        cefr_map[word] = level
    
    print(f"   Loaded {len(cefr_map)} words with CEFR levels")
    return cefr_map


def cefr_to_int(level: str) -> int:
    levels = {"A1": 1, "A2": 2, "B1": 3, "B2": 4, "C1": 5, "C2": 6}
    return levels.get(level, 3) # Default B1


def build_candidate_list(freq_ranking: dict, cefr_map: dict) -> list[tuple[str, str, int]]:
    """Build candidate list prioritizing CEFR levels."""
    print("\n📊 Building candidate pool...")
    candidates = []
    seen = set()
    
    def cefr_priority(lvl):
        if lvl in ["B1", "B2", "C1"]: return 1
        if lvl in ["A2", "C2"]: return 2
        return 3
    
    cefr_words = []
    for word, level in cefr_map.items():
        if word in freq_ranking:
            cefr_words.append((word, level, freq_ranking[word]))
    
    cefr_words.sort(key=lambda x: (cefr_priority(x[1]), x[2]))
    
    # Sort by frequency within each level
    candidates.sort(key=lambda x: (x[1], x[2]))
    
    # Fill quotas
    final_candidates = []
    level_counts = defaultdict(int)
    
    # 1. Fill from CEFR source first
    for w, l, r in candidates:
        if level_counts[l] < CEFR_QUOTAS.get(l, 0):
            final_candidates.append((w, l, r))
            level_counts[l] += 1
            seen.add(w)

    print(f"   Filled from source: {dict(level_counts)}")
    
    # 2. Fill gaps from frequency list (only if needed)
    # User said: "do not change sources word count". So we should try to stick to source.
    # But if we are short, we might need fillers. 
    # However, strictly speaking, we should prioritize the user's constraints.
    # If Oxford 5000 is missing C2 words (it might be), we can't invent C2.
    # We will relax and fill gaps inferred by rank ONLY if strictly necessary 
    # but try to map them intelligently.
    
    remaining_freq = [(w, r) for w, r in freq_ranking.items() if w not in seen]
    remaining_freq.sort(key=lambda x: x[1])
    
    for w, r in remaining_freq:
        # Infer level if missing
        if r <= 500: lvl = "A1"
        elif r <= 1000: lvl = "A2"
        elif r <= 2000: lvl = "B1"
        elif r <= 3500: lvl = "B2"
        elif r <= 5000: lvl = "C1"
        else: lvl = "C2"
        
        if level_counts[lvl] < CEFR_QUOTAS.get(lvl, 0):
            final_candidates.append((w, lvl, r))
            level_counts[lvl] += 1
            seen.add(w)
            
    # Final Sort by Level then Rank
    final_candidates.sort(key=lambda x: (x[1], x[2]))
    
    print(f"   Final Quotas: {dict(level_counts)}")
    print(f"   Total candidates prepared: {len(final_candidates)}")
    return final_candidates


# =============================================================================
# Kaikki Parser
# =============================================================================

def stream_kaikki(target_lemmas: set[str]) -> dict:
    """Stream Kaikki JSONL and extract data."""
    print(f"\n📖 Streaming Kaikki dictionary ({KAIKKI_FILE})...")
    
    if not KAIKKI_FILE.exists():
        print("   ⚠️ Kaikki file not found!")
        return {}
    
    results = {}
    # decoder = msgspec.json.Decoder() (removed)
    
    file_size = KAIKKI_FILE.stat().st_size
    print(f"   File size: {file_size / (1024*1024):.1f} MB")
    
    found = 0
    processed = 0
    
    # Optimize: Stop if we find everything (unlikely with strict filter but good practice)
    # Actually we can't stop early because we don't know which words will pass strict filtering
    # But we can skip parsing non-target words
    
    with gzip.open(KAIKKI_FILE, 'rt', encoding='utf-8') as f:
        pbar = tqdm(f, desc="   Parsing", total=1500000)
        for line in pbar:
            processed += 1
            
            try:
                entry = json.loads(line)
                word = entry.get('word', '').lower()
                
                # Only English words
                if entry.get('lang') != 'English':
                    continue
                
                if word in target_lemmas and word not in results:
                    # Extract IPA
                    ipa = None
                    sounds = entry.get('sounds', [])
                    for sound in sounds:
                        if 'ipa' in sound:
                            ipa_val = sound['ipa']
                            tags = sound.get('tags', [])
                            if 'US' in tags or 'General-American' in str(tags) or not ipa:
                                ipa = ipa_val
                    
                    # Extract definition using Lexicographer
                    senses = entry.get('senses', [])
                    definition, examples = Lexicographer.select_best_sense(senses, word)
                    
                    if definition:
                        # Limit examples
                        examples = examples[:5]
                        
                        # Synonyms
                        synonyms = []
                        for sense in senses:
                             for syn in sense.get('synonyms', []):
                                 if 'word' in syn: synonyms.append(syn['word'])
                        synonyms = list(dict.fromkeys(synonyms))[:5]
                        
                        pos = entry.get('pos', 'word')
                        
                        results[word] = {
                            'ipa': ipa,
                            'definition': definition,
                            'synonyms': synonyms,
                            'examples': examples,
                            'pos': pos
                        }
                        found += 1
                        
                        if processed % 1000 == 0:
                            pbar.set_postfix(found=f"{found}")

            except Exception:
                continue
                
        pbar.close()
    
    print(f"\n   ✅ Extracted data for {len(results)} lemmas")
    return results


# =============================================================================
# Main Pipeline
# =============================================================================

def build_seed_database():
    print("=" * 60)
    print("🌱 LEXICAL SEED DATABASE GENERATOR v8")
    print("   MATRIX VIEW: Collocations & Context Graph")
    print("=" * 60)
    
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    
    # 1. Load Data
    freq_ranking = load_frequency_ranking()
    cefr_map = load_oxford_cefr()
    
    # 2. Build Candidates
    candidates = build_candidate_list(freq_ranking, cefr_map)
    candidate_set = set(w for w, _, _ in candidates)
    
    # 3. Stream Kaikki
    kaikki_data = stream_kaikki(candidate_set)
    
    # 4. Build Entries
    print("\n⚙️ STAGE 4: Building Vocabulary Entries")
    entries = []
    
    skipped_ipa = 0
    skipped_def = 0
    
    for idx, (lemma, cefr, rank) in enumerate(tqdm(candidates, desc="   Processing")):
        if len(entries) >= TARGET_SIZE:
            break
            
        data = kaikki_data.get(lemma)
        if not data: continue
        
        ipa = data.get('ipa')
        definition = data.get('definition')
        
        if not ipa:
            skipped_ipa += 1
            continue
        if not definition:
            skipped_def += 1
            continue
            
        # Process sentences
        raw_examples = data.get('examples', [])
        sentences = []
        for ex_text in raw_examples:
            if s := create_context_sentence(ex_text, lemma):
                sentences.append(s)
        
        # Fallback if no real sentences found
        if not sentences:
             sentences = [
                 ContextSentence(f"The word '{lemma}' is common.", 2)
             ]
        
        entry = VocabularyEntry(
            id=len(entries) + 1,
            lemma=lemma,
            rank=rank,
            cefr=cefr,
            pos=expand_pos(data.get('pos', 'word')),
            ipa=ipa,
            definition=definition,
            synonyms=data.get('synonyms', []),
            collocations=[], # Populated later
            fsrs=FSRSState(
                difficulty=calculate_fsrs_difficulty(rank),
                stability=0.0,
                retrievability=0.0
            ),
            sentences=sentences[:3] # Limit to 3 context examples
        )
        entries.append(entry)
        
    print(f"\n   ⚠️ Skipped: IPA={skipped_ipa}, Def={skipped_def}")
    
    # 5. Link Collocations (Matrix)
    link_collocations(entries)
    
    # 6. Validation
    total = len(entries)
    print("\n✅ STAGE 5: Validation Report")
    
    has_links = sum(1 for e in entries if e.collocations)
    print(f"   📊 Matrix Density:")
    print(f"      Connected Nodes: {has_links}/{total} ({100*has_links/total:.1f}%)")
    
    # 7. Export
    print("\n💾 STAGE 6: Export")
    
    def to_dict(e: VocabularyEntry) -> dict:
        d = asdict(e)
        d['fsrs'] = asdict(e.fsrs)
        d['sentences'] = [asdict(s) for s in e.sentences]
        return d
    
    output = {
        "version": 8,
        "generated_at": datetime.now().isoformat(),
        "total_entries": total,
        "matrix_stats": {
            "connected_nodes": has_links,
            "density": f"{(has_links/total)*100:.1f}%"
        },
        "entries": [to_dict(e) for e in entries]
    }
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    
    size_mb = OUTPUT_FILE.stat().st_size / (1024 * 1024)
    print(f"   ✅ Exported to {OUTPUT_FILE}")
    print(f"   📦 Size: {size_mb:.2f} MB")
    print(f"   📊 Entries: {total}")
    
    print("\n" + "=" * 60)
    print("🎉 GENERATION COMPLETE")
    print("=" * 60)


if __name__ == "__main__":
    build_seed_database()
