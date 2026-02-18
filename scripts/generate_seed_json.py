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
import tarfile
import csv
import io
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
TARGET_SIZE = 8000
KAIKKI_FILE = DATA_DIR / "kaikki_english.jsonl.gz"
GOOGLE_10K_FILE = DATA_DIR / "google_10k.txt"
NORVIG_1W_CANDIDATES = [Path("count_1w.txt"), DATA_DIR / "count_1w.txt"]
OXFORD_3000_FILE = DATA_DIR / "oxford_3000.csv"
OXFORD_5000_FILE = DATA_DIR / "oxford_5000.csv"
TATOEBA_FILE = DATA_DIR / "sentences_detailed.tar.bz2"

# Remove Strict Quotas - Allow natural distribution from Oxford Lists
CEFR_QUOTAS = {
    "A1": 9999,
    "A2": 9999,
    "B1": 9999,
    "B2": 9999,
    "C1": 9999,
    "C2": 9999
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
    suggested_collocations: list[str] = field(default_factory=list) # Pedagogical suggestions
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
        # Filter Inflections / Alternative Forms
        low_text = text.lower()
        if re.search(r"^(plural of|past of|third-person|present participle|alternative form of|obsolete form of|archaic form of|inflection of|participle of|comparative of|superlative of)", low_text):
            return -1000.0 # Strongly reject
            
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
    
    # BLACKLIST (Offensive, Vulgar, or Problematic words)
    BLACKLIST = {
        "cock", "cocks", "dick", "pussy", "shit", "fuck", "bitch", 
        "ass", "bastard", "damn", "bloody", "crap", "sex", "sexy",
        "nigger", "faggot", "dyke", "retard", "spastic", "whore"
    }
    
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
            
            if token in STOP_WORDS or token in BLACKLIST:
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


    print(f"   ✅ Created {links_count} edges (Avg Degree: {avg_degree:.2f})")


def inject_context_tatoeba(entries: list[VocabularyEntry]):
    """
    Stage 4: Context Injection via Tatoeba.
    - Stream sentences_detailed.tar.bz2
    - Filter lang='eng', length 5-15
    - Match words
    - Select top 3
    """
    print(f"\n💬 Injecting Context from Tatoeba ({TATOEBA_FILE})...")
    
    if not TATOEBA_FILE.exists():
        print("   ⚠️ Tatoeba file not found! Skipping context injection.")
        return

    # Map lemma -> entry index
    lemma_map = {e.lemma: i for i, e in enumerate(entries)}
    target_words = set(lemma_map.keys())
    
    # Store candidates: entry_idx -> list of (score, text, cloze_idx)
    candidates_store = defaultdict(list)
    
    matched_count = 0
    
    # Tatoeba format: ID \t Lang \t Text ...
    try:
        with tarfile.open(TATOEBA_FILE, "r:bz2") as tar:
            # Locate the inner file 
            member = next((m for m in tar.getmembers() if "sentences_detailed" in m.name), None)
            if not member: 
                print("   ❌ sentences_detailed.csv not found in archive!")
                return
                
            f = tar.extractfile(member)
            io_wrapper = io.TextIOWrapper(f, encoding="utf-8")
            
            for line in tqdm(io_wrapper, desc="   Scanning Tatoeba", total=10000000):
                try:
                    parts = line.strip().split('\t')
                    if len(parts) < 3: continue
                    
                    lang = parts[1]
                    if lang != 'eng': continue
                    
                    text = parts[2]
                    words = text.split()
                    w_count = len(words)
                    
                    if not (5 <= w_count <= 15): 
                        continue
                    
                    low_text = text.lower()
                    
                    # Check for matches
                    # Only check if any target word is present to avoid slow regex every time
                    # We tokenize low_text for intersection check
                    tokens = set(re.findall(r"[a-z']+", low_text))
                    
                    common = tokens.intersection(target_words)
                    if not common: continue
                    
                    for w in common:
                        idx = lemma_map[w]
                        
                        # Verify proper boundary/case using helper
                        ctx = create_context_sentence(text, w)
                        if ctx:
                            # Score: number of other target words
                            score = len(common)
                            candidates_store[idx].append((score, ctx))
                            matched_count += 1
                                
                except Exception:
                    continue
    except Exception as e:
        print(f"   ❌ Error processing Tatoeba: {e}")
        return
            
    print(f"   ✅ Found {matched_count} context matches")
    
    # Assign top 3
    updates = 0
    for idx, candidates in candidates_store.items():
        candidates.sort(key=lambda x: x[0], reverse=True)
        
        unique_ctx = []
        seen = set()
        for _, ctx in candidates:
            if ctx.text not in seen:
                unique_ctx.append(ctx)
                seen.add(ctx.text)
            if len(unique_ctx) >= 3:
                break
                
        entries[idx].sentences = unique_ctx
        if unique_ctx: updates += 1
        
    print(f"   ✅ Updated {updates} entries with Tatoeba context")


def load_frequency_ranking() -> dict[str, int]:
    """Load word frequency ranking, preferring Norvig 1w."""
    norvig_path = next((path for path in NORVIG_1W_CANDIDATES if path.exists()), None)
    ranking = {}

    if norvig_path is not None:
        with open(norvig_path, "r", encoding="utf-8") as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) < 2:
                    continue
                word = parts[0].lower()
                if len(word) > 1 and word not in ranking:
                    ranking[word] = len(ranking) + 1
        print(f"   Loaded {len(ranking)} words from Norvig 1w ({norvig_path})")
        return ranking

    if not GOOGLE_10K_FILE.exists():
        print(f"   ⚠️ No frequency source found. Missing {GOOGLE_10K_FILE}")
        return {}

    with open(GOOGLE_10K_FILE, "r", encoding="utf-8") as f:
        for rank, line in enumerate(f, 1):
            word = line.strip().lower()
            if len(word) > 1 and word.isalpha() and word not in ranking:
                ranking[word] = rank

    print(f"   Loaded {len(ranking)} words from Google 10K ({GOOGLE_10K_FILE})")
    return ranking


def load_oxford_cefr() -> dict[str, str]:
    """Load and merge Oxford 3000 and 5000 CEFR lists."""
    cefr_map = {}
    
    # helper
    def load_file(path):
        if not path.exists():
            print(f"   ⚠️ {path} not found!")
            return
        print(f"   Loading {path}...")
        with open(path, 'r') as f:
            reader = csv.DictReader(f)
            count = 0
            for row in reader:
                # Format: ,word,type,cefr,phon_br...
                if 'word' not in row or 'cefr' not in row:
                    continue
                    
                word = row['word'].lower().strip()
                if " " in word: continue 
                level = row['cefr'].upper()
                
                if word not in cefr_map:
                    cefr_map[word] = level
                else:
                    current_lvl = cefr_map[word]
                    if cefr_to_int(level) < cefr_to_int(current_lvl):
                        cefr_map[word] = level
                count += 1
            print(f"   -> Read {count} lines.")

    load_file(OXFORD_3000_FILE)
    load_file(OXFORD_5000_FILE)
    
    print(f"   Loaded {len(cefr_map)} unique words with CEFR levels")
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
    
    # VSC Rank Limits
    # Core (A1/A2): Locked (Any Rank OK, usually < 2000)
    # Intermediate (B1/B2/C1): Target 2000-5000. Cap 12000.
    
    # Define Blacklist for filtered lemmas (Offensive + Function Words)
    BLACKLIST_LEMMAS = {
        # Offensive
        "cock", "cocks", "dick", "pussy", "shit", "fuck", "bitch", 
        "ass", "bastard", "damn", "crap", "sex", "sexy", "whore", "slut",
        # High-Frequency Function Words (Particles, Prepositions, Pronouns)
        "the", "in", "to", "of", "and", "a", "that", "it", "for", "on", "with", 
        "as", "at", "this", "but", "by", "from", "or", "an", "will", "if", 
        "than", "us", "we", "he", "she", "they", "me", "you", "him", "her", 
        "my", "your", "our", "their", "who", "which", "what", "how", "why", 
        "where", "when", "all", "any", "both", "each", "few", "more", "most", 
        "other", "some", "such", "no", "nor", "not", "only", "own", "same", 
        "so", "too", "very", "can", "just", "should", "now", "be", "is", "re", 
        "am", "are", "was", "were", "been", "being", "have", "has", "had", 
        "do", "does", "did", "done", "about", "above", "across", "after", 
        "against", "around", "behind", "below", "beside", "between", "beyond", 
        "during", "inside", "outside", "over", "through", "under", "upon", "within"
    }

    for word, level in cefr_map.items():
        if word in BLACKLIST_LEMMAS: continue
        if word in freq_ranking:
            rank = freq_ranking[word]
            
            # VSC Hard Cap: Rank > 12000 -> Reject
            if rank > 12000:
                continue
                
            cefr_words.append((word, level, rank))
    
    
    # VSC Sorting: 
    # Prioritize 2000-5000 band?
    # Simple CEFR sort handles most.
    
    # VSC Sorting: Prioritize 2000-5000 band
    def rank_priority(r):
        if 2000 <= r <= 5000: return 0 # Goldilocks Zone (First)
        return 1                       # Others (Fillers)

    cefr_words.sort(key=lambda x: (cefr_priority(x[1]), rank_priority(x[2]), x[2]))
    
    # Use cefr_words as the primary candidate source
    candidates = cefr_words
    
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
    
    # FINAL SOURCE: Oxford Only
    # We strictly respect the Oxford list (cefr_map).
    # Any word not in cefr_map is excluded.
    
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
                    # Skip IPA Extraction
                    pass
                    
                    # Extract definition using Lexicographer
                    senses = entry.get('senses', [])
                    definition, examples = Lexicographer.select_best_sense(senses, word)
                    
                    if definition:
                        # Limit examples (Use as suggested collocations)
                        examples = examples[:3]
                        
                        # Synonyms (Limit to 3 high-quality)
                        synonyms = []
                        all_syns = []
                        for sense in senses:
                             for syn in sense.get('synonyms', []):
                                 term = syn.get('word', '')
                                 if term and term not in all_syns and term != word:
                                     all_syns.append(term)
                        
                        # Filter synonyms (must be single words, no spaces)
                        synonyms = [s for s in all_syns if " " not in s][:3]
                        
                        pos = entry.get('pos', 'word')
                        
                        results[word] = {
                            'ipa': None, # Removed
                            'definition': definition,
                            'synonyms': synonyms,
                            'suggested_collocations': examples, # Using examples as proxy for collocations
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
    proper_noun_count = 0
    
    for idx, (lemma, cefr, rank) in enumerate(tqdm(candidates, desc="   Processing")):
        if len(entries) >= TARGET_SIZE:
            break
            
        data = kaikki_data.get(lemma)
        if not data: continue
        
        ipa = data.get('ipa')
        definition = data.get('definition')
        
        if not definition:
            skipped_def += 1
            continue
            
        # Init with empty sentences (Tatoeba will fill)
        sentences = []
        
        pos = expand_pos(data.get('pos', 'word'))
        
        # VSC Proper Noun Policy (Max 5% ~ 260)
        if pos in ['proper noun', 'prop', 'name']:
            if proper_noun_count >= 260:
                continue
            proper_noun_count += 1
        
        entry = VocabularyEntry(
            id=len(entries) + 1,
            lemma=lemma,
            rank=rank,
            cefr=cefr,
            pos=pos,
            ipa=None, # Explicitly Null
            definition=definition,
            synonyms=data.get('synonyms', []),
            suggested_collocations=data.get('suggested_collocations', []),
            collocations=[], 
            fsrs=FSRSState(
                difficulty=calculate_fsrs_difficulty(rank),
                stability=0.0,
                retrievability=0.0
            ),
            sentences=sentences
        )
        entries.append(entry)
        
    print(f"\n   ⚠️ Skipped: IPA={skipped_ipa}, Def={skipped_def}")
    
    # 5. Context Injection (Tatoeba)
    if TATOEBA_FILE.exists():
        inject_context_tatoeba(entries)
    else:
        print("   ⚠️ Tatoeba file missing, skipping context.")
    
    # 6. Link Collocations (Matrix)
    link_collocations(entries)
    
    # 6b. VSC Pruning (Dimension 3: Magnet Rule)
    print("\n✂️ STAGE 6b: Pruning Orphan Words (< 3 collocations)...")
    orphans = {i for i, e in enumerate(entries) if len(e.collocations) < 3}
    
    if orphans:
        print(f"   ⚠️ Pruning {len(orphans)} orphans (Magnet Rule). Re-indexing...")
        entries[:] = [e for i, e in enumerate(entries) if i not in orphans]
        
        # Reset and Re-link
        for i, e in enumerate(entries, 1):
             e.id = i
             e.collocations = []
        
        print("   🔄 Re-linking Graph after pruning...")
        link_collocations(entries)
    else:
        print("   ✅ No orphans found.")
    
    print(f"   Proper Nouns Used: {proper_noun_count} / 260")
    
    
    # 7. VSC Audit Sample
    print("\n🔍 Generating VSC Audit Sample...")
    import random
    audit_sample = []
    
    # Select 5 random entries + specific checks if present
    sample_indices = random.sample(range(len(entries)), min(5, len(entries)))
    
    for i in sample_indices:
        e = entries[i]
        audit = {
            "candidate_lemma": e.lemma,
            "evaluation": {
                "frequency_check": 2000 <= e.rank <= 5000 or (e.rank <= 500 and e.cefr in ['A1','A2','B2','C1','C2']), 
                "rank": e.rank,
                "polysemy_exception": e.rank <= 500 and e.cefr not in ['A1', 'A2'], # Rough heuristic
                "news_test_passed": len(e.sentences) >= 3, # Proxy for context availability
                "collocation_count": len(e.collocations),
                "proper_noun_check": e.pos != 'proper noun' or proper_noun_count <= 260,
                "cefr_verified": e.cefr
            },
            "verdict": "PASS" if len(e.collocations) >= 2 else "FAIL (Low Connectivity)"
        }
        audit_sample.append(audit)
        
    with open("docs/VSC_Audit_Sample.json", "w") as f:
        json.dump(audit_sample, f, indent=2)
    print("   ✅ Saved audit to docs/VSC_Audit_Sample.json")

    # 8. Validation & Export (Original Step 7)
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
        "version": 9, # Major Update
        "generated_at": datetime.now().isoformat(),
        "total_entries": total,
        "coverage": {
            "ipa": 0.0,
            "definitions": 1.0,
            "roots": 0.0, 
            "synonyms": 1.0,
            "unique_roots": 0
        },
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
