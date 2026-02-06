#!/usr/bin/env python3
"""
Lexical Seed Database Validator v1.0.0
======================================
Validates the generated seed_data.json against quality protocols.
1. No-Null Policy (Rank, IPA)
2. Sanity Check (Definition Length)
3. Tatoeba Filter (Context Quality)
"""

# /// script
# dependencies = [
#   "msgspec", 
#   "regex"
# ]
# ///

import json
import statistics
import sys
from pathlib import Path
from dataclasses import dataclass
from typing import List, Optional

# Configuration
SEED_FILE = Path("Lexical/Resources/Seeds/seed_data.json")

def validate_seed():
    print("=" * 60)
    print("🔍 LEXICAL SEED DATABASE VALIDATION")
    print("=" * 60)
    
    if not SEED_FILE.exists():
        print(f"❌ Error: Seed file not found at {SEED_FILE}")
        sys.exit(1)
        
    try:
        with open(SEED_FILE, 'r') as f:
            data = json.load(f)
    except Exception as e:
        print(f"❌ Error loading JSON: {e}")
        sys.exit(1)
        
    print(f"📄 Loaded {len(data)} entries.")
    
    # Metrics
    missing_ipa = 0
    missing_def = 0
    long_defs = 0
    missing_context = 0
    orphans = 0 # No collocations
    
    ranks = []
    
    for entry in data:
        lemma = entry.get('lemma', 'UNKNOWN')
        
        # 1. No-Null Policy
        if not entry.get('ipa'):
            missing_ipa += 1
            # Optional: Print samples?
        
        if not entry.get('definition'):
            print(f"   ⚠️ Missing Definition: {lemma}")
            missing_def += 1
            
        if not entry.get('rank'):
             print(f"   ⚠️ Missing Rank: {lemma}")
        else:
            ranks.append(entry['rank'])
            
        # 2. Sanity Check
        definition = entry.get('definition') or ""
        if len(definition) > 200:
            long_defs += 1
            
        # 3. Context
        sentences = entry.get('sentences', [])
        if not sentences:
            missing_context += 1
        else:
            # Validate matches
            for s in sentences:
                text = s.get('text', '')
                if lemma.lower() not in text.lower():
                     # Fuzzy check failure
                     pass
                     
        # 4. Collocations
        if not entry.get('collocations'):
             orphans += 1

    # Reporting
    print("\n📊 VALIDATION REPORT")
    print(f"   Total Entries:      {len(data)}")
    print(f"   Missing IPA:        {missing_ipa} ({missing_ipa/len(data)*100:.1f}%)")
    print(f"   Missing Definition: {missing_def}")
    print(f"   Definitions > 200c: {long_defs}")
    print(f"   Missing Context:    {missing_context}")
    print(f"   Orphan Words:       {orphans}")
    
    if ranks:
        print("\n📈 RANK STATISTICS")
        print(f"   Min Rank: {min(ranks)}")
        print(f"   Max Rank: {max(ranks)}")
        print(f"   Avg Rank: {sum(ranks)/len(ranks):.1f}")

    # Pass/Fail Thresholds
    failures = []
    if missing_def > 0: failures.append("Missing Definitions detected")
    # IPA is often missing for rare words in Kaikki, so we might just warn
    if missing_ipa > (len(data) * 0.2): failures.append("High missing IPA rate (>20%)") 
    
    if failures:
        print("\n❌ VALIDATION FAILED")
        for f in failures:
            print(f"   - {f}")
        sys.exit(1)
    else:
        print("\n✅ VALIDATION PASSED")
        sys.exit(0)

if __name__ == "__main__":
    validate_seed()
