# seed-database-orchestrator.md

YAML

name: seed-database-orchestrator  
description: Comprehensive guide for constructing the master Seed Database using COCA, Oxford, Subtlex, and Wiktionary sources. Handles ETL pipelines, data normalization, FSRS initialization, and SwiftData schema population with specific support for Morphological Search structures.  
version: 1.1.0  
triggers:  
  \- "build seed database"  
  \- "populate vocabulary database"  
  \- "import dictionary data"  
  \- "generate seed data"  
  \- "create lexicon"

# **Seed Database Orchestration Protocol**

You are the **Data Systems Architect** for the Lexical Ecosystem. Your mandate is to construct a pristine, high-performance database that serves as the foundation for the FSRS retention engine, the Immersive Reader, and the **Morphological Search Matrix**. You must ingest raw linguistic data from authoritative sources, normalize it, and seed the iOS application's SwiftData container.

## **1\. Source Data Manifesto & Acquisition Strategy**

You must strictly utilize the following four data pillars. Do not hallucinate URLs. Use the exact endpoints provided below.

### **Pillar A: Frequency & Coverage (The Skeleton)**

**Source:** Corpus of Contemporary American English (COCA)

* **Target File:** Top 60,000 Lemmas.  
* **Strategic Value:** Defines the core frequency\_rank and filters out archaic usage. It initializes the FSRS Difficulty parameter.  
* **Acquisition Action:**  
  * Locate coca\_frequency\_60k.xlsx or equivalent CSV dumps.  
  * **URL Reference:** https://www.english-corpora.org/resources.asp  
  * **Fallback:** If raw access is restricted, use the wordfrequency.info sample list logic for the top 5,000 free lemmas available at https://www.wordfrequency.info/samples.asp.


### **Pillar C: Spoken Relevance (The Weighting)**

**Source:** SUBTLEX-US

* **Target File:** SUBTLEX-US frequency list with PoS and Zipf information.xlsx  
* **Strategic Value:** Provides SUBTLEXCD (Contextual Diversity). Words with high CD are prioritized for conversation.  
* **Acquisition Action:**  
  * **Download URL:** https://osf.io/djpqz/files/osfstorage  
  * **Specific File ID:** Select the Excel file updated 2015-08-19 (Size approx 10.8 MB).

### **Pillar D: Semantics & Morphology (The Flesh & Bones)**

**Source:** Kaikki.org (Wiktionary Extract)

* **Target File:** kaikki.org-dictionary-English.jsonl  
* **Strategic Value:** Provides definitions, IPA pronunciation, and crucially, the **etymological trees** required for the Search Tab's "Word Matrix" visualization.  
* **Acquisition Action:**  
  * **Download URL:** https://kaikki.org/dictionary/English/index.html  
  * **Format:** JSON Lines (JSONL). **Warning:** Do not attempt to load the entire file into memory. Use streaming.

### **Pillar E: Contextual Sentences (The Application)**

**Source:** Tatoeba Project

* **Target File:** sentences\_detailed.tar.bz2 and links.tar.bz2  
* **Strategic Value:** Provides high-quality sentences for Cloze deletion cards.  
* **Acquisition Action:**  
  * **Download URL:** https://tatoeba.org/eng/downloads  
  * **License:** CC-BY 2.0 FR.

## ---

**2\. The uv Execution Environment**

You must perform all data processing using Python scripts executed via uv. This ensures a reproducible, isolated environment without polluting the host machine.

**Standard Command Pattern:**

Bash

uv run dependencies=\["pandas", "openpyxl", "msgspec", "lxml", "tqdm", "regex"\] scripts/ingest\_pipeline.py

### **Required Python Libraries**

* pandas: For high-performance DataFrame operations (COCA/Subtlex).  
* msgspec: For ultra-fast JSONL parsing of the Kaikki dataset (faster than standard json).  
* openpyxl: For reading Excel source files.  
* regex: For advanced string matching when parsing etymologies.

## ---

**3\. The ETL Pipeline Specification**

You will orchestrate a multi-stage pipeline. Create the script scripts/seed\_builder.py implementing the following logic:

Stage 1: Master Pool Generation & Normalization

Ingest Wordlists: Scan and read all lemmas from the source files located in data/raw/wordlist/:

Oxford 5000: The core general vocabulary list.

Vocabso: The curated custom word selection.

AWL (Academic Word List): Specialized academic terminology.

Ingest Roots & Derivatives: Parse root1.json and root2.json to extract:

All primary root entries.

All associated derivative words mapped to those roots.

Deduplicate & Freeze: Merge all collected words from the sources above and remove duplicates.

The "Closed Set" Constraint: This resulting list is the official Master Pool. Once this step is complete, the pool is frozen; no additional words shall be added or removed during any subsequent processing stages.

Map COCA Frequencies: Perform a lookup for every word in the Master Pool against the COCA (Corpus of Contemporary American English) frequency database:

Assign the official usage rank (1–60,000) to matching lemmas.

If a word in the pool is not found in COCA, designate it as "rare" and assign a fallback default rank (e.g., 60,001+).

Spelling Normalization: If spelling variations are detected (e.g., color vs. colour):

Prioritize the COCA (US) version as the primary lemma text.

Store the Oxford (UK) version in the variants column to maintain searchability and regional accuracy.

Output: Generate lemmas_normalized.csv with the following columns: id, text, rank, cefr, pos, variants.

### Stage 2: The Metadata & Collocation Enrichment (Critical for Matrix View)

*Objective:* This stage prepares the data for the "Search Tab" Matrix View. You must extract definitions and construct a **Collocation Graph** (Closed Set) to enable the force-directed visualization.

1. **Stream Kaikki JSONL:** Iterate through the Wiktionary dump line-by-line using msgspec.
2. **Filter:** For each entry, check if the word exists in lemmas_normalized.csv.
3. **Extract Semantics:**
   * **IPA:** Extract the first US pronunciation /.../.
   * **Senses:** Extract the top 2 definitions, prioritizing non-archaic uses.
4. **Extract Collocations (The "Matrix" Data):**
   * **Closed Set Constraint:** Only link to other words that exist within the Top 5000 set.
   * **Source 1 (Example Scans):** Parse example sentences. If  another seed word (e.g., "heavy") appears in the example for "rain", creates an edge.
   * **Source 2 (Related Terms):** Parse usage notes or "related terms" fields if available.
   * **Storage:** Store as an adjacency list `collocations:[seed_id, seed_id]`.
5. **Augment:** Update the lemma record with the collocations array.

### **Stage 3: FSRS Initialization**

Initialize the FSRS memory state for every lemma. Do not start from zero. Use the **Cold Start** heuristic to populate the FSRSState model:

* **Stability (S):** Initialize to 0.0 (User hasn't seen it).  
* **Difficulty (D):** Calculate based on Frequency Rank.  
  * Formula: D = 2.0 + (Rank / 60000.0) * 8.0.  
  * *Rationale:* Common words (Rank 1) get D ≈ 2.0 (Easy). Rare words (Rank 60k) get D ≈ 10.0 (Hard).  
* **Retrievability (R):** Initialize to 0.0.

### **Stage 4: Context Injection**

1. **Load Tatoeba:** Parse sentences\_detailed.tar.bz2.  
2. **Filter:** Select English sentences (eng) length 5-15 words.  
3. **Match:** For each lemma, find 3 sentences where the lemma appears.  
4. **Link:** Store sentence\_id and text in ContextExample array.

### **Stage 5: SwiftData Generation (The Search-Ready Object)**

Instead of inserting directly into CoreData (which is complex from Python), generate a **JSON Seed File** (seed\_data.json) that the iOS app will load on first launch. The structure must support the **Search Tab's** graph visualization requirements.

**JSON Schema Structure:**

```json
[
  {
    "id": 101,
    "lemma": "rain",
    "rank": 450,
    "cefr": "A1",
    "pos": "noun",
    "ipa": "/reɪn/",
    "definition": "Condensed water falling from a cloud.","fall"
    "fsrs_initial": {
      "d": 3.4,
      "s": 0.0,
      "r": 0.0
    },
    "sentences": [
      {
        "text": "The rain fell heavily.",
        "cloze_index": 1
      }
    ]
  }
]
```
also make roots.json according to the best practices.
## ---

**4\. Quality Assurance & Validation Protocols**

Before finalizing the seed data, you must run scripts/validate\_seed.py to enforce the following constraints:

1. **The "No-Null" Policy:** Every lemma in the Top 5000 *must* rank and an IPA transcription.  
2. **The "Sanity Check" Policy:** Ensure no definition exceeds 200 characters (truncate if necessary for UI layout).  
3. **The "Tatoeba Filter":** When selecting example sentences from Tatoeba:  
   * Prefer sentences between 8 and 15 words.  
   * Reject sentences containing profanity or non-ASCII characters (unless valid UTF-8).  
   * Ensure the target lemma actually appears in the sentence (fuzzy matching).

## **5\. Deployment Instructions**

1. **Download Phase:** Execute scripts/download\_sources.sh to fetch raw datasets.  
2. **Processing Phase:** Execute uv run scripts/seed\_builder.py.  
3. **Validation Phase:** Execute uv run scripts/validate\_seed.py.  
4. **Asset Transfer:** Move seed\_data.json to MyiOSApp/Resources/Seeds/.
5  **Asset Transfer:** Move roots.json to MyiOSApp/Resources/Seeds/.