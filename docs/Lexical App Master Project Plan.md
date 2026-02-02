# **Master Project Management Document (PMD): Architecture and Execution Roadmap for the Lexical Agentic Ecosystem**

## **1\. Strategic Governance and the Agent-First Paradigm**

### **1.1 The Operational Shift: From Authoring to Orchestration**

The execution of the "Lexical App" necessitates a fundamental departure from traditional Software Development Life Cycle (SDLC) methodologies. The prevailing industry standard, characterized by human-centric coding supported by intelligent completion tools, is insufficient for the complexity and velocity required by this project. Instead, this initiative will deploy an **"Agent-First" architecture** within the Google Antigravity IDE ecosystem. This paradigm shifts the role of the senior technical lead from a primary author of code to an architect of autonomous processes and a supervisor of digital labor.1

In this model, the "developer" does not manually implement the intricate mathematical models of the **Free Spaced Repetition Scheduler (FSRS)** or the distributed consistency logic of **Conflict-Free Replicated Data Types (CRDTs)**. Rather, the developer defines the constraints, strategic objectives, and verification protocols under which autonomous AI agents operate. The agents, functioning as active workers with direct access to the file system, terminal, and runtime environment, execute the tactical implementation. This transition addresses the "Intermediate Plateau" not just in language learning—the app's core market problem—but in software engineering itself, where the cognitive load of managing complex, multi-layered architectures often stifles innovation.1

The operational governance of this project relies on bridging the **"Trust Gap"**—the critical distance between an agent's assertion of task completion and the human architect's verification of functional correctness. To systematically close this gap, the project mandates the generation of structured, version-controlled **Artifacts** at every phase of the development lifecycle. These artifacts—specifically Task Plans, Implementation Plans, and Walkthrough Artifacts—serve as the immutable evidence of work, transforming the ephemeral nature of chat-based AI interaction into a rigorous engineering discipline.1

### **1.2 The Three-Surface Interaction Model**

To facilitate deep agentic integration, the project utilizes the Antigravity IDE's proprietary "Three-Surface" interaction model. This architectural choice is not merely aesthetic but functional, defining how agents perceive and manipulate the development environment.

| Surface | Functionality | Strategic Application in Lexical App |
| :---- | :---- | :---- |
| **Editor Surface** | Agent-Aware Code Manipulation | The agent perceives the entire workspace semantically, not just the active file. This is critical for refactoring the VocabularyItem SwiftData models across the entire codebase when FSRS parameters change.1 |
| **Mission Control** | Orchestration & Planning | The "Manager View" where the human architect reviews high-level "Implementation Plans" before authorizing code generation. This prevents architectural drift in complex modules like the CRDT Sync Orchestrator.1 |
| **Browser Surface** | Visual Verification & Research | A headless Chromium instance allowing agents to "see" the iOS Simulator via the Model Context Protocol (MCP). This enables autonomous visual regression testing of the "Liquid Glass" UI components.1 |

This tripartite structure ensures that the autonomous agents possess the necessary context to handle the project's specific technical challenges, such as the "Blue/Yellow/Known" state transitions in the Immersive Reader, without constant human context-switching.

### **1.3 Persona-Based Orchestration Strategy**

To prevent context saturation—a failure mode where an LLM's reasoning degrades due to an overabundance of irrelevant information—the project employs a strict **Persona-Based Orchestration** strategy. We do not employ a single "Generalist" agent. Instead, distinct agent personas are initialized via system prompts in the .agent/rules directory, each with a segregated set of responsibilities and "Skills".1

* **The Systems Architect:** This persona is responsible for the macro-level design, enforcing SOLID principles, and generating the Implementation Plan artifacts. It possesses deep knowledge of the FSRS algorithm's mathematical foundations but does not write UI code. Its primary directive is to ensure that the data models support the "Recall Dominance" pedagogical goal.1  
* **The Senior iOS Engineer:** Specialized in Swift 6.2 concurrency and the iOS 26 "Liquid Glass" design system. This agent is tasked with implementing thread-safe UI updates using MainActor isolation and managing the GlassEffectContainer hierarchies. It is explicitly prohibited from modifying the core FSRS logic without Architect approval.1  
* **The QA Automation Engineer:** This persona drives the testing framework. Uniquely, it utilizes the **Model Context Protocol (MCP)** to control the iOS Simulator. It "sees" the screen, taps buttons, and verifies that the "Brain Boost" queue correctly reinjects failed cards into the session. It produces the Walkthrough Artifacts—video evidence of successful feature implementation.1

## ---

**2\. Technical Architecture and Stack Definition**

### **2.1 The Hybrid Pedagogical Engine**

The Lexical App is defined by a hybrid architecture that synthesizes three historically distinct domains. The PMD requires strict adherence to this tripartite structure throughout the development lifecycle.

1. **Algorithmic Retention (The "When"):** We replace legacy SM-2 static intervals with the **FSRS v4.5** algorithm. This model calculates review intervals (![][image1]) based on Retrievability (![][image2]), Stability (![][image3]), and Difficulty (![][image4]). The system must track memory states at the atomic **Lemma** (root word) level to prevent database bloat and ensure efficient learning.2  
2. **Contextual Acquisition (The "How"):** The application rejects isolated flashcards in favor of "rich, authentic input." The **Immersive Reader**, built on **TextKit 2**, facilitates "Tap-to-Capture" interactions, instantly converting raw text into structured learning objects within a specific context sentence.2  
3. **Structural Analysis (The "Context"):** The **Collocation Engine** visualizes the semantic connections of words using a force-directed graph (Matrix View). This component is critical for the "analytical" user persona who benefits from understanding the contextual web of language (e.g., *rain* -> *heavy*, *pouring* -> *rain*).2

### **2.2 The Offline-First Data Strategy**

Given the "interstitial" nature of the user's engagement—studying in short bursts on subways or coffee shops—the application must be **Offline-First**. This requirement dictates the use of **Conflict-Free Replicated Data Types (CRDTs)** for synchronization. Traditional "Last-Write-Wins" (LWW) strategies are mathematically proven to cause data loss in Spaced Repetition Systems (SRS) when reviews occur on multiple offline devices.10

* **Review Logs (G-Set):** Review events are immutable facts. A "Grow-Only Set" (G-Set) allows the system to merge review histories from an iPhone and iPad by simply unioning the logs. The current memory state (Stability/Difficulty) is then deterministically recalculated by replaying this merged log.12  
* **Vocabulary State (LWW-Element-Set):** The status of a word (New/Learning/Known) utilizes a Last-Write-Wins Element Set, where high-precision timestamps resolve conflicts regarding the user's current relationship with a word.13

## ---

**Milestone 1: Foundation & Environment Setup**

**Objective:** Construct the "Digital Shipyard" by initializing the Antigravity IDE, configuring agent personas, establishing hardware control via MCP, and codifying domain knowledge into executable Skill Files.

### **1.1 Strategic Objective**

The primary objective of Milestone 1 is not to write feature code, but to engineer the *engineer*. We must transform the generic Gemini models within Antigravity into specialized experts capable of building the Lexical App. This involves a rigorous setup of the .agent directory, the integration of the uv package manager for rapid script execution, and the connection of the iOS Simulator via the Model Context Protocol (MCP).1

### **1.2 Key Activities**

#### **1.2.1 Antigravity Workspace Initialization**

* **Directory Structure Enforcement:** Initialize the project root with the mandatory Antigravity hierarchy: /.agent/rules/, /.agent/skills/, /.agent/memory.md, and /.agent/tasks.json. These files serve as the "Long-Term Memory" (LTM) for the agents, preserving architectural decisions across sessions.1  
* **Package Management Strategy (uv Integration):** Implement uv as the exclusive runner for utility scripts. Unlike pip, uv supports **PEP 723** inline metadata, allowing agents to execute Python scripts (e.g., for generating mock FSRS data) without managing persistent virtual environments. This "zero-setup" execution model is critical for the agent's "Self-Healing" loops.1  
* **Repository Hygiene:** Configure .gitignore to explicitly track .agent/rules and .agent/skills (institutional memory) while excluding transient .agent/tasks.json and build artifacts.

#### **1.2.2 Agent Persona Configuration**

* **Defining the Architect:** Create .agent/rules/architect.md. This system prompt must explicitly instruct the agent to prioritize **Implementation Plans** over code generation and to enforce the "Recall Dominance" UI principle in all design documents.1  
* **Defining the QA Engineer:** Create .agent/rules/qa\_engineer.md. This persona must be instructed on the usage of MCP tools (ios-simulator-mcp) and the requirement to produce visual **Walkthrough Artifacts** (screenshots/video) for every verified task.1

#### **1.2.3 Model Context Protocol (MCP) Integration**

* **Server Configuration:** Install and configure the ios-simulator-mcp server in .agent/mcp\_config.json. This JSON-RPC bridge enables the agent to issue commands like launch\_app(bundleId), ui\_tap(x, y), and get\_screen\_tree() directly to the Xcode Simulator.6  
* **Tool Filtering:** To reduce agent cognitive load and prevent hallucinations, explicitly filter the exposed tools using the IOS\_SIMULATOR\_MCP\_FILTERED\_TOOLS environment variable. We restrict the agent to non-destructive testing tools: screenshot, ui\_tap, ui\_type, ui\_describe\_all, and launch\_app.  
* **Connectivity Verification:** Execute a "Handshake Protocol" where the QA agent attempts to boot a specific simulator (e.g., "iPhone 16 Pro") and retrieve its UDID via MCP to confirm control authority.18

#### **1.2.4 Skill Engineering (The Intelligence Layer)**

We must bridge the "Knowledge Cutoff" of the LLM regarding proprietary or cutting-edge technologies (like iOS 26 Liquid Glass or the specific FSRS v4.5 math). This is achieved by authoring SKILL.md files.

* **fsrs-retention-engine.md:** This skill file must contain the exact mathematical formulas for FSRS.  
  * *Retrievability:* ![][image5].19  
  * *Stability Update:* ![][image6].19  
  * *Constraint:* The skill must explicitly forbid the use of static intervals (e.g., "1 day, 3 days").13  
* **lexical-acquisition-reader.md:** Defines the logic for **TextKit 2** integration. It must detail the "Blue/Yellow/Known" highlighting logic and the requirement for atomic lemma tracking (mapping "running" to "run").13  
* **ios-liquid-glass-ui.md:** Encodes the iOS 26 design system rules. It must instruct the agent to use GlassEffectContainer for grouping translucent elements and to verify accessibilityReduceTransparency for accessibility compliance.13  
* **crdt-sync-orchestrator.md:** Specifies the sync logic. It must define the **Review Log** as an immutable append-only structure (G-Set) and the **Vocabulary State** as a Last-Write-Wins set (LWW-Set) to ensure mathematical convergence of data across devices.12

### **1.3 Deliverables**

1. **Antigravity Configuration Package:** Fully populated .agent directory with mcp\_config.json and uv scripts.  
2. **Skill File Suite:** Validated SKILL.md files for FSRS, Reader, Liquid Glass UI, and CRDT Sync.4  
3. **Persona Manifest:** System prompts for Architect, Senior Engineer, and QA Engineer.  
4. **Verification Artifact:** A verification\_report.md generated by the QA agent containing a screenshot of the booted simulator and a log of the successful uv script execution.1

### **1.4 Testing & Validation**

* **MCP Control Test:** Request the QA agent to "Launch MobileSafari on the simulator and navigate to apple.com."  
  * *Pass Criteria:* The agent successfully executes the sequence of MCP commands (open\_url, ui\_tap) and produces a screenshot of the Apple homepage.  
* **Skill Recall Test:** Query the Architect agent: "How do we calculate the next interval for a 'Hard' card?"  
  * *Pass Criteria:* The agent must reference the fsrs-retention-engine skill and cite the specific stability update formula, not the generic SM-2 multiplier.4  
* **Dependency Isolation Test:** Run a Python script via uv run that requires pandas.  
  * *Pass Criteria:* The script executes without manual pip install, demonstrating uv's ability to handle inline metadata.

### **1.5 Acceptance Criteria**

* The IDE successfully indexes all 4 primary Skill files.  
* The QA Agent can drive the iOS Simulator without human intervention.  
* The uv package manager is active and correctly isolating script dependencies.  
* The "Trust Gap" is bridged for the environment setup via a visual Walkthrough Artifact.

## ---

**Milestone 2: Architecture & Core Logic (Data & Algorithmic Layer)**

**Objective:** Construct the "Invisible Technology" layer—the offline-first database, synchronization engine, and FSRS scheduling logic—ensuring mathematical correctness and data integrity before any UI is built.

### **2.1 Strategic Objective**

Milestone 2 establishes the data foundation. The Lexical App requires a persistence layer that supports complex relationships (Words ![][image7] Sentences ![][image7] Reviews) and a sync engine that is robust against network partitions. We will utilize **SwiftData** for local persistence and implement the **FSRS v4.5** algorithm in pure Swift. The critical challenge here is ensuring that the sync logic (CRDTs) and the scheduling logic (FSRS) interact correctly: replaying a synced log of reviews must deterministically produce the correct memory state.8

### **2.2 Key Activities**

#### **2.2.1 SwiftData Schema Design**

* **Collocation/Matrix Modeling:** Design the VocabularyItem entity. It must use the @Model macro and include a \#Unique constraint on the lemma string to prevent duplicates. Fields must include stability (Double), difficulty (Double), and retrievability (Double) to support FSRS.13  
* **Immutable Review Logs:** Create the ReviewLog entity. This model is critical for the CRDT strategy. It must be treated as an **Append-Only Log**.  
  * *Attributes:* uuid (UUID), cardID (UUID), grade (Int: 1-4), reviewDate (Date), duration (TimeInterval), deviceID (String).  
  * *Constraint:* Records in this table are never updated or deleted, only inserted. This guarantees that synchronization is a commutative operation (Order A ![][image8] B \= Order B ![][image8] A).8  
* **Performance Optimization:** Apply the \#Index macro to the next\_review\_date and lemma columns. The FSRS scheduler performs high-frequency queries to fetch "Due" cards, and the Reader performs massive lookups during text tokenization. Indexing is mandatory for 120Hz performance.13

#### **2.2.2 CRDT Synchronization Engine**

* **G-Set Implementation:** Implement the SyncOrchestrator using a Grow-Only Set logic for review logs. The sync process involves fetching remote logs and performing a set union with local logs.  
* **LWW-Set Implementation:** Implement a Last-Write-Wins Element Set for the VocabularyItem metadata (e.g., "is\_known" flag). This requires storing a separate timestamp for state changes to resolve conflicts (e.g., User A marks "Known" on iPad at 10:00 AM; User B marks "New" on iPhone at 10:05 AM ![][image9] Result: "New").11  
* **Deterministic State Replay:** Develop the FSRSCalculator service. Whenever new review logs are ingested via sync, this service must query all logs for a specific card, sort them chronologically, and re-run the FSRS difference equations to update the stability and difficulty values. This ensures "Eventual Consistency" across all devices.8

#### **2.2.3 FSRS Logic & Brain Boost**

* **Algorithm Implementation:** Translate the FSRS math from fsrs-retention-engine.md into a Swift FSRSScheduler class. Implement the logic to calculate the optimal interval ![][image1] where ![][image10] (90% retrievability).19  
* **Brain Boost Queue:** Implement the "Short-Term Triage" logic. This is a non-persistent, in-memory priority queue.  
  * *Logic:* If Grade \< 3 (Again/Hard), the card is not rescheduled for tomorrow. It is injected into the current session queue at position \+ 3\.  
  * *Exit Condition:* The card remains in the Brain Boost loop until it receives two consecutive Grade \>= 3 ratings.2

### **2.3 Deliverables**

1. **Data Layer Package:**  
   * SchemaV1.swift: Complete SwiftData model definitions.  
   * PersistenceController.swift: Thread-safe database actor.  
2. **Sync Engine Module:**  
   * CRDTMerger.swift: Logic for G-Set and LWW-Set merging.  
   * SyncManager.swift: Mock interface for CloudKit/Local sync transport.  
3. **Algorithmic Core:**  
   * FSRSScheduler.swift: Unit-tested implementation of FSRS v4.5.  
   * BrainBoostSession.swift: Logic for intra-session repetition.  
4. **Test Suite:** Extensive unit tests covering CRDT conflict resolution scenarios and FSRS mathematical accuracy.

### **2.4 Testing & Validation**

* **CRDT Convergence Verification:**  
  * *Test:* Instantiate two separate databases (Device A, Device B). Perform conflicting reviews on the same card on both devices. Trigger the merge function.  
  * *Validation:* Both databases must result in identical stability and difficulty values for the card. The review log count must equal ![][image11].11  
* **FSRS Math Verification:**  
  * *Test:* Simulate a review history: \[Good, Good, Hard, Good\].  
  * *Validation:* The calculated interval must match the reference FSRS Python implementation within a 0.01 margin of error. It must explicitly *not* match SM-2 calculations.19  
* **Brain Boost Logic Test:**  
  * *Test:* Simulate a session where a card is graded "Again."  
  * *Validation:* The card must reappear within 3 steps. The session must not conclude until the card is graded "Good" twice.

### **2.5 Acceptance Criteria**

* SwiftData schema builds with strict concurrency enabled (Swift 6.2).  
* CRDT merge logic passes the "Commutativity Property" test (A+B \== B+A).  
* FSRS scheduler accurately predicts retrievability decay.  
* Database performs inserts of 10,000 logs in \< 200ms.8

## ---

**Milestone 3: The Acquisition Engine (Immersive Reader & Ingestion)**

**Objective:** Build the "Input" interface using TextKit 2 to facilitate "Contextual Incidental Learning," enabling the real-time categorization of vocabulary into "Blue/Yellow/Known" states and bridging external content via Safari.

### **3.1 Strategic Objective**

Milestone 3 addresses the "Intermediate Plateau" by providing the user with high-volume, comprehensible input. The technical challenge is rendering large texts (e.g., entire books) while performing real-time dictionary lookups for every single word to apply the correct color coding. This requires a **TextKit 2** architecture that leverages lazy processing and background tokenization to maintain 120fps scrolling performance.13

### **3.2 Key Activities**

#### **3.2.1 TextKit 2 Implementation**

* **Custom Layout Architecture:** Implement NSTextContentStorage and NSTextLayoutManager. Unlike the legacy TextKit 1, TextKit 2 separates content management from layout, allowing for non-contiguous layout calculation (essential for large documents).22  
* **Asynchronous Tokenization:** Integrate Apple's NaturalLanguage framework. Upon loading a text, offload tokenization and lemmatization to a background actor.  
  * *Process:* Raw Text ![][image9] NLTokenizer ![][image9] Lemma Resolution ![][image9] DB Lookup ![][image9] NSAttributedString.  
  * *State Mapping:* Map database states to visual attributes: New ![][image9] Blue Highlight (\#E3F2FD), Learning ![][image9] Yellow Highlight (\#FFF9C4), Known ![][image9] No Highlight.13  
* **Accessibility & Theming:** Implement listeners for accessibilityReduceTransparency. If enabled, switch from "Liquid Glass" style highlights to high-contrast underlines (Dotted for New, Dashed for Learning) to ensure usability for visually impaired users.3

#### **3.2.2 The "Tap-to-Capture" Interaction**

* **Contextual Extraction:** When a user taps a "Blue" word, the system must perform a sentence boundary analysis using NLTokenizer. It must capture the *full sentence* surrounding the word to serve as the "Context" for the flashcard. This is non-negotiable for "Contextual Integrity".2  
* **Ergonomic Bottom Sheet:** Implement the Capture Card using UISheetPresentationController with a .medium detent. This ensures the interaction remains in the "Thumb Zone" (bottom 30% of screen), allowing for one-handed operation during commutes.3  
* **Frequency Analysis:** Query the embedded COCA (Corpus of Contemporary American English) database. If the selected word is low-frequency (Rank \> 20,000), display a "Rare Word Warning" on the capture card to guide the user toward higher-value vocabulary.8

#### **3.2.3 Safari Web Extension (Importer Bridge)**

* **DOM Injection Strategy:** Develop a Safari Extension that injects a content.js script. This script must replicate the "Blue/Yellow" highlighting logic within the web page DOM.  
* **Bloom Filter Optimization:** To avoid sending the user's entire vocabulary database to the webpage (privacy/performance risk), generate a **Bloom Filter** of the "Known" words on the native side and pass this compressed probabilistic structure to the content script for fast client-side filtering.8  
* **Subtitle Parsing:** Implement parsers for YouTube (.srv3 format) and Netflix (JSON/XML). The extension must extract not just the text but the startTime and duration of the subtitle line to enable "Video Flashcards".8

### **3.3 Deliverables**

1. **Immersive Reader Component:** ReaderView (SwiftUI wrapper for TextKit 2\) capable of rendering styled text.  
2. **NLP Pipeline:** TokenizationActor for background processing of text.  
3. **Capture Interface:** Ergonomic bottom sheet with Frequency Badge and Context Editor.  
4. **Safari Extension:** Functional AppEx target with Bloom Filter integration.  
5. **COCA Database:** SQLite/SwiftData store containing frequency data for top 60k lemmas.

### **3.4 Testing & Validation**

* **Scroll Performance Profiling:**  
  * *Test:* Load "Moby Dick" (approx. 200k words) into the Reader.  
  * *Validation:* Use Instruments to verify that the main thread remains unblocked. Scrolling framerate must not drop below 110fps on ProMotion devices. Layout calculations for visible text must occur within 16ms.24  
* **Lemma Resolution Test:**  
  * *Test:* Tap the word "better" in a text.  
  * *Validation:* The capture card must identify the lemma as "good" (not "better") and display the frequency stats for "good."  
* **Safari DOM Injection Test:**  
  * *Test:* Navigate to a Wikipedia article.  
  * *Validation:* "New" words are highlighted blue. Tapping a word opens the app's capture intent without crashing the browser.

### **3.5 Acceptance Criteria**

* TextKit 2 layout correctly handles bi-directional text and dynamic type resizing.  
* Context sentences are accurately extracted without truncation.  
* Safari Extension respects user privacy (only processes text on active tab).  
* Visual state updates (e.g., marking a word as "Known") propagate instantly across the active document.

## ---

**Milestone 4: The Retention Engine (FSRS & Review Loop)**

**Objective:** Construct the "Output" interface, strictly adhering to the "Recall Dominance" pedagogical principle, and integrate the FSRS scheduler into a user-facing Study Session.

### **4.1 Strategic Objective**

Milestone 4 builds the engine that drives retention. The User Interface must be designed to facilitate "Active Recall." Unlike standard apps that show multiple choice answers (Recognition), this app must show *only* the Cloze sentence, forcing the user to mentally retrieve the word before revealing it. The FSRS algorithm developed in Milestone 2 is now connected to the UI grading buttons.3

### **4.2 Key Activities**

#### **4.2.1 Flashcard UI & Recall Dominance**

* **Front-Face Design:** Create the FlashcardFrontView. It displays the context\_sentence with the target lemma replaced by a blank (\[\_\_\_\_\_\]). Crucially, **no grading buttons** are visible. The entire screen acts as a "Reveal" gesture target.3  
* **Liquid Glass Morphing:** Use iOS 26 GlassEffectContainer and .matchedGeometryEffect to implement the transition to the "Back" face. The blank should "morph" into the filled word (highlighted yellow), and the grading bar should slide up from the bottom. This fluid transition reduces the cognitive jar of state changes.3  
* **Grading Toolbar:** Implement the four FSRS buttons: **Again (1)**, **Hard (2)**, **Good (3)**, **Easy (4)**.  
  * *Ergonomics:* Place these in the bottom 25% of the screen.  
  * *Feedback:* Tapping a button should trigger a "Toast" showing the new interval (e.g., "Good: 4 days") to build trust in the algorithm.3

#### **4.2.2 Session Orchestration & Brain Boost**

* **Session Generator:** Develop the SessionManager class. It queries SwiftData for cards where next\_review\_date \<= Now.  
* **Brain Boost Integration:** Implement the UI for the "Short-Term Queue." When a card is graded "Again," it stays in the session.  
  * *Visual Cue:* Apply a subtle pulsing orange border or a specific "Learning Mode" badge to distinguish these cards from normal reviews.  
  * *Logic:* Ensure the card appears at intervals (e.g., \+3, \+10) until it graduates.2

#### **4.2.3 Multimedia Anchors**

* **Neural TTS Pipeline:** Integrate AVSpeechSynthesizer or OpenAI TTS. When the card is revealed, the sentence audio must play automatically.  
* **Video Loop Player:** For words captured from Netflix/YouTube via the Safari Extension, embed a player that loops the specific startTime to endTime segment. This provides prosodic context (tone, body language) which aids memory encoding.2

### **4.3 Deliverables**

1. **Flashcard UI Package:** FlashcardView, GradingControl, LiquidGlassContainer.  
2. **Session Manager:** Logic to interleave FSRS reviews with Brain Boost drills.  
3. **Media Components:** VideoAnchorPlayer, TTSManager.

### **4.4 Testing & Validation**

* **FSRS Interval Verification:**  
  * *Test:* Review a new card with "Good."  
  * *Validation:* Verify in the database that stability has increased and next\_review\_date is set correctly according to the FSRS formula.  
* **Brain Boost Loop Test:**  
  * *Test:* Fail a card. Continue the session.  
  * *Validation:* The failed card must reappear. It must NOT be marked as "Review Complete" until successfully recalled twice in the session.  
* **UI Latency Test:**  
  * *Validation:* The "Reveal" transition must run at 60fps+. Audio must start within 100ms of the reveal.

### **4.5 Acceptance Criteria**

* The UI strictly enforces Recall Dominance (Answer is hidden).  
* FSRS updates are persisted correctly to the Review Log (G-Set).  
* Multimedia assets load and play without stalling the UI.  
* Accessibility labels are present for all grading buttons.

## ---

**Milestone 5: The Home Screen Offensive (Widgets & App Intents)**

**Objective:** Reduce the barrier to entry for study by moving interaction outside the app sandbox via iOS 17 Interactive Widgets and App Intents.

### **5.1 Strategic Objective**

The "Home Screen Offensive" is a key differentiator. By enabling "Micro-Dose" learning (5-10 second sessions) directly on the home screen, we bypass the friction of app launching. This requires a sophisticated implementation of **App Intents** to handle database writes from the widget extension and **Shared App Groups** to ensure data consistency.3

### **5.2 Key Activities**

#### **5.2.1 Shared Persistence Layer**

* **App Group Migration:** Migrate the SwiftData container to a shared App Group (e.g., group.com.lexicalapp). This allows the Widget Extension background process to read/write the same FSRS database as the main app.13  
* **Asset Sharing:** Ensure audio files and images are stored in the shared container so widgets can access them without file duplication.

#### **5.2.2 Interactive Widget Development**

* **Micro-Dose Widget:** Develop a widget that shows a single Cloze card.  
  * *Constraints:* Widgets cannot scroll. Use ViewThatFits to truncate long sentences intelligently.  
  * *Interaction:* Implement a two-stage timeline. Tap "Reveal" ![][image9] Reload Timeline ![][image9] Show Answer & Grade Buttons.  
  * *Binary Grading:* Due to space constraints on systemSmall widgets, implement a simplified binary grading scheme: **Forgot (Red)** vs. **Recalled (Green)**. Map "Recalled" to FSRS "Good".3  
* **Word of the Day (WOTD):** Create a widget that cycles through high-value words. Implement a "Smart Rotation" intent that refreshes the word if the user engages with it (e.g., plays audio).3

#### **5.2.3 App Intents Architecture**

* **GradeCardIntent:** Develop a Swift AppIntent that executes the FSRS logic in the background. Crucially, this intent must be performant enough to update the DB and reload the widget timeline in \< 1 second.  
* **PlayAudioIntent:** Implement AudioPlaybackIntent. This allows the widget to play the pronunciation file using the system's background audio session without launching the host app—a critical feature for low-friction study.3

### **5.3 Deliverables**

1. **Widget Extension Target:** MicroDoseWidget, WOTDWidget.  
2. **App Intents Library:** GradeIntent, CaptureIntent, AudioIntent.  
3. **Shared Persistence Config:** Validated App Group entitlement.

### **5.4 Testing & Validation**

* **Background Write Test:**  
  * *Action:* Grade a card on the widget.  
  * *Validation:* Open the main app immediately. The card should be gone from the "Due" queue, and the stats dashboard should reflect the review.  
* **Audio Intent Test:**  
  * *Action:* Tap the speaker icon on the WOTD widget.  
  * *Validation:* Audio plays. The app does *not* open. The dynamic island/Live Activity indicator may appear briefly.  
* **Timeline Flush Test:**  
  * *Action:* Complete a review.  
  * *Validation:* The widget must immediately show the next card. No "stale" data should be visible.23

### **5.5 Acceptance Criteria**

* Widgets function fully offline.  
* Grading interactions correctly update the FSRS stability parameters.  
* Audio playback is instantaneous and background-compatible.

## ---

**Milestone 6: Intelligent Engagement (Bandit Algos & Morphology)**

**Objective:** Implement the "AI Brain" of the ecosystem—using Bandit Algorithms for smart notifications and Morphological Analysis for structural learning.

### **6.1 Strategic Objective**

Static notifications ("Time to study\!") lead to fatigue and app deletion. Milestone 6 replaces this with a **Multi-Armed Bandit (MAB)** system that optimizes engagement by learning *what* message to send and *when* to send it. Simultaneously, we implement the **Morphology Matrix** to visualize the hidden connections between words, turning vocabulary acquisition into a logical exploration.8

### **6.2 Key Activities**

#### **6.2.1 Bandit Notification System**

* **Algorithm Implementation:** Implement an **Epsilon-Greedy** MAB algorithm.  
  * *Arms:* Define notification templates: "Streak Defense" (Loss Aversion), "Curiosity Gap" (Knowledge Gap), "Social Proof."  
  * *Reward:* Define "App Open" as the reward signal (1.0).  
  * *Logic:* 80% of the time, Exploit (send the best performing template). 20% of the time, Explore (try a random template).8  
* **Interruptibility Modeling:** Integrate CMMotionActivityManager.  
  * *Trigger:* Detect the transition from walking or automotive to stationary. This signals the user has arrived home or sat down—a prime window for study.  
  * *Constraint:* Do not poll continuously. Use "Significant Location Change" to wake the app and perform a lightweight check.8  
* **Fatigue Management:** Implement a hard "Cool Down." If 3 notifications are ignored (Reward \= 0), silence the app for 48 hours to preserve the user relationship.

#### **6.2.2 Morphology Matrix**

* **Etymological Database:** Integrate a lightweight etymology database (e.g., extracted from Wiktionary) mapping lemmas to roots (e.g., *spect* \-\> *inspect*).  
* **Force-Directed Graph:** Implement a physics-based graph view using SwiftUI Canvas or a library like Grape.  
  * *Visualization:* The Root is the central node. Derived words are satellites. Nodes are colored by their FSRS state (Blue/Yellow/Known).3  
* **Stability Boosting:** Implement the "Multiplier Effect." When a user learns a Root, programmatically apply a stability boost (e.g., 1.15x) to all derived words in the database, reflecting the cognitive ease of learning related terms.13

### **6.3 Deliverables**

1. **Engagement Engine:** BanditScheduler, MotionMonitor.  
2. **Morphology UI:** WordMatrixView, EtymologyService.  
3. **Privacy Manifest:** Updated declaration for Core Motion usage.

### **6.4 Testing & Validation**

* **Bandit Convergence:**  
  * *Test:* Simulate a user who only opens "Curiosity" notifications.  
  * *Validation:* The probability weight of the "Curiosity" arm must increase over 50 simulated trials.  
* **Interruptibility Trigger:**  
  * *Test:* Simulate a "Walk" \-\> "Sit" transition in the simulator.  
  * *Validation:* A local notification ("Smart Nudge") is scheduled within 2-5 minutes.  
* **Graph Rendering:**  
  * *Test:* Select the root "chron" (time).  
  * *Validation:* Graph displays "chronic," "synchronize," "chronology" as connected nodes.

### **6.5 Acceptance Criteria**

* Notifications are context-aware and adaptive.  
* Morphology graph is interactive and reflects real-time learning status.  
* Motion monitoring has negligible battery impact.

## ---

**Milestone 7: Core Development, Integration & Deployment**

**Objective:** Final system integration, rigorous Agentic QA automation, and public release preparation.

### **7.1 Strategic Objective**

The final milestone is about convergence. We integrate the Reader, Review, Widget, and Engagement modules into a cohesive product. The focus shifts from "building" to "verifying." We deploy the **QA Agent** to run exhaustive regression tests using the MCP simulator control, ensuring that the complex interactions (e.g., capturing a word in Safari and reviewing it in a Widget) function flawlessly.1

### **7.2 Key Activities**

* **Module Integration:** Merge all feature branches. Ensure the TabBarController correctly routes between the Reader, Review, and Stats dashboards.  
* **Agentic QA Automation:** Execute full "Walkthroughs."  
  * *Scenario:* "Fresh Install \-\> Onboarding \-\> Safari Capture \-\> Widget Review \-\> Sync to iPad."  
  * *Tooling:* Use MCP ui\_tap, type\_text, and screenshot to document every step.  
* **Performance Optimization:** Run Instruments profiling. Ensure memory usage is \< 150MB and scroll performance is 120fps.  
* **App Store Prep:** Generate privacy manifests, marketing assets, and TestFlight builds.

### **7.3 Deliverables**

1. **Production Candidate (.ipa).**  
2. **QA Artifact Suite:** A comprehensive folder of video logs and screenshots proving feature stability.1  
3. **Source Code Handover:** Finalized Git repository with all SKILL.md and architecture docs.

### **7.4 Testing & Validation**

* **End-to-End Regression:** All Acceptance Criteria from M1-M6 must pass.  
* **Sync Stress Test:** Sync 10,000 items between 3 devices under simulated poor network conditions.

### **7.5 Acceptance Criteria**

* Zero critical crashes.  
* Data integrity verified (no data loss during sync).  
* All features approved by human supervisor via Artifact review.

## ---

**9\. Workflow Instruction**

**Master Plan is generated.** I acknowledge that I will subsequently provide you with one milestone at a time, and your role will be to expand that specific milestone into a granular, low-level technical specification, including specific code implementation details, schema definitions, and agent prompts.

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAYCAYAAADDLGwtAAAAa0lEQVR4XmNgGHrgIhB/B+L/SPg9igo0AFOEF7AwQBSdR5dAB2UMEIXe6BLo4BMDEdaCAEnuO40ugQ4qGCAKfdAl0AF13cfMAFF0AV0CHUxggCiMQpeAgWsMELe9A+K3QPwBiP+gqBgFhAAASvkf/u64jGAAAAAASUVORK5CYII=>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAYCAYAAAAlBadpAAAAy0lEQVR4Xu2SMQ8BURCER6XSqiVahd8gWr3/4g8olCqVH6KlUGkQnUonR0hEEGaz7708e+/UivuSSS4zs5fbzQElI+pMvZ1u1JF6RF7Dl4vwRcsM6jdtECOFuTVJB5qtbeDpQwtdG5AJNJsaP7BB+pOFonUCqUKbelJ74+eQQbnwklpRd+dV41IKv68cJmbr/J/skC4NoX7dBjGpfYUr1K/YIEYKC2ui+KWBAbTQswHyw+F5TF2oDHrlE/XyoaMFHThA//fad1zy53wAhPQ9J2j9tisAAAAASUVORK5CYII=>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAAYCAYAAAAh8HdUAAAAqklEQVR4XmNgGLJADYhnArEvklgJEhsFsALxPyCeDcR8QGwHxP+BuAaIPyOpQwEgBTboggwQ8Sp0QRBYwACRxAZA4iBXYACQBD5NWAFMUy+6BD7QzYDQCMMzUFTgAHkMmBpvoaggAFwY8PuTIRhdAAoWM+DQ5AfEBeiCUFDKgEPTWSBehy4IBX8ZcAQGzN08aOJrGfAknSdAzATEHxggmt9D6QVIakbBwAEAIrItoSGpzDcAAAAASUVORK5CYII=>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABEAAAAXCAYAAADtNKTnAAAAsUlEQVR4XmNgGAWEQBcQfwTi/1D8HYjfoYldh6smAGAasIGfDLjlUABI0SF0QSjgYYDIN6CJo4AIBogiR3QJJIDPpWBwjYGAAgYiDCGogIEINSDJA+iCSMCNAaIGZyzBwsMBTRwZ3GaAqBFDl4ABQs40ZIDI16FLIAOQAlA6wAVA8k/QBZGBCgNEUTO6BBDIMUDk1qFLwEAgEJ9kQHjlDhAfh+KzUDFQ0jeFaRgFIw4AAFhqNpdzGLpuAAAAAElFTkSuQmCC>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAMUAAAAYCAYAAABKmDkBAAAF1UlEQVR4Xu2bV4glRRSGjwlRMWNWGDGBWRAUQR9EfVizICiCu6IYFl1RUFEREXNWzAFnjW+CuKJiQIwP6oMKRlQEc8Kc4/k9XUz1P1XV1ff27e5Z+4PDdP/VVV1dt+KpGpGBgbnD8iyMwbJqU9792t71wMCc4Aq1a1gcgRPVflQ7Qm0ttffUblHb23+oabZkoSXQi+Aj+8gGYj3TwOj8LenefEcWAryvdiGLyj8sNMlEE1fWUbtR7XCZGUr3nQmWb9VW9e77wOpqH7E4kM1CsXrl7PhycIlU/Xtc4r9DKt5/Q9R3MpOBX9S+VvvD06bcw8TnYpV2Uvyk9rRYr7uz2m9qJ8nsD+L7rqnKD8qtS86ScqVLWVesITZSVLGp2jcsFiD/sZEma+oUK4QnxPTNSD9S7QvSfBDnMhZrgPhnsCimP0baRWovk9YV76qdyqLyivSjsvmk8rJI4mFtcJXkryfQee5P2jHSQP6RwPMsKnuKhb1OOrT1SXMsIxaeM+cLsUDiH/Sz2m4sij2P93ZNLN+OB6X6mSrGje9AOn+y6JEKmzR/SbyXZ7aQ2WVyf0Bz7MRCiMPEEtiLA5RbxcIWe9qGhRbjZEmHV/GDxON/xUIBCvECFlvmBjEvR4q+NApMR5HOJaSv6V0/413HOJgF4lAWMnHfOL+kxsHzK3v3xxZaCKxDK3lD4glA57C71H4nDeyjNk9szow4+xX3dcFogPhYKOVys3TbswHkuaph9qVRPCSWju+kwAiMaYdjI+86BnpkuDxDXK52KYuZPCm2ntyWAyLgW3i6Do1Hm2fpPkqo4mPqg0r2AekAvfK9LIrNpU8TS+vF4v6o0hN5wLvk8uRsSemJ2eAH5W9oG7wfQ3mKvjQK/s3hMBk1Xfw2+N19rhRbF7QF1plwxPisKOZE+lTtEanRIAAKAx4nVGQsCJE4NCQaAmHns1jg1hPbcUBNDpTZDQMjSAysb3J+1O3V7o4YRsA71abV7lC7Xe02i5YF3l+1A9u3RsE2Khh5Ti+u0SCu9cLaADOFcfJfwq0nsKD2ebPQQ0CPjQAhl+m4bCN5P1pV+KTJeX+dRgGPH+b+bIjPGmwTi1bJLmJpcE+e8ibmgIaBdQj2ldoGnsrccq3kbQknhgUY9HU5QExfwGLBlxJOL5eQGxYcLZbuxhzgMc57myDn/XUaBSrvAQFDfNZgGAVzeFQsDewFODDtO8G7H4VptbfUzuGATJCnKovhpu2NEHsZvCjQQ25O6OexWICwB1jMBD9SLK7rIWOsJ+lwBzZ7sCCrY7ng/cuxSNRpFDGaiD9uGsy02tXF9T1qZ3phbXCTNPhNSOgFFiVdcNAxB2fcegIVGMC953tjMO+f790zmIvGXK4Y0V5j0WNXiee3LfB+3uRk+tIocGKhKbD+cg3CgYbBi+9R2Ny7Xs27ZjD6pdac2ZwtVkC8Gwi4UfjX96n96t07VpHyc7xN79KM9abwaiF8a9LdsYQU10n1M5MG7z+XReI5sediTowcxvnOg8Tio2dtAixwQwfuABwXp7CYyQ5ipxTguMBeyFMSrqcOfFPuDniQ68U2yHBmBF4nbGagQvrAP4wXfSJ2Hsr3Z08VYSHcsZDPOECsEWJPJLZId3sf74il4aZwoZGMQc93MYsts1jiG0MoQ5QJDqh9qPax2KiItVJdYmWfYqFYebrfHH/Rs8KhMg5V65BFLGTC34gyS4Hn/Y3HThg1E/PEFpBNw4XYBTxSToo23tEl2PRFp+3zEt37wPnSizLBUY6q1hsCa4OmwQiUWm+0CUbW41hsmNj0c2kBR+9RyeHJzBlJMeodwmJXYMfbn1ZVsbuM7q5L0YteomAF6Vd+5irO9ewsBryOoal6p6QyzOD/IpoGW/joWfoE3L6TGBH/r6COhU5Ggzr1rzXghq067zMpVpL8Xdy22UrCezwDadxREZ9Yxd+DhYGBpZHvpXw6F9PzvqwXBwY64VWxjWHsUTwstgk4cf4FkKKfcSfbuMoAAAAASUVORK5CYII=>

[image6]: <data:image/png;base64,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>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABMAAAAXCAYAAADpwXTaAAAAjklEQVR4XmNgGAWjgGjAAsST0AXRwF50AVxgFboAFvANXQAbYATiZ+iCWIA6EJehC6KDv+gCeMBSIDZHFwSBBCD+D8QmJOJrQLyPAQ1UMkAM8yMRgwwDYVCkYYA/6AJ4wEQg9kYXRAYgG+6iC2IBikDciS6IDWxBF8ACPqEL4AJsQNyPLogGDqMLjILhBgAQJRjl3POdFQAAAABJRU5ErkJggg==>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAAXCAYAAADQpsWBAAAAcklEQVR4XmNgGAUoQA9dAAsQAWJGZIHpyBwcIAuIJZAFBrmmmcgcHABD0xxkDg6QDcRiyALzkDk4QC4Q8yMLLEfm4ABN6AL/0QWwgH/oAkJA/BNdEApYgPgHEFuiS8DAOQaIrSD6KpT9HIjZkRWNAkoAABULEr1cSEh4AAAAAElFTkSuQmCC>

[image9]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABMAAAAXCAYAAADpwXTaAAAAVUlEQVR4XmNgGAWjgKpgL7oAJeAfugAlwAaIy9AFKQHngNgcXRAETMjEt4B4HwMa8CMTX4NiFgYKwUQg9kYXJAcoAnEnuiC54BO6ACXgMLrAKBhuAACnlhESw2iRqwAAAABJRU5ErkJggg==>

[image10]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEEAAAAYCAYAAACldpB6AAAB/0lEQVR4Xu2Xuy9FQRDGRwiRINGISggdhVItCoJOoVL4F5QKCY0IiUIkHvEuhEaPQjwKlRCEKDQoxCuI92PG7p7smTN771Xcc5v9JV+x38zumd1z7+4eAI/H43EziHpA/Wi9oG5QH5ZXbpIzQCfqCvWJ6mexZAyBqv8dVcViImbCnDVQfiUPxMAy6tJqL6BurXYiqOYx1m6x2iKUtM1NpB5U7JAHYoCemyN4jczj7EP0hbYJXoh2UAkNPICMg4rNMD/dDINcNHln3GRIv+pC7dUxP+AIop0M0oBxQP9j6bmp1OPKIW+RmwapUy2ozeic+XEh1US4fBspp0J7B8wPoCCdCLuoPdSb9vLspCTMOzSHmkVNo6ZQk6gJ3ScR0kQIl2+zAdGcUe09M/8Psx/QBmhzrP1M4Zqsy+dQjjlSs1Bb2lsPMixOQB6UBiC/hAdigv6KUl2pLgJB9wR6832oMlD9ekMZGtegT6B8WsVUGPinkrEKcl3kfXMzBZpA9c3mAYICO9wE9+LERSnIzyevi3k9rN0BKs/e065B7XURukElt/IARBdBKijd0Bu3j7RmiNaxor0lyzPzMhetat3ODTKQEdQj6g7UqXCP+rITkBpQHenaSt8TdNnIBHRfOEVtgqqnIByGYtQFqoj5r6C+f+iaTftLfjjs8Xg8Ho9H4BdIlKYEqCNCdwAAAABJRU5ErkJggg==>

[image11]: <data:image/png;base64,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>