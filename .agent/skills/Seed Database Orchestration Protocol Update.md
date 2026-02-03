# **Seed Database Orchestration Protocol: The Architectural Foundation of the Next-Generation Lexical Ecosystem**

## **1\. Executive Summary: The Data Systems Mandate**

The construction of the master Seed Database for the Lexical Ecosystem represents a pivotal convergence of computational linguistics, advanced database architecture, and cognitive science. This report serves as the definitive technical manual for the **Data Systems Architect**, establishing a rigorous, reproducible methodology for ingesting, normalizing, and enriching raw linguistic data. The mandate is not merely to aggregate words but to architect a **pristine, high-performance relational object** that serves as the bedrock for the system's three core pedagogical engines: the Free Spaced Repetition Scheduler (FSRS) retention engine, the Immersive Reader, and the morphological Search Matrix.1

In the current landscape of Mobile Assisted Language Learning (MALL), data sterility remains a pervasive bottleneck. Market incumbents often rely on static, decontextualized word lists that fail to reflect the dynamic, interconnected nature of human language.1 To bridge the "intermediate plateau"—the critical phase where learners struggle to transition from passive recognition to active retrieval—the Lexical Ecosystem requires a data structure that is mathematically precise, semantically rich, and pedagogically aligned.

This protocol delineates a "Multi-Pillar" acquisition strategy, synthesizing four authoritative data sources: the **Corpus of Contemporary American English (COCA)** for frequency and coverage; the **Oxford 3000™ / 5000™** for pedagogical alignment and CEFR grading; **SUBTLEX-US** for spoken relevance weighting; and **Kaikki.org (Wiktionary)** for deep semantic and morphological extraction. By orchestrating these disparate sources through a Python-based ETL (Extract, Transform, Load) pipeline managed by the uv package manager, we establish a "Closed Set" Lexical Graph. This graph not only powers the application's FSRS algorithms but also enables the "Matrix View," a force-directed visualization of etymological families that transforms vocabulary acquisition from rote memorization to structural discovery.2

The following sections provide an exhaustive technical specification for this orchestration, moving from source acquisition strategies to the intricacies of the uv execution environment, the multi-stage ETL pipeline, and the rigorous quality assurance protocols required to deploy a "search-ready" object to the iOS SwiftData container.

## ---

**2\. Source Data Manifesto & Acquisition Strategy**

The integrity of any algorithmic system is fundamentally limited by the quality of its input data. For the Lexical Ecosystem, we reject the use of generic, unverified "frequency lists" found in public repositories in favor of a "Multi-Pillar" strategy. Each of the four data pillars described below serves a distinct, non-overlapping functional role—Skeleton, Filter, Weighting, and Flesh—creating a composite data structure that is robust, verifiable, and pedagogically sound.

### **2.1 Pillar A: Frequency & Coverage (The Skeleton)**

**Source:** Corpus of Contemporary American English (COCA)

**Target Artifact:** Top 60,000 Lemmas (coca\_frequency\_60k.xlsx or equivalent CSV)

**Strategic Value:** The Skeleton of the Lexical Graph.

The Corpus of Contemporary American English (COCA) is the only large, genre-balanced corpus of English, containing over one billion words of text from spoken, fiction, popular magazines, newspapers, and academic journals.4 Unlike traditional dictionaries which are prescriptive and static, COCA is descriptive and dynamic, capturing the language as it is actually used.

**Technical Justification:** The primary utility of COCA in this architecture is the definition of the frequency\_rank variable. This integer value (1 to 60,000) is not merely metadata; it is a functional variable used to initialize the **FSRS Difficulty (D)** parameter.2 The FSRS algorithm models memory decay based on the intrinsic difficulty of the material. By mapping frequency\_rank to D using a linear interpolation formula (e.g., Rank 1 ![][image1] D=2.0, Rank 60k ![][image1] D=10.0), we provide the scheduler with a "Cold Start" heuristic. This allows the system to schedule the first review of the word "the" differently from the word "ephemeral" even before the user has interacted with them.1

**Data Integrity Protocol:**

* **Lemma vs. Word Form:** We strictly utilize the **lemma** list rather than the word-form list. A lemma aggregates all inflected forms of a word (e.g., *run, runs, running, ran* ![][image2] *run*).6 Storing data at the lemma level reduces database bloat by approximately 60% and aligns with the cognitive reality of the mental lexicon, where word families are stored as connected units rather than isolated strings.  
* **The 60k Cutoff:** While COCA offers lists up to 100,000 words, the Top 60,000 covers approximately 98-99% of all tokens in standard English text. Beyond this threshold, the "long tail" of vocabulary consists largely of proper nouns, archaic terms, and hapax legomena (words occurring only once), which yield diminishing returns for the intermediate learner.5

**Acquisition Action:** The Architect must acquire the coca\_frequency\_60k.xlsx dataset. If raw access is restricted due to licensing, the fallback protocol utilizes the wordfrequency.info sample list logic for the top 5,000 free lemmas, which serves as the "Minimum Viable Corpus" for the application's core functionality.8

### **2.2 Pillar B: Pedagogical Alignment (The Filter)**

**Source:** Oxford 3000™ / 5000™ (CEFR Aligned)

**Target Artifact:** CSV extraction of CEFR levels (A1-C2).

**Strategic Value:** The Pedagogical Guardrails.

While COCA provides raw statistical frequency, it lacks pedagogical nuance. A word like "damn" may be high-frequency (Rank \~800), but it is not necessarily an A1 (Beginner) priority in a formal educational context. To address this, we integrate the Oxford 3000™ and 5000™ lists, which map vocabulary to the Common European Framework of Reference for Languages (CEFR) levels: A1, A2, B1, B2, C1, C2.10

**Strategic Application:** This mapping enables the "Too Difficult" warning system within the Immersive Reader. If a user with a B1 proficiency profile attempts to "capture" a C2 word, the system can intervene, suggesting they focus on high-yield B2 vocabulary first. This prevents cognitive overload and encourages a more structured learning path.1

**Normalization Logic:**

The ETL pipeline must handle the intersection of Pillar A and Pillar B.

* **Primary Key Matching:** We perform a LEFT JOIN on the COCA list using the lemma string.  
* **Imputation Heuristic:** Since COCA (60k) is larger than Oxford (5k), approximately 55,000 words will lack a CEFR tag. For these, we employ a rank-based imputation heuristic:  
  * Rank 1-1,000 ![][image1] A1  
  * Rank 1,001-3,000 ![][image1] A2  
  * Rank 3,001-5,000 ![][image1] B1/B2  
  * Rank 5,001+ ![][image1] C1/C2 This ensures the "No-Null" policy for proficiency tagging is maintained across the entire database, enabling consistent filtering logic in the UI.10

### **2.3 Pillar C: Spoken Relevance (The Weighting)**

**Source:** SUBTLEX-US

**Target Artifact:** SUBTLEX-US frequency list with PoS and Zipf information.xlsx

**Strategic Value:** The Conversational Prioritization.

Traditional corpora like the BNC (British National Corpus) or even parts of COCA can over-represent written text (newspapers, academic journals). For an application focused on conversational fluency, we require a weighting mechanism that prioritizes spoken utility. SUBTLEX-US, derived from a corpus of 51 million words from film and television subtitles, provides this metric.1

**Key Metrics:**

* **SUBTLEXCD (Contextual Diversity):** This metric measures the number of distinct movies/shows a word appears in, rather than just raw frequency count. CD has been shown to be a better predictor of word processing reaction times than raw frequency. A word that appears once in 100 movies is more "valuable" for a learner than a word that appears 100 times in a single movie.  
* **Zipf Scale:** The dataset includes Zipf values (logarithmic frequency scale). We utilize this to fine-tune the FSRS Initial Stability (S0). Words with extremely high Zipf scores (\>6.0) are likely already "passive" vocabulary for the user; the system assigns them a higher S0, pushing their first review interval further into the future to avoid redundant drilling.1

### **2.4 Pillar D: Semantics & Morphology (The Flesh & Bones)**

**Source:** Kaikki.org (Wiktionary Extract)

**Target Artifact:** kaikki.org-dictionary-English.jsonl

**Strategic Value:** The Morphological and Semantic Graph.

This is the most complex and structurally rich data source. Kaikki provides a machine-readable extraction of Wiktionary, offering definitions, IPA pronunciation, and crucially, **etymological trees**.

**The Matrix Data:** The "Morphological Search Matrix" feature of the application relies on constructing a graph where words are nodes and etymological roots are edges. Kaikki's etymology\_text and derived fields must be parsed to extract these relationships (e.g., linking "structure" and "destruction" via the root "struct"). This transforms the database from a flat list into a relational network.2

**Streaming Architecture:**

The source file is a massive JSONL (JSON Lines) dump, often exceeding several gigabytes. Loading it entirely into memory is computationally prohibitive and prone to crashes. The ingestion protocol mandates the use of streaming parsers (specifically msgspec) to process the file line-by-line, filtering only for the target lemmas identified in Pillar A. This ensures the build process remains performant even on standard development hardware.

### **2.5 Pillar E: Contextual Sentences (The Application)**

**Source:** Tatoeba Project

**Target Artifact:** sentences\_detailed.tar.bz2 and links.tar.bz2

**Strategic Value:** The Context Injection Engine.

Isolated words are difficult to retain; context is the anchor of memory. Tatoeba provides a corpus of high-quality, human-translated sentences that serve as the raw material for the "Context Injection" phase.

**Cloze Generation:** These sentences are used to generate Cloze Deletion cards (e.g., "The cat sat on the \[\_\_\_\_\_\]"). The protocol applies strict filtering heuristics—length (5-15 words), language (English), and content safety—to ensure the context is digestible for a mobile screen ("Thumb Zone" optimization) and pedagogically appropriate.3

## ---

**3\. The uv Execution Environment: Reproducible Data Engineering**

To ensure the reproducibility of this complex data orchestration, the protocol mandates the use of uv, a modern, high-performance Python package manager written in Rust. uv replaces the fragility of traditional pip and venv workflows with atomic, lock-file-driven environments that guarantee consistent execution across different development machines.11

The "Seed Database Orchestrator" is not merely a script; it is a compiled artifact of a specific environment state. Using uv ensures that the specific versions of parsing libraries (like pandas and msgspec) are locked, preventing subtle bugs caused by dependency drift.

### **3.1 Environment Specification & Command Pattern**

The build script scripts/seed\_builder.py must be executed within an ephemeral, isolated environment defined by uv metadata.

**Standard Command Pattern:**

Bash

uv run dependencies=\["pandas", "openpyxl", "msgspec", "lxml", "tqdm", "regex", "pydantic"\] scripts/ingest\_pipeline.py

### **3.2 Required Python Libraries & Justification**

* **pandas**: Essential for the high-performance merging of the COCA (60k rows) and Oxford (5k rows) DataFrames. Its vectorized operations reduce the "Stage 1" normalization processing time from minutes to milliseconds.  
* **msgspec**: Selected over the standard json library for parsing the Kaikki JSONL dump. Benchmarks indicate msgspec is 10-80x faster at decoding, which is critical when streaming a multi-gigabyte text file. It allows for defining strict schemas for the JSON lines, automatically filtering out malformed data.2  
* **openpyxl**: Required for reading the specific Excel (.xlsx) formats provided by COCA and SUBTLEX.  
* **regex**: A replacement for the standard re module, required for the recursive pattern matching needed to parse nested etymological templates in Wiktionary data (e.g., handling nested {{derived|en|la|struere}} tags).  
* **lxml**: Used for high-speed XML parsing if source data (like subsets of Wiktionary) is provided in XML format.  
* **tqdm**: Provides progress bars for the long-running ingestion tasks (Kaikki streaming), essential for developer experience during the build process.

## ---

**4\. The ETL Pipeline Specification: From Raw Corpus to Seed Object**

The Extract, Transform, Load (ETL) pipeline is the core operational mechanic of the Seed Database Orchestrator. It is designed as a linear sequence of transformative stages, where each stage produces an intermediate artifact. This modularity allows for easier debugging, validation, and partial re-runs.

The script scripts/seed\_builder.py implements the following logic:

### **Stage 1: The Lemma Registry (Normalization & Merging)**

**Objective:** Create a single, canonical list of unique lemmas that serves as the primary key for all subsequent joins.

1. **Ingest COCA:** The script reads coca\_frequency\_60k.xlsx. At this stage, we discard columns regarding dispersion or genre specificities, retaining only lemma, rank, and part\_of\_speech.  
   * *Normalization:* COCA uses specific PoS tags (e.g., j for adjective). These must be mapped to a standardized Enum (adj, noun, verb, adv) compatible with the Swift LexicalCategory used in the iOS app.  
2. **Ingest Oxford:** The CEFR CSV is loaded. We perform a LEFT JOIN on the COCA DataFrame using lemma as the key.  
3. **Conflict Resolution:**  
   * *Spelling:* If Oxford uses "colour" and COCA uses "color", the system defaults to the COCA (US English) version as the primary key but stores the Oxford version in a variants array to support fuzzy search matching.  
   * *Levels:* If a word exists in Oxford, its cefr tag (A1-C2) is authoritative.  
   * *Imputation:* For the \~55,000 words in COCA *not* in Oxford, we impute the level using the rank-based heuristic defined in Section 2.2.  
4. **Output:** lemmas\_normalized.csv. This file becomes the "Truth" of the database.

### **Stage 2: Metadata & Collocation Enrichment (The Matrix Construction)**

**Objective:** Prepare the data for the "Search Tab" Matrix View by extracting definitions and constructing a **Collocation Graph** (Closed Set).

This stage transforms the database from a list into a network. The "Matrix View" in the iOS app uses a force-directed graph where nodes are words and edges represent semantic or etymological links.2

1. **Stream Kaikki JSONL:** The script iterates through the massive Wiktionary dump line-by-line using msgspec.  
2. **Filter & Match:** For each entry, we check if the word exists in lemmas\_normalized.csv. If not, it is discarded immediately to conserve memory.  
3. **Semantic Extraction:**  
   * **IPA:** We extract the first US pronunciation (labeled en-us). If missing, we fall back to UK IPA but flag it for review.  
   * **Senses:** We extract the top 2 definitions. We implement a filter to reject definitions tagged "archaic," "obsolete," or "offensive" to maintain pedagogical relevance.  
4. **Collocation Extraction (The Matrix Data):**  
   * **The Closed Set Constraint:** A critical requirement for the visualization is that we do not link to words *outside* our database. If the word "rain" has a related term "precipitation," we only create a graph edge if "precipitation" also exists in lemmas\_normalized.csv. This prevents "dead ends" in the UI where a user taps a node that leads nowhere.  
   * **Source Scanning:** We parse example sentences and usage notes to find co-occurrences of other seed words.  
   * **Storage:** We build an adjacency list: collocations: \[seed\_id, seed\_id\]. This array of integers is stored directly on the lemma object, allowing the Swift app to render connections without complex SQL joins.  
5. **Augment:** The lemma record is updated with the extracted IPA, definitions, and collocations array.

### **Stage 3: FSRS Initialization (The Cold Start Heuristic)**

**Objective:** Initialize the memory state for every lemma so the scheduler works immediately upon first launch.

The FSRS algorithm relies on three variables: Stability (S), Difficulty (D), and Retrievability (R). For a new user, R is 0\. However, D is not uniform. The word "The" is inherently easier than "Anachronism." We use a **Cold Start Heuristic** to pre-calculate D based on the COCA frequency rank.1

* **Formula:** ![][image3]  
  * *Rationale:* FSRS difficulty scales from 1 (easiest) to 10 (hardest).  
  * Rank 1 (e.g., "the") ![][image4] (Easy).  
  * Rank 60,000 (e.g., "accoucheur") ![][image5] (Hard).  
  * This linear interpolation provides a reasonable starting point. The algorithm will self-correct as the user begins reviewing.  
* **Stability (S):** Initialized to 0.0 (User hasn't seen it).  
* **Retrievability (R):** Initialized to 0.0.

### **Stage 4: Context Injection (Tatoeba Integration)**

**Objective:** Provide context sentences for "Smart Card" generation.

1. **Load Tatoeba:** Parse sentences\_detailed.tar.bz2.  
2. **Filter:** We strictly select sentences with lang='eng'.  
   * *Length Filter:* Reject sentences \< 5 words (too short for context) or \> 15 words (too long for mobile widgets/Thumb Zone).3  
3. **Match & Link:** For each lemma, we perform a regex search \\b{word}\\b (word boundary search) against the filtered sentence corpus.  
4. **Selection:** We select the top 3 sentences that match. Priority is given to sentences that *also* contain other high-frequency words (optimizing for comprehensibility).  
5. **Data Structure:** Sentences are stored as an array of objects: \[{ "id": 123, "text": "...", "cloze\_index": 4 }\]. The cloze\_index marks the position of the target word, enabling the frontend to easily render the \[\_\_\_\_\_\] blank.

### **Stage 5: SwiftData Generation (The Search-Ready Object)**

**Objective:** Serialize the enriched data into a format optimized for iOS ingestion.

Direct CoreData/SwiftData manipulation from Python is notoriously brittle. Instead, we generate a monolithic JSON file (seed\_data.json) that strictly adheres to the Swift Codable protocol used in the iOS app.

**JSON Schema Structure:**

JSON

\[  
  {  
    "id": 101,  
    "lemma": "rain",  
    "rank": 450,  
    "cefr": "A1",  
    "pos": "noun",  
    "ipa": "/reɪn/",  
    "definition": "Condensed water falling from a cloud.",  
    "collocations": , // IDs for "heavy", "fall"  
    "fsrs\_initial": {  
      "d": 3.4,  
      "s": 0.0,  
      "r": 0.0  
    },  
    "sentences":  
  }  
\]

This structure is "flat" regarding relationships (using IDs for collocations rather than nesting objects), which prevents circular reference errors during serialization and simplifies the Swift decoder logic.

## ---

**5\. Quality Assurance & Validation Protocols**

Before deployment, the seed\_data.json artifact must pass a rigorous validation suite. "Garbage in, garbage out" is fatal for a retention engine. The script scripts/validate\_seed.py enforces the following constraints:

### **5.1 The "No-Null" Policy**

**Constraint:** Every lemma in the Top 5,000 *must* have a valid CEFR tag, a non-empty IPA transcription, and at least one definition.

**Rationale:** The Top 5,000 represents the "Core" vocabulary. Missing data here breaks the user's trust and disrupts the learning path. The script throws a hard error if coverage drops below 100% for this subset.

### **5.2 The "Matrix Density" Check**

**Constraint:** The average node degree (collocations per word) must be \> 2.0.

**Rationale:** The Matrix View relies on interconnectivity. A graph with isolated nodes (degree \= 0\) provides no value for exploration. If the graph is too sparse, the build fails, prompting the Architect to loosen the "Closed Set" constraint or import additional intermediate roots.

### **5.3 The "Sanity Check" Policy**

**Constraint:** No definition should exceed 200 characters.

**Rationale:** Long definitions break the UI layout of the flashcards and widgets. The script automatically truncates definitions or selects shorter alternatives from the Wiktionary data if this limit is exceeded.

**Constraint:** UTF-8 Validation. Ensure no encoding artifacts (mojibake) exist in the text, particularly from the Tatoeba import.

### **5.4 The "Tatoeba Filter"**

**Constraint:** Context Verification.

**Rationale:** Sometimes lemmatization causes mismatches (e.g., the lemma "go" matches the word "go", but the sentence might use "went"). The script performs a fuzzy match check to ensure the target lemma (or a valid inflection) actually appears in the sentence text. We also enforce the "Profanity Filter" to reject sentences containing non-pedagogical content.

## ---

**6\. Deployment Instructions: The Orchestration Flow**

The deployment is an automated, reproducible process orchestrated by uv.

1. **Download Phase:**  
   * Execute scripts/download\_sources.sh. This shell script creates a data/raw directory and uses curl or wget to fetch the specific files from the URLs provided in Section 2\.  
   * *Security Note:* Verify SHA-256 checksums of downloaded files to prevent supply chain attacks or data corruption.  
2. **Environment Setup:**  
   * Run uv venv to create the isolated environment.  
   * Run uv pip sync requirements.txt to lock dependencies.  
3. **Processing Phase:**  
   * Execute uv run scripts/seed\_builder.py.  
   * Monitor the tqdm progress bars. The Kaikki parsing stage will be the bottleneck; expect \~10-15 minutes of processing time on a standard M-series chip.  
4. **Validation Phase:**  
   * Execute uv run scripts/validate\_seed.py.  
   * Review the generated validation\_report.md. Check for "Red Flags" (e.g., "Zero sentences found for 'apple'").  
5. **Asset Transfer:**  
   * Upon success, the script automatically moves seed\_data.json to the iOS project path: MyiOSApp/Resources/Seeds/.  
   * It also generates a version\_hash.txt containing the SHA-1 of the seed file. The iOS app uses this hash to detect if a seed update is required on first launch.

## ---

**7\. Conclusion: The Foundation of Fluency**

This Seed Database Orchestration Protocol is not merely a data import task; it is the architectural foundation of the entire Lexical Ecosystem. By rigorously fusing frequency, pedagogy, morphology, and context, we create a data object that is "alive"—capable of guiding a learner from the chaos of raw vocabulary to the structured order of fluency. The use of uv ensures this process is repeatable, scalable, and robust, ready to support the next generation of algorithmic language learning.

This infrastructure ensures that when the FSRS engine queries for the difficulty of "ephemeral," or when the Search Matrix visualizes the root "chron," the data returned is accurate, contextual, and pedagogically sound. This differentiates a true lexical acquisition engine from a simple dictionary app.

---

**Prepared By:** Data Systems Architect / Computational Linguistics Lead

**Date:** February 2, 2026

**Version:** 1.1.0
