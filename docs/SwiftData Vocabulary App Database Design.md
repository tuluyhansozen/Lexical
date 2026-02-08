# **Architectural Specification: Database Strategy for the Next-Generation Lexical Acquisition Ecosystem**

## **1\. Executive Summary: The Structural Imperative of Cognitive Modeling**

The architecture of modern Mobile Assisted Language Learning (MALL) applications faces a critical inflection point. The traditional "digital flashcard" model—characterized by static databases, linear progression, and simplistic rote memorization intervals—has proven insufficient for bridging the "Intermediate Plateau." This plateau, where learners possess passive recognition vocabulary but lack the active retrieval strength required for spontaneous communication, necessitates a fundamental re-engineering of the underlying data persistence layer.

The "Target System" envisioned in the provided strategic documents is not merely a vocabulary app; it is a **Personalized Lexical Ecosystem**. It demands the synthesis of three distinct computational and pedagogical domains: the mathematical precision of **Algorithmic Spaced Repetition (SRS)**, the immersive variability of **Contextual Incidental Learning**, and the structural interconnectivity of **Morphological Analysis**.

For the Systems Architect, this convergence presents a unique set of constraints. The database must support high-frequency read operations to power real-time text analysis (tokenizing and coloring thousands of words per second in the "Immersive Reader"), while simultaneously handling complex, mathematically derived write operations to maintain the integrity of the **Free Spaced Repetition Scheduler (FSRS) v4.5** algorithm. Furthermore, the requirement for an **Offline-First** experience, synchronized across distributed devices (iPhone, iPad, Desktop) via **Conflict-Free Replicated Data Types (CRDTs)**, renders standard "Last-Write-Wins" synchronization strategies obsolete and dangerous.

This comprehensive architectural report outlines the schema design, data topology, and implementation strategy for the Target System using **SwiftData**. It provides a rigorous analysis of the "Dual-Store Topology"—the strict separation of static linguistic data from dynamic user states—and details the specific schema requirements for advanced features such as Onboarding Level Tests (Computerized Adaptive Testing), LLM-driven Content Generation, and the Force-Directed Word Matrix. This document serves as the definitive guide for the Senior iOS Engineer and the Systems Architect operating within the Google Antigravity IDE ecosystem.

## ---

**2\. Strategic Data Topology: The Dual-Store Architecture**

A pervasive anti-pattern in educational software design is the conflation of "Linguistic Truth" (immutable data) and "Learner State" (mutable data). In a monolithic schema, the definition of a word, its phonetic transcription, and its etymological root are stored in the same record as the user's "Next Review Date" and "Memory Stability." This coupling results in severe inefficiencies: syncing static dictionary data via CloudKit consumes unnecessary bandwidth, updating the dictionary requires complex migration scripts on user devices, and query performance degrades as the user's history grows.

To mitigate these risks, the Target System implements a **Dual-Store Topology** utilizing SwiftData’s advanced ModelConfiguration capabilities. This architecture mandates the coexistence of two distinct persistent stores within the application sandbox, each governed by different rules of mutability, storage, and synchronization.

### **2.1 The Static Corpus Store (The Immutable Truth)**

The Static Corpus Store serves as the application's reference library. It contains the "Ground Truth" of the language—data that is universally true for all users and does not change based on user interaction.

* **Persistence Strategy:** Read-Only SQLite Store.  
* **Deployment:** Pre-populated, compressed, and bundled with the application binary.  
* **Synchronization:** Excluded from CloudKit and iCloud Backup. Updates are delivered via App Store binary updates or differential over-the-air (OTA) patches that replace the underlying .store file.  
* **Scale:** Designed to hold between 20,000 and 60,000 lemma entries, plus associated multimedia references and morphological graphs.

The primary entity within this store is the LemmaDefinition. This entity must be rigorously indexed to support the ![][image1] lookups required by the "Immersive Reader" engine. When a user opens an article, the text processing engine tokenizes the content and queries this store to determine the existence and rank of every word on the screen. Latency here directly impacts the frame rate of the UI; therefore, the schema prioritizes query speed over storage size.

### **2.2 The User Progress Store (The Cognitive Shadow)**

The User Progress Store represents the learner's brain. It tracks the "Shadow" of the language—the specific, evolving relationship between the user and each lemma.

* **Persistence Strategy:** Read-Write SQLite Store.  
* **Deployment:** Generated empty on first launch; populated via the "Onboarding Level Test" and subsequent interactions.  
* **Synchronization:** Private CloudKit Database, synchronized using a CRDT-compliant logic.  
* **Characteristics:** High write frequency. Every tap, every review, and every article read triggers updates to this store.

The separation allows for the implementation of a "Soft Link" pattern. The VocabularyItem in the User Store does not duplicate the definition or audio path; it holds a foreign key (lemmaId) that resolves against the Static Corpus at runtime. This decoupling ensures that if the content team corrects a typo in the definition of "ubiquitous" in the Static Store, the change is instantly reflected for all users without requiring a database migration on their devices.

## ---

**3\. Schema Specification: The Static Corpus**

The design of the Static Corpus must support three critical functions: efficient frequency-based lookup for the Onboarding Test, morphological traversal for the Word Matrix, and rich metadata retrieval for the Flashcard UI.

### **3.1 The Lemma Definition Model**

The LemmaDefinition is the atomic unit of the Static Store. It must capture the linguistic complexity of English while remaining performant.

Swift

import SwiftData  
import Foundation

@Model  
final class LemmaDefinition {  
    // PRIMARY KEY & INDEXING  
    // The unique string identifier (e.g., "run").   
    // Indexed for rapid lookups during text tokenization.  
    @Attribute(.unique) var lemma: String  
      
    // FREQUENCY & RANKING  
    // Derived from COCA or BNC corpora.   
    // Critical for the Onboarding Level Test and "Smart Ignoring" logic.  
    // Rank 1 \= "the", Rank 20,000 \= "ephemeral".  
    @Attribute(.indexed) var rank: Int  
      
    // LINGUISTIC METADATA  
    var partOfSpeech: String // Enum mapped to String: "n", "v", "adj", "adv"  
    var ipa: String // Phonetic transcription, e.g., "/səˈrɛndɪpɪti/"  
    var cefrLevel: String // "A1", "A2", "B1", "B2", "C1", "C2" \[1\]  
    var basicMeaning: String // Concise definition for the flashcard back-face  
      
    // MULTIMEDIA & ASSETS  
    // Filename references to assets stored in the App Bundle or On-Demand Resources.  
    var audioFilename: String?  
      
    // MORPHOLOGICAL LINKAGE  
    // Soft Link to the Root entity.  
    // Indexed to allow "Find all words with root ID X" queries.  
    @Attribute(.indexed) var rootId: Int?   
      
    // RELATIONAL DATA  
    // We strictly define the inverse to ensure integrity within the static graph.  
    @Relationship(deleteRule:.cascade, inverse: \\StaticSentence.lemmaDefinition)  
    var sentences:?  
      
    init(lemma: String, rank: Int, partOfSpeech: String, ipa: String, cefrLevel: String, basicMeaning: String, rootId: Int? \= nil) {  
        self.lemma \= lemma  
        self.rank \= rank  
        self.partOfSpeech \= partOfSpeech  
        self.ipa \= ipa  
        self.cefrLevel \= cefrLevel  
        self.basicMeaning \= basicMeaning  
        self.rootId \= rootId  
    }  
}

**Data Integrity Insight:** The cefrLevel field is not merely descriptive; it is functional. It drives the "Article Generation" logic, allowing the LLM to select vocabulary appropriate for the user's estimated proficiency. The rank field is vital for the "Recommendation Engine," ensuring that learners are not exposed to obscure words (Rank \> 20,000) before mastering high-frequency items (Rank \< 3,000).2

### **3.2 The Morphological Root Model**

To support the "Word Matrix" visualization, the database must model the etymological relationships between words. The schema must facilitate the rapid construction of a force-directed graph where a central "Root" node is connected to its derived "Lemma" nodes.

Swift

@Model  
final class MorphologicalRoot {  
    // IDENTIFICATION  
    @Attribute(.unique) var id: Int // Numeric ID from the etymology database  
    @Attribute(.indexed) var root: String // e.g., "spect" or "spec/spic"  
      
    // SEMANTICS  
    var basicMeaning: String // e.g., "look, see"  
    var originLanguage: String // "Latin", "Greek"  
      
    // GRAPH OPTIMIZATION  
    // Instead of a heavy SwiftData @Relationship, we store a pre-computed   
    // array of lemma ranks or IDs. This allows the graph renderer to   
    // instantiate the node structure without fetching full Lemma objects   
    // until the user interacts with a specific node.  
    var associatedLemmaIds:   
      
    init(id: Int, root: String, basicMeaning: String, originLanguage: String, associatedLemmaIds:) {  
        self.id \= id  
        self.root \= root  
        self.basicMeaning \= basicMeaning  
        self.originLanguage \= originLanguage  
        self.associatedLemmaIds \= associatedLemmaIds  
    }  
}

**Second-Order Insight:** By storing associatedLemmaIds as a primitive array, we decouple the MorphologicalRoot from the LemmaDefinition table overhead. This is critical for the "Explore" tab, where the user might swipe through dozens of roots rapidly. The application can render the *shape* of the word family (e.g., seeing that *spect* has 45 derivatives while *aev* has only 4\) using only the lightweight Root entity, fetching the heavy Lemma details only on demand.5

## ---

**4\. Schema Specification: The Retention Engine (FSRS & User State)**

The User Progress Store is the dynamic heart of the application. Its schema is dictated by the requirements of the **FSRS v4.5 Algorithm**, which replaces the legacy SM-2 model. FSRS requires the tracking of three distinct variables—Stability (![][image2]), Difficulty (![][image3]), and Retrievability (![][image4])—along with a precise history of interactions to optimize its predictive accuracy.

### **4.1 The Vocabulary Item (The Cognitive State)**

This entity represents the user's brain state regarding a specific word.

Swift

@Model  
final class VocabularyItem {  
    // FOREIGN KEY  
    // Links to LemmaDefinition.lemma in the Static Store.  
    @Attribute(.unique) var lemmaId: String   
      
    // FSRS MEMORY MODEL VARIABLES \[6, 7, 8\]  
    // Stability (S): The interval in days at which Retrievability drops to 90%.  
    // A high stability means the memory is strong.  
    var stability: Double   
      
    // Difficulty (D): A value between 1.0 (Easiest) and 10.0 (Hardest).  
    // Represents the intrinsic complexity of the memory trace.  
    var difficulty: Double   
      
    // Retrievability (R): The probability (0.0 \- 1.0) that the user can recall  
    // the item at the current moment t.   
    // R \= (1 \+ factor \* t / S) ^ decay  
    // Often calculated dynamically, but stored for caching/sorting.  
    var retrievability: Double   
      
    // SCHEDULING  
    // The absolute date when the item falls below the retention threshold (e.g., 90%).  
    // Indexed for the "Due Today" query.  
    @Attribute(.indexed) var nextReviewDate: Date  
    var lastReviewDate: Date?  
      
    // READER STATE MACHINE   
    // 0 \= New (Blue): User has not interacted.  
    // 1 \= Learning (Yellow): In the SRS loop (Stability \< Graduation Threshold).  
    // 2 \= Known (Transparent): Stability \> Graduation Threshold or Manually Marked.  
    var status: Int   
      
    // SYNC CONFLICT RESOLUTION (LWW-Element-Set)  
    // The timestamp of the last state change. Used to resolve conflicts  
    // between devices (e.g., iPhone marks 'Known', iPad marks 'New').  
    var stateUpdatedAt: Date   
      
    // RELATIONSHIPS  
    @Relationship(deleteRule:.cascade) var reviewLogs:?  
      
    init(lemmaId: String, status: Int \= 0) {  
        self.lemmaId \= lemmaId  
        self.status \= status  
        self.stability \= 0.0  
        self.difficulty \= 0.0  
        self.retrievability \= 0.0  
        self.nextReviewDate \= Date.distantFuture  
        self.stateUpdatedAt \= Date()  
    }  
}

### **4.2 The Review Log (The Immutable History)**

In a distributed, offline-first system, the current state of a word (e.g., Stability \= 45.2) is a derivative of its entire history. If devices desynchronize, simply merging the stability scalar value is mathematically unsound and leads to data loss. The system must merge the *history* of reviews and recalculate the state.

Therefore, the ReviewLog schema is critical. It must act as an **Append-Only Log** (G-Set) that records the immutable facts of user interaction.

Swift

@Model  
final class ReviewLog {  
    // UNIQUE IDENTIFIER  
    // Critical for deduplication during CRDT merging.  
    @Attribute(.unique) var id: UUID  
      
    // ASSOCIATIONS  
    var lemmaId: String  
      
    // FSRS INPUTS \[7, 8\]  
    // The grade assigned by the user: 1=Again, 2=Hard, 3=Good, 4=Easy  
    var grade: Int   
      
    // The precise moment of review.  
    var reviewDate: Date  
      
    // FSRS OPTIMIZER DATA  
    // Time taken to answer in milliseconds.   
    // Used by the FSRS Optimizer to detect "easy" vs "hesitant" recall.  
    var duration: TimeInterval   
      
    // The interval that was scheduled for this card before this review.  
    // Essential for calculating the "R" value at the moment of review.  
    var scheduledDays: Int   
      
    // The state of the card before this review (0=New, 1=Learning, 2=Review, 3=Relearning).  
    var reviewState: Int   
      
    // DEVICE METADATA  
    // Useful for debugging sync loops and identifying the source of reviews.  
    var deviceId: String   
      
    init(lemmaId: String, grade: Int, reviewDate: Date, duration: TimeInterval, scheduledDays: Int, reviewState: Int, deviceId: String) {  
        self.id \= UUID()  
        self.lemmaId \= lemmaId  
        self.grade \= grade  
        self.reviewDate \= reviewDate  
        self.duration \= duration  
        self.scheduledDays \= scheduledDays  
        self.reviewState \= reviewState  
        self.deviceId \= deviceId  
    }  
}

**Third-Order Insight:** The inclusion of reviewState and scheduledDays allows the FSRS optimizer (which may run on the device during charging or on a server) to reconstruct the exact conditions of the review. Without these, the optimizer cannot accurately adjust the algorithm's weights (![][image5]) to fit the user's specific forgetting curve. This schema design effectively "future-proofs" the application for advanced machine learning personalization.8

## ---

**5\. Functional Use Case Implementations**

The database architecture is not static; it is an active participant in the application's core features. This section details how the schema supports specific functional requirements.

### **5.1 Onboarding Level Test: The "Cold Start" Solution**

A major friction point in language apps is the "Cold Start"—treating an intermediate user as a beginner. The database must support an **Adaptive Level Test** to estimate the user's vocabulary size and "warm up" the database.

**Algorithmic Logic:**

1. **Sampling:** The system queries the LemmaDefinition store using the rank index. It selects test items from exponential frequency bands (e.g., Rank 100, 500, 1000, 2000, 5000).11  
2. **Estimation:** Based on the user's pass/fail rate at these bands, the algorithm estimates a "Known Vocabulary Size" (e.g., 3,500 words).  
3. **Database Seeding (The "Warm Up"):**  
   * The system identifies all lemmas with rank \< UserEstimatedSize.  
   * It performs a **Batch Insert** into the VocabularyItem store.  
   * **Crucial Step:** It does *not* merely set status \= 2 (Known). It generates synthetic ReviewLog entries for these words with grade \= 4 (Easy) and date \= Now.  
   * **Result:** The FSRS algorithm initializes these words with a high stability (e.g., 100+ days). They are visually marked as "Known" (White) in the Reader but are technically tracked by the retention engine. If the user encounters one later and forgets it, the system can smoothly transition it back to "Learning" status with a lapse penalty.11

**Schema Requirement:** The LemmaDefinition table must be indexed on rank to allow sub-10ms batch fetching: FetchDescriptor(predicate: \#Predicate { $0.rank \< userEstimatedRank }).

### **5.2 The Immersive Reader: Real-Time State Visualization**

The "Immersive Reader" is the acquisition engine. It displays text with words highlighted based on their status: **New (Blue)**, **Learning (Yellow)**, **Known (White)**.

**Performance Challenge:** Rendering a 1,000-word article requires checking the status of 1,000 tokens against the database. Doing 1,000 individual SQL fetches is prohibitively slow and will cause scroll hitching.

**Architectural Solution: Bloom Filters & In-Memory Sets.**

1. **Launch Strategy:** Upon app launch, the system fetches all lemmaIds from VocabularyItem where status\!= 0\.  
2. **In-Memory Structure:** These IDs are loaded into a Set\<String\> or a Bloom Filter in the AppModel (RAM).  
3. **Render Pass:**  
   * Tokenize text string.  
   * Lemmatize token ("running" ![][image6] "run").  
   * Check In-Memory Set for "run".  
   * *If Present:* Check specific status (Yellow/White) from a lightweight dictionary.  
   * *If Absent:* Default to Blue.  
4. **Lazy Loading:** Detailed VocabularyItem data (stability, next review) is only fetched from the disk when the user *taps* a specific word to open the "Capture Card".6

### **5.3 LLM Article Generation: The Prompt Engineering Pipeline**

The system uses an on-device or API-based Large Language Model (LLM) to generate reading material tailored to the user's specific "Learning" queue.

**Data Flow & Schema:**

1. **Target Selection:** Query VocabularyItem for words where status \= 1 (Learning) AND retrievability \< 0.85 (approaching the forgetting threshold). Select the top 5-10 "At-Risk" lemmas.  
2. **Prompt Engineering:** The system constructs a prompt using the cefrLevel from the Static Store:"Generate a B2-level short story about 'Technology'. You MUST include the following words naturally: \[ephemeral, obsolete, interface...\]. Enclose these words in braces { }.".3  
3. **Content Storage:** Generated content is ephemeral but valuable. We cache it to prevent regeneration costs.

Swift

@Model  
final class GeneratedContent {  
    @Attribute(.unique) var id: UUID  
    var title: String  
    var bodyText: String // The raw text  
    var targetLemmaIds: // The vocabulary words practiced  
    var cefrLevel: String  
    var createdAt: Date  
    var isRead: Bool  
}

4. **Implicit Review:** When the user finishes reading the article, the system triggers an "Implicit Review" for the targetLemmaIds. It inserts a ReviewLog with a distinct reviewState (e.g., "ImplicitExposure") and a moderate grade. This informs the FSRS algorithm that the user has successfully encountered the word in context, slightly boosting its stability without a formal flashcard drill.16

### **5.4 The "Brain Boost" Triage Queue**

The project requirements specify a "Brain Boost" feature: a short-term loop for cards failed during a session (Grade \< 3).

**Conflict with FSRS:** Standard FSRS scheduling operates in *days*. Brain Boost operates in *minutes*. Persisting micro-schedules (e.g., "Review again in 180 seconds") to the main VocabularyItem database is an anti-pattern. It causes unnecessary write churn and complicates the sync logic.

**Architectural Decision:** **Transient State Management.**

1. **In-Memory Queue:** The SessionManager maintains a BrainBoostQueue (Array of VocabularyItem references) in RAM.  
2. **Persistence Fallback:** If the app is backgrounded/terminated, this queue is serialized to a lightweight JSON file in Library/Application Support/ActiveSession.json. It is *not* written to the SwiftData database.  
3. **Graduation Logic:** A card remains in the transient queue until it receives two consecutive "Good" ratings. Only upon "Graduation" is the final result committed to the VocabularyItem (updating stability) and the ReviewLog (recording the interaction). This keeps the long-term database clean of short-term noise.6

## ---

**6\. Synchronization and Offline Integrity**

The requirement for offline-first capabilities fundamentally dictates the database strategy. We cannot rely on server-side logic to resolve conflicts.

### **6.1 CRDT Implementation: The G-Set and LWW-Set**

To ensure eventual consistency across devices, we employ specific Conflict-Free Replicated Data Types (CRDTs).

**1\. The Review Log (G-Set: Grow-Only Set)**

* **Concept:** Review logs are immutable events. You cannot "un-review" a card.  
* **Sync Logic:** When Device A syncs with Device B, the resulting set of logs is the **Union** of both sets. ![][image7].  
* **Implementation:** ReviewLog entries are identified by UUID. CloudKit fetches new records and inserts them. No updates or deletes are ever performed on ReviewLog entities.

**2\. The Vocabulary State (LWW-Element-Set)**

* **Concept:** The status (New/Learning/Known) is mutable.  
* **Sync Logic:** We use **Last-Write-Wins** based on the stateUpdatedAt timestamp.  
* **Implementation:**  
  Swift  
  // Pseudocode for Merge  
  if remoteRecord.stateUpdatedAt \> localRecord.stateUpdatedAt {  
      localRecord.status \= remoteRecord.status  
      localRecord.stateUpdatedAt \= remoteRecord.stateUpdatedAt  
  }

**3\. Deterministic Replay (The FSRS Solver)**

Merging the stability value directly is dangerous because it depends on the *sequence* of reviews.

* **The Strategy:** Whenever new ReviewLog entries are ingested via sync:  
  1. Identify all affected lemmaIds.  
  2. For each lemma, fetch the full history of ReviewLogs (Local \+ New Remote).  
  3. Sort them chronologically.  
  4. **Replay** the FSRS algorithm from ![][image8] to ![][image9].  
  5. Update VocabularyItem.stability and VocabularyItem.difficulty with the recalculated values. This guarantees that regardless of the order in which devices come online, they will converge on the mathematically correct cognitive state.6

## ---

**7\. Advanced Integration: Widgets and App Groups**

The "Home Screen Offensive" strategy requires interactive widgets to display and update data without launching the main app.

**Constraints:**

* Widgets run in a separate process extension.  
* They cannot access the main app's memory or standard sandbox.

**Implementation Strategy:**

1. **Shared App Group:** Establish a security group group.com.yourcompany.lexical.  
2. **Shared Container:** Configure the SwiftData ModelContainer to use a URL within this shared group.  
   Swift  
   let containerURL \= FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group....")\!  
   let storeURL \= containerURL.appendingPathComponent("UserProgress.store")  
   let config \= ModelConfiguration(url: storeURL)

3. **Concurrency Safety:** Because both the App and the Widget might attempt to write to the SQLite file simultaneously, use **Swift actors** to serialize database access. Alternatively, design the Widget to write to a lightweight "Inbox" table (WidgetInteraction) which the main app consumes and processes into the main FSRS tables upon becoming active. This minimizes the risk of database locking errors.6

## ---

**8\. Conclusion: The "Deep Work" Architecture**

The architecture detailed in this report rejects the simplistic notion of the database as a passive storage bin. Instead, it elevates the database to the role of a **Cognitive Model**, actively participating in the pedagogical process.

By rigorously separating the **Static Corpus** (Read-Only, Optimized) from the **Dynamic User State** (Synced, FSRS-driven), we achieve a system that is performant at scale (60,000+ words) and robust against the chaos of distributed, offline-first usage. The integration of specialized schemas for **Morphological Roots** and **LLM Prompting** further distinguishes this system, transforming it from a mere tool for memorization into a comprehensive ecosystem for language acquisition.

This blueprint provides the technical foundation required to execute the ambitious "Agent-First" development roadmap, ensuring that the autonomous agents have a structured, mathematically sound environment in which to operate.

---

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAYCAYAAACIhL/AAAABv0lEQVR4Xu2VTStFURSGX98MiAFlgIHfIDKRj/ADFAO5GShzJfkJSkkG/oOfYMJEMhITXWWADDCgFPK5Vnsf93jv3nfvm0sG96m3zn3W2vuuTufsA5T5f4yyCNAuqWQZS5dkU7IhaaKai3nJEssIPliEWINZNGN/d0quJU9fHfl0SK5YpmiGf5BayTtLF3qrdZNdLlhe4d9I19WTa5Wc21oSH3uSVZaMbnDGMsUQTM8w+X7JMzkmNGAVCtdxiUADcnd4i/wLws9eaEBF6yMslQGY4g55pgWm7468ugZyTMyAJ5IDloreAV3MzxAzDdN3mHKN1oWIGXAZnp6YxUoWpk+Pk4RB60LE/McUHD1tVuYVHLj6Zh3OhWst0wtHT/L2PHKBmIDp4yMoY32ImAF74OmJWezr6YPbM771aSbh6bmHp2BJDtsaLiD3ZoeIGVCPKm+PFo5YCjcwb3khdK1+rgoRM+Axvp8QedzCbLIP80zqtT64IbRvgaVFz0z9Rl/Y6DWfowm6zxjLUrAoeWBZJBUI3+EfoZtXsyyCbck6y1IyLjllGYl+499Y/gYrkjmWEfzJcAkZFgG6JXUsy5SKT7BCf4Wmd65tAAAAAElFTkSuQmCC>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAAYCAYAAAAh8HdUAAAAqklEQVR4XmNgGLJADYhnArEvklgJEhsFsALxPyCeDcR8QGwHxP+BuAaIPyOpQwEgBTboggwQ8Sp0QRBYwACRxAZA4iBXYACQBD5NWAFMUy+6BD7QzYDQCMMzUFTgAHkMmBpvoaggAFwY8PuTIRhdAAoWM+DQ5AfEBeiCUFDKgEPTWSBehy4IBX8ZcAQGzN08aOJrGfAknSdAzATEHxggmt9D6QVIakbBwAEAIrItoSGpzDcAAAAASUVORK5CYII=>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABEAAAAXCAYAAADtNKTnAAAAsUlEQVR4XmNgGAWEQBcQfwTi/1D8HYjfoYldh6smAGAasIGfDLjlUABI0SF0QSjgYYDIN6CJo4AIBogiR3QJJIDPpWBwjYGAAgYiDCGogIEINSDJA+iCSMCNAaIGZyzBwsMBTRwZ3GaAqBFDl4ABQs40ZIDI16FLIAOQAlA6wAVA8k/QBZGBCgNEUTO6BBDIMUDk1qFLwEAgEJ9kQHjlDhAfh+KzUDFQ0jeFaRgFIw4AAFhqNpdzGLpuAAAAAElFTkSuQmCC>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAYCAYAAAAlBadpAAAAy0lEQVR4Xu2SMQ8BURCER6XSqiVahd8gWr3/4g8olCqVH6KlUGkQnUonR0hEEGaz7708e+/UivuSSS4zs5fbzQElI+pMvZ1u1JF6RF7Dl4vwRcsM6jdtECOFuTVJB5qtbeDpQwtdG5AJNJsaP7BB+pOFonUCqUKbelJ74+eQQbnwklpRd+dV41IKv68cJmbr/J/skC4NoX7dBjGpfYUr1K/YIEYKC2ui+KWBAbTQswHyw+F5TF2oDHrlE/XyoaMFHThA//fad1zy53wAhPQ9J2j9tisAAAAASUVORK5CYII=>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA4AAAAZCAYAAAABmx/yAAAApklEQVR4XmNgGAWjAAhmAPF9IP4PxIxI4gVA/AeJD5LfCePoAnE5kkQ6TALKf4XGB2Ew+AGljaGCLDAJKD8PiR8BxGdgnFoo3c2AZBoQMEH5IBfBgAYQT0XigwFI0UskPsgmZINAoAGIxdDEwIrCkPgvoGLI4C8an4GbAVMRiP8MTQweosgApLACyhaH8pENu4/ERgGwUAXhh1CxO0hiwlCxUTD4AADh0Sp0gvlmIgAAAABJRU5ErkJggg==>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABMAAAAXCAYAAADpwXTaAAAAVUlEQVR4XmNgGAWjgKpgL7oAJeAfugAlwAaIy9AFKQHngNgcXRAETMjEt4B4HwMa8CMTX4NiFgYKwUQg9kYXJAcoAnEnuiC54BO6ACXgMLrAKBhuAACnlhESw2iRqwAAAABJRU5ErkJggg==>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAI8AAAAYCAYAAADDAK5oAAAD8ElEQVR4Xu2ZWahNURjHP+ODQkJeCC/iGkpSFIknlCneJMoQefBGJNdQiowZi8xkSMSLkCEPKGOGkMiDMss8D9//rrXuXedvr3PPuXcf557u+tW/c/b/W+vstdfa+1trryMSiUQikUgkUv/Ypnqv+uPpnWqVX6ie81Iy++eH9eoyU1RvJbPdH1WX/EJp4U4QSeaEmP5px4GU6MtGgBlsVEPBx7WBmBNc5UCkkkIPwh42AuTbBpT/xWaazBRzkuEciFSC/vnJZorsYyNAPjdPdzHll3MgTZ5Lfo2qb5SJ6Z9lHEiRA2wEyGecDoop35wDaVLolFzqYGALPQiH2AiQzzj9l3HFCWqyCu/IRpHopdod0C7VTtV2MW+WW1VbTLWcqc0gNFT1ZDOBQt08eDMsGNWtd4awYXmmmqq6Qj5eD2tLZ9V11X0OFAn0T2i900zVhE0PvNKvZjMBTDG5kOvNU916Bw+czxLVA9U31Xqrx6oLfiHG7WGEwJ5PEqjTW9WC/Fl0XFMuqyawWQSQNXCtKzhgucuGRw/VK9UpDiSwn40A2cbK57CYsi05YEn6ndeqeeSh3HTyKsmWkuerBrOpjFbdYDNlQm1KApkKT1g+ypWjYtrSigOWT2x4PFHtEJOlq2MDGwFy7Zds4zpAtYhNMeUbJ3htyaugkZjgTQ4oHST55K5R3Lhy1R1VN3uMjIR5fK9qjlTtZPtgQDDNnRFzQ3b1YknnLgZ8nT7YsR3GpmWh/cS1h+r7YK/tGJsENijPshkA5/zNptJUwu3xfWQsTNWh5UzFXIwKY8jfbP1QdkGsDXkTVSulan6/Zz9RFotG8EjVx353G5MOfHdrh6Gqh16sWLiO5kEYIaZjQ4MAXD+gb7OV88GDtpFNCx4ubkeIUWLOuZb8cusnLaKxc42HG3VHqharjmeUsOAt5LuYnUc0CD/ohGN0zBdVe1eBCHUG+/h/5aR37MdPi3nzcfixi6rx3nExwPWjH7h/IPQbFpahHXlkYGSRI6rz8m+/ZANrLAwushr+EsEn6q/xCwWYJqZdSe124/pVNc5V8Hihmkse1nNpvABlkNQZmIJ4G/ypmPkVIKv49fAdUyPopPpcFUr8/VIBU0t/8krhetBGZFofbB5neyHIG0w7+FHmnJhsscDz/E7Dk4NUPske+wvNa6qlqk322NUbaz9LCTzZTF2/ebCs4DZi6mKv1mA9NJtNZaCYdD3I85AKHV3EvH2gUQBrJqRYvMq2Vr1RTbax22L2HEoJ7JNgisE1uX++y8Rk1A9ilgku09Yl0DZ/isN3TNlY86QGFrjYeEInRCJ5gcXbOtUtDkQiudCPjUgkEsmJvyaiG5FQFfArAAAAAElFTkSuQmCC>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACoAAAAYCAYAAACMcW/9AAABHklEQVR4Xu2UMUtCYRSGX8X+gJNztDSEf8DFNRH8GS1BSFtbU4j/IIxC3NqElsCpqS0ocAm3KLBoEl3Uc7pH+O7xXMPl1PA98MI9z/FyX+V+ApFIZBuqlCFlQempXYoJ5VFLJ5qUeTAfISlswosTLZ3gZ+8b7kI5lGWR1wsHGrB/vRkCX6EcUu5F1mX2ZAC76AiB53fjVMSnzBxPvmEXfYHhWRxrmcElpZuRG8o15YrSkc/Wfu7Khp+9Voh4gvIHInKhdOQNdtFnKH+rhTNZ7+grlOfhKxS/cE5pbRE+oJs4g100deoZHvhArXgIrr3gDkXD9bXYk2v+Fn/BO5K/oxUlJL12Aoe2yCmlEC6cGVM+KHdI+uym15FIJPLvWAJ2olFPnrcp/QAAAABJRU5ErkJggg==>

[image9]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGEAAAAYCAYAAADqK5OqAAAC1klEQVR4Xu2WS6hOURTHl8dAHklEUZIkE48yw+AiEzKQgTyKEskrZEAx8BwgmYiIrkdExojSLQYSMwMTRZQQGXgT1u/utbvrru9+57vq9t072L/6d/b677XPt8/a+9vniBQKhUKhUOizfFU9imahR2lY47+qbdEs9CiVNZ4uKaF/7Cj0GHVrPEe1UHVXUsJii3uT7aqLqtnBP6NaGzyYGeIdqg0uPq5a5WK4JKkoMFZ1VTWuo7sTK1XXVdOCf1C108WzVFdUm50HDWvMhLkRnR8sRr3BZdUf1QiL30uaMPxUDZA0z3nmwUbzMutVC1RPVZ9VX1T9VHdU5yznl10Zd0t1QjXUYg8LhZcXq021xNrXVCOt/77qk2qu9eE9szZ0u8YkbIlmHc5KmmBXuqBqVZ2X9NDkLmofVc1t6VyE5RYzlnuyAIDXYm3g4f243H7r2vyjaK9QDVadMh/vsbW/WZxhceKiLFUdtvZvu5KDBloMT8yLVNZ4qqQEdkxvMFzS728N/mi77rXrUal9OOJWF692Pjs0w04HjhQKNl5SDosSyf+4kxYPUe2RtFCZGXYlj2PJg8fm8DSs8Q2pfbhmclO69/vkvHFxLtZk52XwW6Lp4P1S7zfzYp9WHVCtka4Xa4ykPBbJg7cpeA1rTOfHaFawX3XkP5TP9Xrw+5UTNMjJZzLwAu9qXD7KqqDf72zPPWk8HjjWYh4v5ehBwxqT4N/yD1y7GTyXricOE+2ad52Hh8reO+fzUoy5Efr3RdPg6Kk3fr5rk5Nf8t77bu2Hwa+sMQmTrP3DdzQJPuHiQw8zb5DziPNn4hSLX1r8wq6A3+biyCipvXeE/rwBgLOcRZ/gPHI4FTx4uyXlvwp+ZY2PSccK+rd8M1knaQ58oqJDnbvb4dufHLRL0jmdY08sYGSZ1I6J8LHAPPL9+f6P4Oevtgzzwn8d/L5Q40KhUCgUCoVCoTv8Axdq0hKGcTLrAAAAAElFTkSuQmCC>