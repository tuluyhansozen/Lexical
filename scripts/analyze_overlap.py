import csv
import json
import re
from pathlib import Path

# Paths
DATA_DIR = Path("data/raw/word_list")
ROOTS1 = Path("roots1.json")
ROOTS2 = Path("roots2.json")
OXFORD = DATA_DIR / "oxford_5000.csv"
AWL = Path("AWL.txt")
VOCABSO = DATA_DIR / "vocabso.txt"

def get_oxford():
    words = set()
    if OXFORD.exists():
        with open(OXFORD, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            next(reader, None) # header
            for row in reader:
                if len(row) > 1:
                    words.add(row[1].strip().lower())
    return words

def get_roots_lemmas():
    lemmas = set()
    for p in [ROOTS1, ROOTS2]:
        if p.exists():
            data = json.load(open(p))
            for root in data:
                # Add the root itself? usually not a word.
                # Add matrix items
                items = root.get('matrix_items') or root.get('matrix_words', [])
                for item in items:
                    lemmas.add(item['lemma'].lower())
    return lemmas

def get_awl():
    words = set()
    if AWL.exists():
        with open(AWL, 'r') as f:
             for line in f:
                if 'Sublist' in line: continue
                parts = line.split()
                if len(parts) == 1 and parts[0].isalpha():
                    words.add(parts[0].lower())
    return words

def get_vocabso():
    words = set()
    if VOCABSO.exists():
        content = open(VOCABSO).read()
        candidates = re.findall(r'\b[A-Z][a-z]{2,}\b', content)
        for w in candidates:
            words.add(w.lower())
    return words

oxford = get_oxford()
roots = get_roots_lemmas()
awl = get_awl()
vocabso = get_vocabso()

print(f"--- Raw Counts ---")
print(f"Oxford: {len(oxford)}")
print(f"Roots (Lemmas): {len(roots)}")
print(f"AWL: {len(awl)}")
print(f"Vocabso: {len(vocabso)}")

print(f"\n--- Overlaps (Included in Oxford) ---")
print(f"AWL in Oxford: {len(awl.intersection(oxford))} / {len(awl)}")
print(f"Vocabso in Oxford: {len(vocabso.intersection(oxford))} / {len(vocabso)}")
print(f"Roots in Oxford: {len(roots.intersection(oxford))} / {len(roots)}")

print(f"\n--- Unique Contributions ---")
print(f"Oxford Unique: {len(oxford)}")
# Words in AWL that are NOT in Oxford
awl_new = awl - oxford
print(f"AWL New: {len(awl_new)}")

# Words in Vocabso that are NOT in Oxford AND NOT in AWL
vocabso_new = vocabso - oxford - awl
print(f"Vocabso New: {len(vocabso_new)}")

# Words in Roots that are NOT in Oxford, AWL, Vocabso
roots_new = roots - oxford - awl - vocabso
print(f"Roots New: {len(roots_new)}")

total = oxford | roots | awl | vocabso
print(f"\n--- Total Union ---")
print(f"Total Unique Lemmas: {len(total)}")
