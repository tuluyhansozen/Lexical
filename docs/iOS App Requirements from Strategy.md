# **Software Requirements Specification: Next-Generation Lexical Acquisition System**

## **1\. Introduction and Strategic Context**

### **1.1 Purpose and Strategic Alignment**

The objective of this Software Requirements Specification (SRS) is to articulate the comprehensive functional and non-functional requirements for the development of the "Target System," a next-generation English vocabulary acquisition application for the iOS platform. This document translates the high-level strategic vision outlined in the *English Vocabulary App Development Strategy* into a rigorous technical blueprint suitable for engineering implementation.1

The prevailing market for Mobile Assisted Language Learning (MALL) has bifurcated into two distinct but incomplete methodological camps. On one side, mass-market applications like Duolingo prioritize "gamified habit formation" through aggressive engagement mechanics, often at the expense of pedagogical depth and long-term retention for advanced learners.1 On the other, niche tools like Anki provide powerful retention engines based on Spaced Repetition Systems (SRS) but suffer from high-friction user interfaces and a lack of contextual learning features, limiting their adoption to highly motivated autodidacts.1

The Target System defined herein aims to bridge this chasm by implementing a "Personalized Lexical Ecosystem".1 This system is designed specifically to address the "intermediate plateau," a critical phase where learners possess basic vocabulary but fail to bridge the gap between passive recognition and active retrieval in spontaneous conversation. To achieve this, the application architecture must synthesize three historically distinct domains: the mathematical precision of algorithmic retention (SRS), the immersive depth of Contextual Incidental Learning, and the structural clarity of Morphological Analysis.1

This specification serves as the primary governing document for the development lifecycle, guiding system architecture, user interface design, and quality assurance processes. It adheres to the principles of ISO/IEC/IEEE 29148:2018 for software requirements 4, ensuring that all specifications are verifiable, unambiguous, and traceable to the core strategic goals of reducing friction and maximizing lexical growth.7

### **1.2 Scope of the System**

The Target System is an offline-first, mobile-centric application ecosystem that extends beyond the traditional app sandbox. The scope encompasses the primary iOS application, a suite of Interactive Widgets for the Home Screen and Lock Screen, a Safari Web Extension for content ingestion, and a robust backend synchronization service.

The system scope is delimited by the following core functional boundaries:

* **Algorithmic Retention Engine:** A dynamic scheduling system replacing static intervals with the Free Spaced Repetition Scheduler (FSRS) to model memory stability and retrievability.1  
* **Contextual Acquisition Interface:** An "Immersive Reader" and "Tap-to-Capture" system that categorizes vocabulary state (New, Learning, Known) in real-time, integrating "rich, authentic input" from external sources such as web articles and subtitles.1  
* **Interactive Widget Ecosystem:** A "Home Screen Offensive" strategy utilizing iOS 17+ interactive widgets to facilitate micro-learning sessions (5-10 seconds) without requiring full application launch, thereby reducing the barrier to entry for study.1  
* **Intelligent Engagement Architecture:** A machine-learning-driven notification system employing "Bandit Algorithms" and "Interruptibility Modeling" to optimize engagement timing and message content, mitigating notification fatigue.1  
* **Distributed Data Synchronization:** An offline-first data architecture utilizing Conflict-free Replicated Data Types (CRDTs) to ensure data consistency across devices without central locking, supporting the user's movement between iPhone, iPad, and potentially other platforms.1  
* **Generative Content Production:** Integration of Large Language Models (LLMs) and Neural Text-to-Speech (TTS) to generate context-rich flashcards, mnemonic aids, and high-fidelity audio pronunciations.1

### **1.3 Definitions, Acronyms, and Abbreviations**

To ensure consistent interpretation of requirements, the following domain-specific terms are defined:

* **SRS (Spaced Repetition System):** A learning technique that schedules review of information at increasing intervals to exploit the psychological spacing effect.1  
* **FSRS (Free Spaced Repetition Scheduler):** A modern, open-source SRS algorithm that calculates review intervals based on Retrievability (![][image1]), Stability (![][image2]), and Difficulty (![][image3]), offering superior predictive accuracy over the legacy SM-2 algorithm.8  
* **CRDT (Conflict-free Replicated Data Type):** A data structure that allows multiple replicas to be updated independently and concurrently without coordination, mathematically guaranteeing eventual consistency upon merging.13  
* **Lemma:** The canonical form or morphological root of a word (e.g., "run" is the lemma for "running," "ran," "runs"). Tracking at the lemma level prevents fragmented learning.1  
* **MALL (Mobile Assisted Language Learning):** The use of handheld mobile technology to assist in language learning.1  
* **Cloze Deletion:** A flashcard format where a portion of a sentence is occluded (e.g., "The cat sat on the \[\_\_\_\_\_\]"), requiring the user to retrieve the missing word based on context.1  
* **App Intent:** A system framework in iOS that allows widgets to perform actions (like updating a database) in the background without launching the main application.18  
* **Bandit Algorithm (MAB):** A reinforcement learning model (Multi-Armed Bandit) used to dynamically allocate traffic or notifications to the most effective variant based on real-time feedback.19

### **1.4 References**

This specification relies on the following primary documents and standards:

1. *English Vocabulary App Development Strategy.docx* (Strategic Roadmap).1  
2. *ISO/IEC/IEEE 29148:2018 Systems and software engineering — Life cycle processes — Requirements engineering*.4  
3. *Free Spaced Repetition Scheduler (FSRS) Algorithm Specification*.8  
4. *Apple Developer Documentation: WidgetKit and App Intents*.20  
5. *Conflict-free Replicated Data Types: A Primer*.13

## ---

**2\. Overall Description**

### **2.1 Product Perspective**

The Target System functions as a "Personalized Lexical Ecosystem" rather than a standalone utility. It operates within the constraints of the Apple iOS ecosystem while maintaining an architecture that supports future cross-platform expansion. The system interacts with several external entities:

* **The User:** Specifically, intermediate to advanced learners who have exhausted the utility of beginner apps and require tools for deep acquisition.1  
* **External Content Sources:** Web browsers (via Safari Extension) and media players (Netflix/YouTube) from which the system must ingest text and subtitles.1  
* **Linguistic Databases:** External APIs or embedded databases for morphological roots, etymology, and corpus frequency data (e.g., COCA, WordsAPI).1  
* **Generative AI Services:** Cloud-based LLMs for generating semantic context, mnemonics, and example sentences.1

### **2.2 User Characteristics**

The primary user persona, referred to as the "Plateaued Learner," exhibits specific behavioral traits that drive the system requirements:

* **High Motivation, Low Time:** They are willing to study but struggle to find dedicated blocks of time. This necessitates the "Micro-Dose" widget strategy.1  
* **Content Driven:** They prefer reading authentic material (news, books) over artificial textbook exercises. This validates the need for the "Importer Bridge".1  
* **Data Sensitive:** They are discouraged by the loss of progress or "broken streaks," requiring sophisticated "streak defense" mechanisms in the notification architecture.1  
* **Analytical:** They value understanding the *structure* of language (roots, prefixes) rather than just rote memorization, supporting the inclusion of the Morphological Engine.1

### **2.3 Assumptions and Dependencies**

* **Assumption:** The user has an active internet connection for the initial "Capture" phase to query LLMs and dictionaries, but the "Review" phase must remain fully functional offline.1  
* **Dependency:** The system relies on the stability of iOS App Groups to share data between the main app, widgets, and share extensions.24  
* **Dependency:** The efficacy of the FSRS algorithm depends on the accumulation of user review history; the "cold start" period must be managed with sensible default parameters.9

## ---

**3\. Functional Requirements: The Retention Engine (SRS)**

The Retention Engine acts as the central nervous system of the application. It dictates the scheduling of every vocabulary item, ensuring that the user's cognitive load is optimized for maximum retention efficiency. Unlike traditional systems that use static intervals, the Target System must implement a dynamic, adaptive scheduler.

### **3.1 The FSRS Algorithm Implementation**

The system shall implement the Free Spaced Repetition Scheduler (FSRS) version 4 or higher. This model replaces the single "Ease Factor" of SM-2 with a three-component model of memory: Retrievability (![][image1]), Stability (![][image2]), and Difficulty (![][image3]).1

#### **3.1.1 Memory State Variables**

The system must maintain a persistent record of the memory state for every unique lemma-context pair.

* **Retrievability (![][image1]):** Defined as the probability that the user can successfully recall the item at a given moment ![][image4]. It decays over time according to the forgetting curve. The system must calculate ![][image1] using the power approximation developed for FSRS: ![][image5] Where ![][image4] is the time elapsed since the last review and ![][image2] is the stability.8  
* **Stability (![][image2]):** Defined as the interval (in days) required for ![][image1] to drop from 100% to a requested retention level (e.g., 90%). Stability increases with successful recall and decreases with forgetting.25  
* **Difficulty (![][image3]):** A value constrained between 1 and 10 representing the intrinsic complexity of the item. This variable modulates how quickly Stability increases; harder items gain stability more slowly than easy items.8

#### **3.1.2 The Scheduling Loop**

The system shall calculate the optimal next interval (![][image6]) for any item based on the user's "Desired Retention" parameter (![][image7]), which defaults to 0.90 (90%).1

* The interval calculation must satisfy the equation where current Retrievability equals Desired Retention:  
  ![][image8]  
* This formula ensures that the interval expands precisely enough to allow retrievability to drop to 90%, maximizing the "desirable difficulty" of the next review.1

#### **3.1.3 Review Grading and State Updates**

Upon the completion of a review, the user must provide a grade (![][image9]) from the set {Again, Hard, Good, Easy}. The system must update ![][image2] and ![][image3] immediately using the FSRS difference equations 8:

* **Difficulty Update:** ![][image10]. The system must apply mean reversion logic to prevent "Ease Hell," ensuring ![][image3] does not drift permanently to extremes.16  
* **Stability Update (Recall):** If ![][image11] (Success), Stability grows geometrically: ![][image12] Where ![][image13] is a function of Difficulty, current Stability, and Retrievability. This ensures that recalling a "Hard" item (high ![][image3]) that was on the verge of being forgotten (low ![][image1]) yields the massive "memory boost" predicted by cognitive science.8  
* **Stability Update (Forgetting):** If ![][image14] (Failure), Stability must be penalized drastically but not reset to zero, accounting for "residual savings" in memory.8

### **3.2 The "Brain Boost" Triage Queue**

Standard SRS algorithms often fail to handle immediate failures effectively, simply scheduling them for "tomorrow." The Target System shall implement a "Brain Boost" mechanism for short-term distributed practice.1

#### **3.2.1 Queue Logic**

* **Trigger Condition:** When a user grades an item as "Again" (1) or "Hard" (2).  
* **Injection:** The item is placed into a high-priority "Short-Term Queue" separate from the main SRS database.  
* **Reappearance Strategy:** The item must reappear within the *same* study session.  
  * **Spacing:** Ideally 3–5 items later. If the queue is empty, a 60-second timer blocks the reappearance to prevent massed practice (cramming).1  
* **Graduation:** An item is only promoted back to the long-term FSRS queue after two consecutive successful recalls ("Good" or "Easy") within the Brain Boost loop.

#### **3.2.2 Session Visualization**

The interface must distinguish between "Reviewing" (Long-term SRS) and "Learning" (Short-term Brain Boost). A specialized progress indicator (e.g., a circular "Loading" animation around the card) shall provide visual feedback on the item's graduation status from the Brain Boost queue.1

### **3.3 Atomic Lemma Tracking**

The system must track vocabulary at the lemma level to prevent redundancy.

* **Root Identification:** When a user captures "running," the system must perform stemming/lemmatization to identify "run" as the root.  
* **State Inheritance:** If "run" is already "Known," the system shall prompt the user: "You already know 'run'. Do you want to add 'running' as a separate card?" This minimizes database bloat and focuses the user on truly new concepts.1  
* **Family Updates:** Reviewing a derived form (e.g., "unhappiness") should contribute a fractional stability increase to the root ("happy"), reflecting the interconnected nature of the mental lexicon.1

## ---

**4\. Functional Requirements: Acquisition Mechanics (The Reader)**

The Acquisition Engine focuses on the *input* phase of learning. It moves beyond isolated flashcards to the consumption of "rich, authentic input" via an Immersive Reader.1

### **4.1 "Tap-to-Capture" and Visual Status**

The Reader interface must parse text content and overlay visual indicators of vocabulary status.

#### **4.1.1 Vocabulary State Taxonomy**

Every unique word in a document must be classified into one of three states 1:

1. **New (Blue):** The word does not exist in the user's database. These words are actionable targets for acquisition.  
2. **Learning (Yellow):** The word exists in the FSRS queue with a Stability ![][image15] days.  
3. **Known (White/Unmarked):** The word is either explicitly marked "Known" or has a Stability ![][image16] days (or has been implicitly ignored).

#### **4.1.2 Status Transition Logic**

* **Initial Parse:** Upon loading an article, the system must tokenize the text and query the local database (Core Data/SwiftData) for the status of each token. This operation must be performed on a background thread to prevent UI freezing, with results applied asynchronously to the text view.26  
* **User Action (Capture):** Tapping a "Blue" word opens a bottom sheet "Capture Card." Confirming the capture transitions the word to "Yellow" instantly across the entire document and any other open documents.1  
* **User Action (Ignore):** Users must have a "Mark Page Known" gesture (e.g., scroll to bottom confirmation) that converts all remaining "Blue" words to "Known" (White) to simulate passive vocabulary growth.27

### **4.2 Contextual Flashcard Generation ("Smart Cards")**

Mere word-definition pairs are insufficient for deep learning. The system must capture the *provenance* of the vocabulary.1

#### **4.2.1 Sentence Extraction**

When a word is captured, the system must identify the sentence boundaries (using Natural Language Processing NLTokenizer) and store the full sentence as the source\_context.

* **Cloze Formatting:** The system shall automatically generate a display string where the target word is replaced by an underscore or blank (e.g., "The \[\_\_\_\_\_\] is ephemeral.").1

#### **4.2.2 Multimedia Context**

* **Video Anchoring:** If the source is a video (YouTube/Netflix via Extension), the system must capture the timestamp (start/end). The flashcard "Front" shall embed a looping video player restricted to that specific 5-second interval, providing prosodic and visual cues.1  
* **Audio Synthesis:** For text sources, the system must generate high-quality audio for the sentence (not just the word) using AVSpeechSynthesizer or OpenAI TTS, ensuring the user hears the word in connected speech.1

### **4.3 Corpus Intelligence and Filtering**

To guide users away from the "low-frequency trap," the system integrates corpus data.1

#### **4.3.1 Frequency Banding**

Every captured word must be cross-referenced against a locally stored frequency list (e.g., COCA Top 60,000).

* **Visual Indicators:** The "Capture Card" must display the word's frequency rank (e.g., "Top 2000" or "Academic Word List").  
* **Nudge Architecture:** If a beginner (User Level \< A2) attempts to capture a word ranked \>20,000, the system shall display a warning: "This is a rare word. Recommended for C1/C2 learners." This prevents users from filling their SRS queue with obscure terms like "defenestrate" before knowing "window".1

#### **4.3.2 Collocation Detection**

The system must identify multi-word expressions. If the user taps "decision," and the text reads "make a decision," the NLP parser must identify "make a decision" as a statistically significant collocation and offer to save the phrase instead of the isolated noun. This encourages "chunking," a key strategy for fluency.1

## ---

**5\. Functional Requirements: Interactive Widget Ecosystem**

The "Home Screen Offensive" aims to reduce the friction of study by moving interaction outside the app sandbox.1 The system shall utilize iOS 17+ WidgetKit and App Intents to create a suite of interactive tools.

### **5.1 Widget Architecture**

The widgets must operate independently of the main app lifecycle, sharing data via an **App Group** container.

#### **5.1.1 The "Micro-Dose" Flashcard Widget**

* **Goal:** Enable "interstitial learning" (waiting for coffee/bus).1  
* **UI State 1 (Prompt):** Displays the Cloze Sentence. A "Reveal" button is the primary call to action.  
  * *Constraint:* Due to non-scrolling limitations 11, text must be truncated intelligently. The system should prefer short sentences (\<100 chars) for widget display.  
* **UI State 2 (Response):** Displays the answer and grading buttons (Again, Hard, Good, Easy).  
* **Interaction Logic:** Tapping a grade button triggers an AppIntent that:  
  1. Calculates the new FSRS memory state (![][image17]).  
  2. Updates the database in the shared App Group.  
  3. Calls WidgetCenter.shared.reloadTimelines() to fetch the next card immediately.3  
  4. Updates the daily "Review Count" statistic.

#### **5.1.2 The "Word of the Day" (WOTD) Widget**

* **Smart Rotation:** The widget shall not be static. It must rotate the displayed word based on user interaction.  
  * *Save Action:* An interactive "Plus" icon allows immediate capture to the SRS queue.1  
  * *Refresh Logic:* If the user ignores the word (no interaction for 6 hours), the timeline provider rotates to a new high-frequency word.21  
* **Audio Playback:** The widget must include a "Speaker" icon.  
  * *Constraint:* Widgets cannot host complex audio players. The system must use AudioPlaybackIntent to play a pre-cached audio file from the shared container background process.24 This is critical for pronunciation without app launch.

#### **5.1.3 The Streak Keeper Widget**

* **Visual Urgency:** The widget uses color-coded visualizations to leverage "Loss Aversion".1  
  * *Green Ring:* Daily goal complete.  
  * *Orange Ring:* Goal in progress.  
  * *Cracking/Red Icon:* Streak at risk (\<4 hours remaining).  
* **Lock Screen Accessory:** A minimal circular widget on the Lock Screen showing only the numeric streak count, serving as a constant subconscious nudge.1

## ---

**6\. Functional Requirements: Notification Architecture**

To solve "notification fatigue," the system employs a machine-learning-driven scheduler known as the **Bandit Notification System**.1

### **6.1 The Bandit Algorithm (Reinforcement Learning)**

The notification engine determines *what* to send and *when* to send it based on maximizing the "Open Rate" reward function.1

#### **6.1.1 Strategy Arms (Content Templates)**

The system shall treat notification templates as "arms" in a Multi-Armed Bandit problem:

* **Arm A (Streak Defense):** "🔥 Danger\! Your 50-day streak ends in 2 hours." (Trigger: Loss Aversion).30  
* **Arm B (Curiosity Gap):** "Do you know the English word for 'Schadenfreude'?" (Trigger: Curiosity).1  
* **Arm C (Ego/Validation):** "You're in the top 10% of learners this week." (Trigger: Social Proof).  
* **Arm D (Passive-Aggressive):** "We haven't seen you in a while. We'll stop bothering you." (Trigger: Reverse Psychology).1

#### **6.1.2 Exploration vs. Exploitation**

The algorithm (e.g., Epsilon-Greedy or Thompson Sampling) shall:

* **Exploit:** Send the historically best-performing template type (highest Open Rate) 80% of the time.  
* **Explore:** Send a random template type 20% of the time to discover shifting user preferences.31  
* **Adaptation:** If a user stops opening "Streak" notifications, the algorithm downgrades that arm's probability and pivots to "Curiosity" messages automatically.19

### **6.2 Interruptibility Modeling (Core Motion)**

Static scheduling (e.g., "Always at 6 PM") is inefficient. The system must use **Context Awareness** to find the optimal moment to interrupt.1

#### **6.2.1 State Transition Detection**

The system shall utilize the Core Motion framework (specifically CMMotionActivityManager) to detect user state transitions.34

* **Target State:** The optimal moment for a micro-session is the transition from "Active" (Walking/Automotive) to "Stationary." This correlates with arriving home or sitting down on a commute.  
* **Battery Optimization:** To prevent battery drain, the app shall *not* poll continuously. It will use "Significant Location Change" or Background App Refresh tasks to perform a low-power check of the motion history. If a transition occurred in the last 15 minutes, the notification is triggered.36

#### **6.2.2 Frequency Capping**

To prevent app deletion, the system must enforce strict "Cool Down" periods. If the user ignores three consecutive notifications (Reward \= 0), the system must enter a "Silence Mode" for 48 hours.1

## ---

**7\. Functional Requirements: Content Ingestion (Importer Bridge)**

The "Importer Bridge" allows the system to ingest content from the user's digital environment, solving the issue of limited content availability.1

### **7.1 Safari Web Extension**

A simple "Share Extension" is insufficient for interactive reading. The system requires a full **Safari Web Extension** capable of DOM manipulation.38

#### **7.1.1 Architecture**

* **Content Script (content.js):** Injected into every visited webpage (user configurable). It parses the visible text and compares it against a bloom filter or compressed dictionary of the user's "Known Words".39  
* **DOM Manipulation:** The script wraps "New" (Blue) and "Learning" (Yellow) words in \<span\> tags with specific CSS classes to apply highlighting overlays directly on the NYTimes or Wikipedia page.39  
* **Interaction:** Tapping a highlighted word inside Safari triggers a popover (Shadow DOM) that allows the user to capture the word without leaving the browser context.39

### **7.2 Subtitle Extraction Engine**

The extension must detect video players (YouTube, Netflix) and extract subtitle streams.1

* **YouTube Integration:** The script accesses the caption track via the YouTube Player API or by parsing the network traffic for .srv3 or .json caption files.40  
* **Netflix Integration:** Since Netflix subtitles are often image-based or protected, the extension uses OCR or intercepts the \<?o=\> timed text network requests to retrieve the XML/VTT subtitle file.40  
* **Sync:** The captured text is paired with the video timestamp (currentTime) to allow the creation of "Video Flashcards" that loop the specific segment.1

## ---

**8\. Functional Requirements: Data Synchronization (Offline-First)**

The strategy demands a "Personalized Lexical Ecosystem" spanning multiple devices (iPhone, iPad, Mac). This requires a sync architecture that is robust against network partitions.1

### **8.1 The Case for CRDTs**

Traditional "Last-Write-Wins" (LWW) database logic is fatal for SRS applications.

* *Conflict Scenario:* A user reviews 50 cards on an offline iPad (Session A) and 20 different cards on an offline iPhone (Session B).  
* *LWW Failure:* A standard sync might overwrite the database with the "latest" file, losing the reviews from the other device.  
* *Requirement:* The system must use **Conflict-free Replicated Data Types (CRDTs)** to merge these sessions mathematically.13

### **8.2 Data Structures**

* **Review Logs (Append-Only Log):** Each review is an immutable event: {id: UUID, cardId: UUID, grade: Int, timestamp: Date, deviceId: String}.  
  * *Merge Logic:* The sync engine simply unions the sets of review logs from all devices. The FSRS state is recalculated deterministically by replaying the merged log.41  
* **Vocabulary State (LWW-Element-Set):** For the state of a word (New/Learning/Known), an LWW-Element-Set is appropriate. If the user marks a word as "Known" on Friday and "New" on Saturday, the Saturday timestamp wins.14  
* **Streaks (G-Counter):** The daily "cards reviewed" count must use a Grow-only Counter (G-Counter). If Device A counts 10 and Device B counts 20, the merged state is 30 (assuming distinct increments), ensuring credit is given for all work.13

### **8.3 Sync Implementation**

The synchronization layer shall use a Swift-compatible CRDT library (e.g., a port of **Yjs** or **Automerge**, or a custom Swift implementation of **LWW-Set**).42

* **Transport:** Data is exchanged as binary "deltas" or "update vectors" via CloudKit or a custom WebSocket backend, minimizing bandwidth usage.14

## ---

**9\. Functional Requirements: Morphology and Audio**

### **9.1 The Morphology Engine ("Word Matrix")**

The system must visualize the structural relationships between words.1

* **Data Source:** The app must integrate with an etymological database (e.g., Etymonline or Wiktionary parser) to map lemmas to their roots.1  
* **Visualization:** A force-directed graph or "Matrix" view showing the root (e.g., *SPECT*) and its satellites (*inspect, respect, suspect*).  
* **Learning Mechanic:** When a user learns a new root, the system "unlocks" related words in the SRS queue, boosting their initial stability because the user now possesses the "key" to their meaning.1

### **9.2 Text-to-Speech (TTS) Pipeline**

High-quality audio is non-negotiable for pronunciation acquisition.1

* **Hybrid Strategy:**  
  * **Tier 1 (WOTD):** Use server-side Neural TTS (OpenAI tts-1-hd or Azure Neural) for "Word of the Day" content to ensure maximum naturalness.15  
  * **Tier 2 (General):** Use on-device AVSpeechSynthesizer for the infinite content (reader articles). This enables offline playback and zero latency.45  
* **Voice Customization:** Users must be able to select their preferred dialect (US, UK, Australian, Indian English) via the AVSpeechSynthesisVoice API to match their learning goals.45

## ---

**10\. Non-Functional Requirements**

### **10.1 Performance**

* **Widget Latency:** Widget timeline reloads must complete within 500ms of an interaction to maintain the illusion of a "live" app.20  
* **Scroll Performance:** The Reader must maintain 60/120fps scrolling even with hundreds of "Blue/Yellow" highlights. This requires efficient text rendering (e.g., using TextKit 2 or CoreText) rather than heavy HTML web views for local content.

### **10.2 Privacy and Security**

* **Data Minimization:** "Bandit" models and "Interruptibility" checks must run on-device. No raw location or motion data shall ever be uploaded to the cloud.36  
* **Web Extension Safety:** The Safari Extension must request strictly limited permissions. It should not transmit browsing history; it should only send the *text content* of the specific page the user activates the extension on.26

### **10.3 Authentication and Identity**

The system shall implement a robust, privacy-first authentication architecture following iOS best practices for 2025.

#### **10.3.1 Sign in with Apple (Primary)**

* **Mandatory Integration:** "Sign in with Apple" must be the primary authentication method, required by App Store guidelines when other social logins are offered.
* **Credential State Validation:** On every app launch, validate the user's Apple ID credential state using `ASAuthorizationAppleIDProvider.getCredentialState(forUserID:)` to detect revoked credentials.
* **Privacy Respect:** Honor the "Hide My Email" feature; never prompt users to reveal their real email address.
* **Account Linking:** Provide the ability for users to link existing accounts to their Apple ID.

#### **10.3.2 Keychain Security**

* **Token Storage:** All authentication tokens (Apple ID token, CloudKit tokens) must be stored exclusively in the iOS Keychain using `kSecAttrAccessibleWhenUnlocked`.
* **No Insecure Storage:** Sensitive credentials must NEVER be stored in `UserDefaults`, `plist` files, or unencrypted storage.
* **Secure Enclave Integration:** For biometric authentication, cryptographic keys should leverage the Secure Enclave when available.
* **Memory Management:** Wipe sensitive values from memory immediately after use.

#### **10.3.3 Biometric Authentication**

* **Face ID/Touch ID Support:** Use the `LocalAuthentication` framework for optional biometric locks on sensitive actions (e.g., deleting all data, accessing statistics).
* **Fallback Mechanism:** Always provide a device passcode fallback when biometrics fail or are unavailable.
* **User Preference:** Biometric locking must be opt-in via Settings, defaulting to OFF.

#### **10.3.4 Credential Lifecycle Management**

* **Token Refresh:** Implement automatic credential refresh before token expiration; handle refresh failures gracefully by prompting re-authentication.
* **Session Timeout:** Implement configurable session timeout (default: 30 days) after which re-authentication is required.
* **Credential Revocation Detection:** Monitor for Apple ID credential revocation notifications via `ASAuthorizationAppleIDProvider.credentialRevokedNotification`.

#### **10.3.5 Account Deletion (App Store Requirement)**

* **Self-Service Deletion:** Provide an in-app account deletion option accessible from Settings, as required by App Store Review Guidelines 5.1.1(v).
* **Data Purge:** Account deletion must trigger complete purge of user data from local storage AND CloudKit within 30 days.
* **Confirmation Flow:** Require explicit user confirmation with warning about data loss before proceeding with account deletion.

#### **10.3.6 Future: Passkeys Support (Roadmap)**

* **FIDO2/WebAuthn:** Consider implementing Passkeys as an alternative passwordless authentication method for enhanced phishing resistance.
* **Progressive Enhancement:** Layer Passkey functionality over existing Sign in with Apple without removing current authentication methods.

### **10.4 Battery Efficiency**

* **Motion Monitoring:** Use of CMMotionActivityManager must be limited to historical queries or significant change triggers. Continuous background polling is strictly prohibited.36  
* **OLED Optimization:** The "Night Mode" interface must use true black (\#000000) to minimize energy consumption on OLED iPhones.36

## ---

**11\. Appendix: Data Models**

### **11.1 Review Log Schema (CRDT)**

| Field | Type | Description |
| :---- | :---- | :---- |
| id | UUID | Unique identifier for the review event. |
| card\_id | UUID | Foreign key to the Vocabulary Item. |
| grade | Int | 1=Again, 2=Hard, 3=Good, 4=Easy. |
| duration | Int | Time spent viewing the card (ms). |
| timestamp | Int64 | Unix timestamp of the review. |
| device\_id | String | ID of the device creating the record (for vector clocks). |
| algorithm\_ver | String | Version of FSRS used (e.g., "v4.5"). |

### **11.2 Vocabulary Item Schema**

| Field | Type | Description |
| :---- | :---- | :---- |
| lemma | String | The root word (e.g., "run"). |
| stability | Float | FSRS Stability (![][image2]). |
| difficulty | Float | FSRS Difficulty (![][image3]). |
| retrievability | Float | Calculated ![][image1] at last sync. |
| due\_date | Date | Next scheduled review. |
| context\_sentence | String | The sentence captured with the word. |
| source\_url | String | Origin of the capture (for deep linking). |

## ---

**12\. Conclusion**

The "Target System" described in this specification represents a significant advancement in MALL technology. By integrating the FSRS algorithm, it optimizes the *timing* of learning. By employing Interactive Widgets and Bandit Notifications, it optimizes the *engagement* of learning. By using Safari Extensions and Video Parsers, it optimizes the *content* of learning. Finally, by utilizing CRDTs, it ensures a robust, offline-first experience that respects the user's data across their entire digital ecosystem. This architecture directly addresses the strategic goal of solving the "intermediate plateau" through a synthesis of rigorous engineering and pedagogical science.

#### **Alıntılanan çalışmalar**

1. English Vocabulary App Development Strategy.docx  
2. iOS 17 Brings Interactive Widgets, Contact Posters, StandBy, and More, erişim tarihi Ocak 24, 2026, [https://twit.tv/posts/tech/ios-17-brings-interactive-widgets-contact-posters-standby-and-more-look-top-new-features](https://twit.tv/posts/tech/ios-17-brings-interactive-widgets-contact-posters-standby-and-more-look-top-new-features)  
3. How to use interactive widgets in iOS 17 \- AppleInsider, erişim tarihi Ocak 24, 2026, [https://appleinsider.com/inside/ios-17/tips/how-to-use-interactive-widgets-in-ios-17](https://appleinsider.com/inside/ios-17/tips/how-to-use-interactive-widgets-in-ios-17)  
4. Write an SRS document: How-tos, templates, and tips \- Canva, erişim tarihi Ocak 24, 2026, [https://www.canva.com/docs/srs-document/](https://www.canva.com/docs/srs-document/)  
5. ISO/IEC/IEEE 29148 Systems and Software Requirements ..., erişim tarihi Ocak 24, 2026, [https://www.well-architected-guide.com/documents/iso-iec-ieee-29148-template/](https://www.well-architected-guide.com/documents/iso-iec-ieee-29148-template/)  
6. ISO/IEC/IEEE 29148:2018 \- iTeh Standards, erişim tarihi Ocak 24, 2026, [https://cdn.standards.iteh.ai/samples/72089/62bb2ea1ef8b4f33a80d984f826267c1/ISO-IEC-IEEE-29148-2018.pdf](https://cdn.standards.iteh.ai/samples/72089/62bb2ea1ef8b4f33a80d984f826267c1/ISO-IEC-IEEE-29148-2018.pdf)  
7. Markdown Software Requirements Specification (MSRS) \- GitHub, erişim tarihi Ocak 24, 2026, [https://github.com/jam01/SRS-Template](https://github.com/jam01/SRS-Template)  
8. The Algorithm · open-spaced-repetition/fsrs4anki Wiki \- GitHub, erişim tarihi Ocak 24, 2026, [https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm](https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm)  
9. The FSRS Spaced Repetition Algorithm \- RemNote Help Center, erişim tarihi Ocak 24, 2026, [https://help.remnote.com/en/articles/9124137-the-fsrs-spaced-repetition-algorithm](https://help.remnote.com/en/articles/9124137-the-fsrs-spaced-repetition-algorithm)  
10. updated version of extracting/downloading subtitles from netflix for ..., erişim tarihi Ocak 24, 2026, [https://www.jordangeorge.com/blog/updated-version-of-extractingdownloading-subtitles-from-netflix-for-language-learning](https://www.jordangeorge.com/blog/updated-version-of-extractingdownloading-subtitles-from-netflix-for-language-learning)  
11. The best iOS 17 apps with interactive widgets, StandBy support, and ..., erişim tarihi Ocak 24, 2026, [https://www.reddit.com/r/apple/comments/16ngruw/the\_best\_ios\_17\_apps\_with\_interactive\_widgets/](https://www.reddit.com/r/apple/comments/16ngruw/the_best_ios_17_apps_with_interactive_widgets/)  
12. How to download subtitle files from ANY website \- YouTube, erişim tarihi Ocak 24, 2026, [https://www.youtube.com/watch?v=8c8AU\_FDmX8](https://www.youtube.com/watch?v=8c8AU_FDmX8)  
13. What are CRDTs \- Loro.dev, erişim tarihi Ocak 24, 2026, [https://loro.dev/docs/concepts/crdt](https://loro.dev/docs/concepts/crdt)  
14. Build an Offline-First iOS App with Conflict-Free Sync (CRDTs in Swift), erişim tarihi Ocak 24, 2026, [https://medium.com/@aditya877633/build-an-offline-first-ios-app-with-conflict-free-sync-crdts-in-swift-e3cdb0d787e7](https://medium.com/@aditya877633/build-an-offline-first-ios-app-with-conflict-free-sync-crdts-in-swift-e3cdb0d787e7)  
15. Text to speech | OpenAI API, erişim tarihi Ocak 24, 2026, [https://platform.openai.com/docs/guides/text-to-speech](https://platform.openai.com/docs/guides/text-to-speech)  
16. A technical explanation of FSRS | Expertium's Blog \- GitHub Pages, erişim tarihi Ocak 24, 2026, [https://expertium.github.io/Algorithm.html](https://expertium.github.io/Algorithm.html)  
17. Conflict-free replicated data type \- Wikipedia, erişim tarihi Ocak 24, 2026, [https://en.wikipedia.org/wiki/Conflict-free\_replicated\_data\_type](https://en.wikipedia.org/wiki/Conflict-free_replicated_data_type)  
18. Interactive Widgets — iOS 17 \- lyvennitha sasikumar, erişim tarihi Ocak 24, 2026, [https://lyvennithasasikumar.medium.com/interactive-widgets-ios-17-e02a42a15414](https://lyvennithasasikumar.medium.com/interactive-widgets-ios-17-e02a42a15414)  
19. AI Decisioning with Contextual Bandits \- Braze, erişim tarihi Ocak 24, 2026, [https://www.braze.com/resources/articles/contextual-bandits](https://www.braze.com/resources/articles/contextual-bandits)  
20. Hands-on: iOS 17 adds interactive widgets for the Home app ..., erişim tarihi Ocak 24, 2026, [https://sydneycbd.repair/hands-on-ios-17-adds-interactive-widgets-for-the-home-app/](https://sydneycbd.repair/hands-on-ios-17-adds-interactive-widgets-for-the-home-app/)  
21. iOS 17 and iPadOS 17 Now Available With New Features ... \- AppleVis, erişim tarihi Ocak 24, 2026, [https://www.applevis.com/blog/ios-17-ipados-17-now-available-new-features-accessibility-enhancements](https://www.applevis.com/blog/ios-17-ipados-17-now-available-new-features-accessibility-enhancements)  
22. A Sleeping, Recovering Bandit Algorithm for Optimizing Recurring ..., erişim tarihi Ocak 24, 2026, [https://research.duolingo.com/papers/yancey.kdd20.pdf](https://research.duolingo.com/papers/yancey.kdd20.pdf)  
23. WordsAPI API \- PublicAPI, erişim tarihi Ocak 24, 2026, [https://publicapi.dev/words-api](https://publicapi.dev/words-api)  
24. iOS 17 Beta Shared AVAudioPlayer State Between App and Widget, erişim tarihi Ocak 24, 2026, [https://stackoverflow.com/questions/77052698/ios-17-beta-shared-avaudioplayer-state-between-app-and-widget](https://stackoverflow.com/questions/77052698/ios-17-beta-shared-avaudioplayer-state-between-app-and-widget)  
25. What spaced repetition algorithm does Anki use?, erişim tarihi Ocak 24, 2026, [https://faqs.ankiweb.net/what-spaced-repetition-algorithm](https://faqs.ankiweb.net/what-spaced-repetition-algorithm)  
26. Your browser extension may be watching your bank activity: Here’s how to stop it, erişim tarihi Ocak 24, 2026, [https://indianexpress.com/article/technology/your-browser-extension-may-be-watching-your-bank-activity-10490872/](https://indianexpress.com/article/technology/your-browser-extension-may-be-watching-your-bank-activity-10490872/)  
27. Widgetsmith 5: Interactive Widgets for iOS 17 \- David-Smith.org, erişim tarihi Ocak 24, 2026, [https://www.david-smith.org/blog/2023/09/18/widgetsmith-5-interactive-widgets/](https://www.david-smith.org/blog/2023/09/18/widgetsmith-5-interactive-widgets/)  
28. iOS and iPadOS 17: The MacStories Review \- Page 3 of 17, erişim tarihi Ocak 24, 2026, [https://www.macstories.net/stories/ios-and-ipados-17-the-macstories-review/3/](https://www.macstories.net/stories/ios-and-ipados-17-the-macstories-review/3/)  
29. iOS 17: A Comprehensive Guide to the Features & Innovations, erişim tarihi Ocak 24, 2026, [https://www.techaheadcorp.com/blog/exploring-ios-17-a-comprehensive-guide-to-the-latest-features-innovations/](https://www.techaheadcorp.com/blog/exploring-ios-17-a-comprehensive-guide-to-the-latest-features-innovations/)  
30. CRDTs Demystified: The Secret Sauce Behind Seamless ... \- Medium, erişim tarihi Ocak 24, 2026, [https://medium.com/@isaactech/crdts-demystified-the-secret-sauce-behind-seamless-collaboration-3d1ad38ad1cd](https://medium.com/@isaactech/crdts-demystified-the-secret-sauce-behind-seamless-collaboration-3d1ad38ad1cd)  
31. Understanding Contextual Bandits: Advanced Decision-Making in ..., erişim tarihi Ocak 24, 2026, [https://medium.com/@kapardhikannekanti/understanding-contextual-bandits-advanced-decision-making-in-machine-learning-85c7c20417d7](https://medium.com/@kapardhikannekanti/understanding-contextual-bandits-advanced-decision-making-in-machine-learning-85c7c20417d7)  
32. Contextual Bandits for In-App Recommendation, erişim tarihi Ocak 24, 2026, [https://engineering.nordeus.com/contextual-bandits-for-in-app-recommendation/](https://engineering.nordeus.com/contextual-bandits-for-in-app-recommendation/)  
33. What is CRDT in Distributed Systems? \- GeeksforGeeks, erişim tarihi Ocak 24, 2026, [https://www.geeksforgeeks.org/r-language/what-is-crdt-in-distributed-systems/](https://www.geeksforgeeks.org/r-language/what-is-crdt-in-distributed-systems/)  
34. What's New in Core Motion \- WWDC15 \- Videos \- Apple Developer, erişim tarihi Ocak 24, 2026, [https://developer.apple.com/videos/play/wwdc2015/705/](https://developer.apple.com/videos/play/wwdc2015/705/)  
35. How to use Core Motion in iOS using Swift | by Maksym Bilan | Medium, erişim tarihi Ocak 24, 2026, [https://maximbilan.medium.com/how-to-use-core-motion-in-ios-using-swift-1287f7422473](https://maximbilan.medium.com/how-to-use-core-motion-in-ios-using-swift-1287f7422473)  
36. Measure Energy Impact with Instruments \- Apple Developer, erişim tarihi Ocak 24, 2026, [https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/MonitorEnergyWithInstruments.html](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/MonitorEnergyWithInstruments.html)  
37. Do motion zones on battery devices impact battery life? : r/Ring, erişim tarihi Ocak 24, 2026, [https://www.reddit.com/r/Ring/comments/k34b7o/do\_motion\_zones\_on\_battery\_devices\_impact\_battery/](https://www.reddit.com/r/Ring/comments/k34b7o/do_motion_zones_on_battery_devices_impact_battery/)  
38. Safari app extension VS Safari web extension \- Medium, erişim tarihi Ocak 24, 2026, [https://medium.com/@gbraghin/safari-app-extension-vs-safari-web-extension-5615902bc7cd](https://medium.com/@gbraghin/safari-app-extension-vs-safari-web-extension-5615902bc7cd)  
39. Meet Safari Web Extensions on iOS | Documentation \- WWDC Notes, erişim tarihi Ocak 24, 2026, [https://wwdcnotes.com/documentation/wwdcnotes/wwdc21-10104-meet-safari-web-extensions-on-ios/](https://wwdcnotes.com/documentation/wwdcnotes/wwdc21-10104-meet-safari-web-extensions-on-ios/)  
40. Guide: How to download subtitles from Netflix using Google Chrome, erişim tarihi Ocak 24, 2026, [https://www.reddit.com/r/netflix/comments/4i1sp7/all\_guide\_how\_to\_download\_subtitles\_from\_netflix/](https://www.reddit.com/r/netflix/comments/4i1sp7/all_guide_how_to_download_subtitles_from_netflix/)  
41. Log-Based CRDT for Edge Applications, erişim tarihi Ocak 24, 2026, [https://racelab.cs.ucsb.edu/papers/ic2e22.pdf](https://racelab.cs.ucsb.edu/papers/ic2e22.pdf)  
42. Compared to Automerge · Issue \#145 · yjs/yjs \- GitHub, erişim tarihi Ocak 24, 2026, [https://github.com/y-js/yjs/issues/145](https://github.com/y-js/yjs/issues/145)  
43. Best CRDT Libraries 2025 | Real-Time Data Sync Guide \- Velt, erişim tarihi Ocak 24, 2026, [https://velt.dev/blog/best-crdt-libraries-real-time-data-sync](https://velt.dev/blog/best-crdt-libraries-real-time-data-sync)  
44. droher/etymology-db \- GitHub, erişim tarihi Ocak 24, 2026, [https://github.com/droher/etymology-db](https://github.com/droher/etymology-db)  
45. Creating a custom speech synthesizer \- Apple Developer, erişim tarihi Ocak 24, 2026, [https://developer.apple.com/documentation/AVFAudio/creating-a-custom-speech-synthesizer](https://developer.apple.com/documentation/AVFAudio/creating-a-custom-speech-synthesizer)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAAWCAYAAAAb+hYkAAAAtklEQVR4Xu2SMQ5BURBFr8oO1BagsAbR6u3FBhRKlbX8lkKlIjqVThASkU+4Y96Tl8nMBsRJTnPvzM97Lx/4fSb0TF/JGz3QusjaediSBywV/PyDFHMbkh6CpSG06NuCzBAsrREUiI/tFl36oDuTf5EFebElXdF7yprlUEm+j1y4ZJNyly38cgzNW7YQvPsIV2jesIUgxcKGiD+GEbQY2ALO0pRe6BH6aif6LAdIB7q0h/6Pf4Q3aH46g0u8DPIAAAAASUVORK5CYII=>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAsAAAAXCAYAAADduLXGAAAAmklEQVR4XmNgGD7AHoj/I+HNqNIIAJJ4jiaWwgDRhAL0sQlCAYb4NyD+gy4IBRiKYW7EBtahC3xhQGjYAcQGqNKogJMBNRRgWA1ZETLIY8BUfAtFBQ7gwoDDH8HoAlCwmAFNsR8QFyALIIFSBjTFZxmwBA0U/AXiGcgCMHfxIAsCwVog/owmxvAEiJmA+AMDRNN7KL0ASc3wBwCBti+FXgOsKAAAAABJRU5ErkJggg==>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAVCAYAAACZm7S3AAAApklEQVR4XmNgGAVdQPwRiP9D8Xcgfocmdh2uGgeAKcQGfjLglgMDkOQhdEEo4GGAyDegiYNBBANE0hFdAgngdNk1BhwSSACnZpwSSACnGpDgAXRBJODGAFGDEeozoBIc6BJIAK+tWCWgwJABIl+HLgECIAlQPOICIPkn6IIgoMIAkWxGlwACOQaI3Dp0iUAgPsmAcPIdID4OxWehYqAkagrTMArIBABY6Tat7dmOFAAAAABJRU5ErkJggg==>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAcAAAAYCAYAAAA20uedAAAAcklEQVR4XmNgGOTgGxCfQheEgf9AXIAuCAL6DBBJJmRBGyD2AuLdUElfKB8MioC4BCrxFsoHYRQAksxFFwQBXQaIJCO6BAisYYBIYgUgiXfogjAAkgQ5CgaOILHBkipQ9k9kCRDoYYAo+AHELGhywwEAAMS4F/hUVNxNAAAAAElFTkSuQmCC>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAATEAAAAYCAYAAACSscoiAAAJQElEQVR4Xu2cd8w32RTHj85iV+/siyjRBdEJ0bI6IfjDvkIigkhEF7Grd7GW6BZLEESJRLB/bKJFL9E7q/fey/3kzslznu9z7sz97a/uu/NJTp6Zc9v8Zuaee+65dx6zmZmZszIXUsUOcKUiFw3n5wrHzk1UMTMzc/bjmCL/VWUn9yryriL/K/LqIicV+VSRfxc5NuQ7tcivh3xvH84/Opx/LOSDFxf5Z5G7FblMke9YbeN6MdMA5R+jysIrrKYhJwT9ywbd54qcJ+jXwtVVsSHOXeRiqtwRLlvknKqcmVmSl1rt3GNcUxUChkFBhxFyHjvoFAye89oifw/nDuUyI/ZnaxvgK1std3TQYbAfEc7XRvZDV8kli7yyyAOtGi24616y/b7IhcP5LsDNP0OVRwg8A17GRblikZcUeXmRywf9HcLxqriE1bZOtOkOfVbCvRXk55IW+WyR66oykPXZR9p+A6NG7EPD328EHekXDOcO912N2JOLnNfyth28OLw6Jx6P8qIif7C9m/O3Ir8p8q+gO+SZhV9YNTLr4i9FTrfq1dy4yD+KPNoO3gg93zZT18N92zSft/2dYEzGOMVqnl4v8xZW8/NePbPIdax2EM6ZIsT29DrGJBvRfTT/cJGrWB1Mnj/o7h3yOT5lcmFA5Lr83DvuLsF19UC+zMBAVgceUNRHI3YOSYMHJ7qIOhb+vCjzhJggkH5/q07LpSVtEn9wis+Fryp6fsQvRRehzAtUuQCUf6Iqrep5SSPPsTr67AKMJrwAyhdt7x5n93lTYEBp//yaYHsGZwy/frzjKU62mvdxmmB7HSO2x/HNw7nr9JqIq6jujoPufqKHi1hNe50mDGRtgBu0tcdjOuF3ZMY7405WnYCM7Lf68+AvuBF7mtWYmJZ5YaIbw2Nhr7fxcs+wmv4lTeiBgh9XZeH2VtO+Knp0cQ4d8RtyA03o5LC1f+hfrXY2JT6AbdK6buf9Np1nimXKuxFrdUy88BbnK/Itq+WnroFRlDynaULgsO2vJ6uz1ZbqOP+d6CIePGaqqaCPsR6HsAVpX9GELcEUmWB8L1x7nLo7eu/g1rZfr9NJP8bDIqTAdDGrx7lcOMYQMugxqL3KxsvBVHrKA6wWzOITr7GadkrQcYFjDWUj5SL8ydrlmQJk/KfIs1S5YegoU/GiXTFiHl+ECwwCj7c6fc94q9WBiXutdSik91xnzPP9cOy06om6dwznU0v45OHaFfSETxS8wlb7GTdVRcIyMTquncHhqCI3k7QMZie6mgjZ73mP7Q9zqBFz8JQc0m8Vzp0bybl6j5R7qugiWbuTfM3aBbOH+GbLg264sMfZXkdh2ZXzRcHbovxHNGEELHw2mm4SrnnKkO6iETveqscNeCpXCGkRb5cVI46ZGrTI3puMmOfu4dhp1fOocNzKo7TyocuMGB2NtJ6pM3BPtcNGsrYXgfuDYTpB9C3cOVFUR5xSdS0jFnUYK841NPGTcIzH/6RwDkzrs7qdsbQm2cNlxMUo/ED0wIjAqKzwwxnJqevTw/lD9uXow934KB/Yl+MgPfGcdUP7V1OlsGtGjAA9A5IbsRZ4at8M59k749zHxtMXoaeenjzg+a6f6NWIEcdDP/XeKa0VuEy3CWK77Onye4Cx5bn/0Q4G2j1PSyJscGWllCn3B63G0J13Wg1PMM2/56BjYOCcGRULKRGcHnSkkecN+5PH4cJoDMNDAJpVQHTEQDJIY6Upw+NhY0u8PfCj9ebhobUgPqc3OIO5/Fsagof5piJvtHoDGTHYC9ML7Y9NsWBXjJjKlBFjyhafKQMc5ei0CgOX17ssPfX05AHPd7tET6fm/WcVl46NThezelFD1nNt62KbbW8Mdzn1Jf76oM9A3/Kwsi0Qy3Jt63tRp9LXTU/7ixgxOhFbS1QorzqEvVhTqCcG77ODz1/Ra37YoMPwK1xHz/Pqoaeenjzg+S6V6NUTY2Ud/W1F34sbMmSbC060r9O9Iw6mCNkL8DzLHzigP6zKgV9ZXl8v2bYKeKjVelvxGlim3VXQ0/4iRoxA8T0SobzqELzMKTIjdhcbN2LsN/IOmUnGWFqE92WMnno8T7YSF2nVhU6NGLTy98A0fZnykXivW9KCNN2zdcTRugmssqHPRhH0J6pygLT3qrIT9sG0yroH0sKX9KdgQySj7CLSC+1nH75GFjFiLZYp70Ysmwa2eLflBtI3RGcj/SetpulKlTL1W1rvZ8TjV4QCWviK+Rc0wao+WxTqaTvDDRjwPpyZOlbFNtveGPzIT6jSxh8gemJIisfDMDhA0C+u1hG3Oj6cKwQeW1so8Bi/rMoAS86t690UtD8VR9kVI3aUJozQas+nlHwknDH2DgGrbezOHmOqDsc3prYYq6eV1tKP4X0gsmpDdvFwfHQ4zlhluzuJLyH3LG3H47dZ/uGnTzscXW72Olveiu8/upbonzLox+CbvKk864b2n65KgX075GstmvSwzO9k1Yfyh0TfgpgX+TOjF+M+Gf5ZER6bLnjcpsh3RadQZqx+hXYyj+rHVuuI/yrGwYtsteELXKyyw49CWousHoje2TJwTcw6ji3yQ6v/4aHFfW01be4kJ1vdUMoLzaoky5q6CdD3jvzU6igX59WHhrQM/0wp+0AVo8metNaigO89813hPqXNPEWFF/i5qtwwp9jBZWOHe8g9OcNqp2IvDV4nsb5Fad37MdhfhBfm7fOXeBT3usVvrV4nwnEEzzjW9zOrHSyD5+KGwlf+nr0vx354F7k22qVuv1/oeH/GOMn23p3PDMetT9L4Zpj32+8Hv0cNq+9ZZEvR6ZKm3FkVAl7a1IbcMbSP8u741oUM+g3T+pkGPNhsZJviOOvb2bwoZ6Zjrxr1RNfFJtqY2T30ubOfcgzytz4vm7EaKGUEW5S4YXJV4OGNxcs2CSP7w1W5YlrT8ZkjG4wSIRq82KlwxC0t/6pmRiD+sMjyLR+Z8jHoqtERapt4HGhmZtWweu/fFSPsn2zB1FPjkDMNFumwrQ+Ll4FYzDGq3DJs41iHxzkz43zPDv5LKue0IjdU5UwbgpVT3wuuC77n69mlvg2uYfkeu5mZRSF8oHFkNqM/SHRO9q+qZmZmZrYG/1RB/5PGIjOgmZmZma3Cth3+vTZbQE4t8m07m8e7/g9N7wMW9Xz8DAAAAABJRU5ErkJggg==>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAYCAYAAADDLGwtAAAAa0lEQVR4XmNgGHrgIhB/B+L/SPg9igo0AFOEF7AwQBSdR5dAB2UMEIXe6BLo4BMDEdaCAEnuO40ugQ4qGCAKfdAl0AF13cfMAFF0AV0CHUxggCiMQpeAgWsMELe9A+K3QPwBiP+gqBgFhAAASvkf/u64jGAAAAAASUVORK5CYII=>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEkAAAAYCAYAAAC2odCOAAACq0lEQVR4Xu2YS6hOYRSGXwPJfUQZkFsxMHDNwICkSGFggJJM3EqmBkoxkDrKxAhx3IoBBkoJORSJyCW3pI5CIvd7iPdtre2sf/l/zuAMfvZ+6m1/+/2+s/f3rb2+tf99gIqKiormZQv1hvrh+kS9oL4Gb2gxuOwUAcmcgvkjckcZUSDOZ5NMh/Xdyh1lYyEsEDNyB9kO62tNfum4jfpbTTTahqWjXiDGUt+o9uSXFgVIb7RL1DXqi3s94qAyU9QjFejIHff/JXpnoxO0ohPrvIf6gzbD/IG5o4mpt46/MYr6mM1MvXok3sP8brmjSZlHXc9mJzhIrc9mRoG4kE00Dt5V6i21Bpaqi0PfOeoE9Sp44jRs7A7qs3snqbtUdz8fQh31tlA9fEnthmV75Cm1F1Y/RTHXPOcJ1AdYIFYFfy51GR2J8Mfauw42aE7uwO83VHtZaPeBLXJr8IqbzaR6eVsLHO/tTbBf8H29/yY1zfvkL/J2P9TeOz7EQ9Rwb+f5RZZSD8K5Pr2E1voo+PnvfrGNegd74nqrvaa+14wAxsAu8AT2PaeFFeQLr3ZPC9XYWe73dL9Ak5sazhstUpmi+yozn1EDQt9+2NjnwRN5Tjo/S93wY/QHe3skOjK7S1lOHU+ezvclT2h7xacZFzIM9lOjIAes0beiaqSKrbZ9EShtHwUjkoNWEH0FfEM47zIeU5OTt4I6Fs7Hwf5zMIXa5d5o1E5wPnXG27NhGaPFC2WR6klBix+17Y54W0He6G1l3AJvr/VjDtJ9P+aHoWzXvbuUfPOCNtgitIUHBf8hdYXag9q0F8qyi9Qk2HY/HPpUcNtgn0wF/WHFVtfbGXwV/XbqQPC0pTRX1cSY5UtgtVQvjpWwa6kGNgXKjvyDtSKgTNFTnZg7Kir+b34Ckvm7gEfkhWAAAAAASUVORK5CYII=>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAALIAAAAcCAYAAADFnOX2AAAEfUlEQVR4Xu2bV6gUSRSGz6ooLirGRUQXwYigKCqGB8U1guFBQUQwPSiiqCAYUF9MoCurosIKu4r5QYyYUER8UMG8C6YHMSuGVRfFVRfT+a0qpvrcnu7quTM9c++tD356+q/q6eqeM1XVVdVEnopEM9ZnaXo8FYlfWZNZX2WCx1Me2kojBfpR1Q7kkdKoiPRk/c76xfI2WJ/TpFjBVNUDeRRrszTD+Jv1ntTNMnodyJE+TUmVYwGrFmuY3t/JOmblS4tnrCbSTImqEsiXpGFxgTVWmtkwQVxsqpEqR2PhN9R+b+EXmvGs59JMkcocyOcpWIFGEZf+nRqkMl6VCUXgDuuNNDVOF5NncE60EMWiMgeyYTbFX+M91nppSuaS+qKhMqEIoBxoysOIu1jQQxohtJdGFjD05XLOQuIDWWG6l5GgBozNlBKmmZkofFfQunyRpkWS69zG+l+aKYJnl1esf1j/sgYEkysNLoEMYvOY4CkFLlKmPEbzAzniqUnh1xPmRYGJCDxgegpLkkDuJU2D6R8jgFz5g7U9i7aytpAaMtmk8ybtsvxGZYN5dyBHPDKYXW6UBMcslaYn7yQJ5EnSNKC2Qwb0QUqRKZQJ5qSYYIZ+EGkuRN64Kkq3BHIlSSCvkKahVPrHdVidpKl5SLmV0Qzl5XIswHETpWlhvrsyKY4RCeRKkkBGax2K6wXYLCG1DsBVw9VhkaxmdZam5jAlL6MJYlDd+pwEHLNYmp68kySQZ0oTmB/4L5lQBPBgFVpIUmUcI80I0I2QNyaXYEZ+9Ps9hSVJIIdOiK0lleg8/VdATMsg+7LXWTeFF0e2m2LX0i7sYn2QZggtWBtJfTe2eNB9wLplZ/JkBa027l3cMoAyv90NUn1jjFG+JDVG+SmQI13qsU6y6pKqmVFglA1brLdIwmBpCPBH6S7NLLSkkJuXBXynzIv9HcLzZMAY/VPWI1LPQdi+oPBWcBCVvb+eBODmNZBmCAdZZ4WHYxcJz5MbaJVnSNPjzixStUUcCNqB1j7Gn69Y+57y4WvjPIBuF7o9UeBGY9LmgP7cKphcUvxEySepigm6nUOk6cmNqBqhCwXTsYY6Kn8hwQiAC0+kUaLgpQo8dHvyBB4S20hTc4h1ztrvS8UL5KgFUwas9Z4qzRJlmjQ8hQNBa4+WoIthAhlTqutYt1njWB+1/5bUn+Ou3sfDjL1y72dSr3kBs6y1D6mXUTHKYzhOatiqJasd6zGrtU6T58DEUn3KlMHj+U5/1n+kAgbbCdpHoCGQF5KqnWVXYxnrCGsPqdqxK2VqHuRDQI8m1QL8SOqB06T9SWrc1QDPLDjH6ArWpgB5jkaUWXjlUmt7PKHYQ3MnrM8I8g3Wvgm2+3qL0Q/MSqJmPaM9w169PaW3a/QWfyB5DrzE2VHvP2fNyyR7PG40p+CbKwgs9Kn3kaq9a7P2s06zOug8GFXALOEc1lHtIchXslbpfayVRtdlut7HND5ma4E8B7jMWs56R9kXaHk85eaaNDyeigbGSdFPLtV14SXHN1buU9EhK6anAAAAAElFTkSuQmCC>

[image9]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAYCAYAAAAlBadpAAAAyklEQVR4XmNgGJZAGogLgHgmECshiVshsTHAYiD+D8S3gdgbiFWBeBoQPwdiS6gcVgCS+A3E3OgSQFDJAJG/hC4BAn8Y8JgKBSD5IHTBD1AJZnQJNIBhuC5U8CG6BBaAofkvVJAXXYIYANKIYSKxAJ9mfyB2BmJ7IHYAYhcGtHABaXyNLIAEsoG4ngFhQTkQMyErwGczDIDkb6ELgsA1BogkO7oEFOQyQOTD0SVgAGY7ipOAQA5JDi/Yy4BQ+A5KN0Ll1sAUjYIhBwDP2zLKnm6VTgAAAABJRU5ErkJggg==>

[image10]: <data:image/png;base64,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>

[image11]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADMAAAAYCAYAAABXysXfAAABuElEQVR4Xu2WzSsFURjGX9/KR1JWIpGlj2xEimLFglj4F5TITmxkzYaiZMlNyVJ2SlmwtiAspJR8ZiPJ53PuO9M98865d2ZczF3Mr37de5/nTHPmnJl7L1FEROhUwgm4Amu1vF17n/GswS94DvtgPVyG17DN6sKgCT4Qn/8QljlrN2rgGyySBZgi7o9kISiGzzAmizQYgYva53XiubRomYN38l511Q/KMAml8AYewCzRBUWdV87NlMV5Ii5yZCEwHuxBLjyBF7BQdH65Ive5jRfTYIWXsjDgOjgge8QLVyHyoEwTz6VXFh9WUSKLP2QDvsI6WfhggHi+C7JQGLfrH9iHdzL0YB5uEm9At+jipLqYfuKDOmEX7CHv5yoVefCU+Gs/X3RBUL+Bas7bslBhshUahTOUuOBJmO0Y4Q/1m3BLvBu/hXETjKFA9Wcy9EENfCF+RtJB3VarIrPn3aGHx1ZYoIcaY8T9sCxS0Aw/4ZwsfsAQmRfczly3vV3IW6ha6/xSBcdlmCZysRutbEfLHOxSYuKP1uus1W3Zg0KinHinlffEc1tyjIjwh/q37deMpzWAERERIfANq21xWkbm5wkAAAAASUVORK5CYII=>

[image12]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAMsAAAAYCAYAAABUUQmyAAAF7klEQVR4Xu2aZ6g0NRSGj70XRMGKvSPYFRFFsIAVUVAR/MReUBQUu3xir1hAFNva8IcoooL9h/WHqFiwFwQLVuy95rlJ7p49m8xmd6+zd9d54LAzbzKz6TlJRqShoaGhoaGhYVC2tUJDBys4m9eKJazj7HpneyjtJHU9ySzn7FpnBzibP2i7tYPHkp+dzWPFWQIN9ATx7WvpoK3bDq6Vf6xQxQLO/nZ2g7MlnW0n/gVnOvtBxZtUfnL2pPhRZnNnvzk7TvosxFnGU862t6KCRnq0FWviNme/O9sw2N3O3pbO8v4q3Gv7ToXPJAuKb/9FkJDUdI1+uhUnDPJ4ihXF649acUxYXdId/S7xjTQ2vmM6g2thRUmnbY6k9ZjW/5rnnF1uRUtL8olBZ9aZVA6WfN5xYbax4pjwjbO9rWgYtrOcb4VCnpB8maf0ujrLfFLwP1WJyemTAi5mLo+4AXWxlRUSrGeFCnJ50gzbWS6yQiGvSj59r1tBqtvnTMP/7GhFTUxMzyloAmH2IO+P2YCaYUOhymfup7EcImXxh+0sl1mhkCOl3eZKBoBUZznQ2Tni3UpYRXz7PWs6Rjfk9Qtnr4j3KFK85ex5K2oulXaCol3XEWNyYbfL5v2Bjhj1wSLTNgpIaVVQ2Z9YMcGwnWWYwfVX6S733GZDDNfQKaLOQLdG0OkMNi67gWg3hXt24bin3VtYn9vnuzheuhP/TkeM0bGfs9szxq5Ky9kt4gvjRmdXTT1Vzl7SnXdmnFFgO0zPikvADPW0FRPw7mOt2AfDdBZg59WW+7sdMTwxzHKHeH0DpW0SNL1dHr2HSOw8eyotsr+k/ysLPlsugZMO25j95P1qycedI34EPdUG9CB2GFvppfDcrVZMQDy2x0tgO90ajdVq0fpFz/Abm7BcfbSkW18/aAsrjfvSXU3Wjvad0+xjhQCjdvahCSG1XQyHis/7yjYgwRJSXU6E0fj7IboJVe+tgudaVkxAPDyKEhiFrd2X0KJVcaIVAjHfjxg9VxZ4EVZfK2iLhPvNwn3VWkazhXS/cwoyxQlqipMl89AIYKa7pA87zz9WCSfGVHYKRsbSvF/s7GYrKkrfE4kNBoq2MhMwm3HA2gvenav/EgZ1w1hX5CBNrLmsliqH6MZp1gzaouF+qXDP4F8CLr995xQvOrvXioG/pHOR/7izP8VX5ufidxROU+FwtrP3nL0gPpHwhrPvp2P4RRU7F8tIJlE1QUXntoY5SWZ7U8O0/rV41+NTpf8hPj+a15zd6ewaZ7+YsCqiL60ZpMNQNx9ZMQHvzY3yJQzaWb50doUVA6TJuq25ztKSbj3OLIspLff8+1YQ/9+puNMvWdzo90jnJy5UIr7gZ84eVLp+KY3rMHXPZzL0UqDjRR9SP5NMVE2QJv5fLw4htRtC+WiNjnBBuLZxdXlyIjy3HdQT+66Inm1KOEJ6x19WfJxBt39hmM7Cf5NODS5hKt2xndrDcXYtbXwOkdFWVdpGQbtSaYdLegnCQPeyFeFj8RXxrfiXcerLb0vF0eiE7erszXAdR7+HxU+xsSFF9HP6GndhVPDJB7DjR5p+DL80cAsz6r7qHveNb5lsJ4prnQjXeqFZxS5WMDBg4U+XYhtRhHTTWKl7Zh9+8RRiefTDMJ1lIWcXik9nNNse+D6PAZp0YszotFXgN+aBOOeKf544Ma7e0cQtw8Phf9gt3FmFaQjvVRdF6ArAJdk0XG9pwjQHOXs2XO8u3kWIDOMv14nNG/dri69sFpkRRqS4lw/2uTrhv3ey4gwzaGeZraTc4IHAxdK7FPGlD5l74DQ6NhrWNbFBsc16f7gep48zdd5Y/Me1DqPxatJ2Wc8QPzgALijhfMVMedQN269VXwQ0dMPhJm10aJ4Rv3iKcHj0gbo/Svz0iivHwY6GxsXssrX46ZMNAA6PxoXlxXcY0j1X6ZwNvORsJaXxqf+H4redWRdRbqMCV8SeWTSkYTlCfTX8j2kaQBlNOTVMsYMVGjrgbIYNh4aGhoaGhhr4F7oUtM7OL06RAAAAAElFTkSuQmCC>

[image13]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACUAAAAXCAYAAACMLIalAAABsElEQVR4Xu2VSytFYRSGlwxMMFJKGTByjSIjU8mAET9AKTEyVSZkLgMSU8lfMBATt5RyCRORy4BSLimkWK9vrVpnfXsbnSjtp972Xs9eZ3/r7Ms5RBn/iGbONKfPuDGz/+t8csY5RZx+qec5J3IcA7+I13xw1uV43nmjcIU8WFiHUlrE7zmfd7BIjZdML8VDNVLo33E+72CRJS8FP1Q9hf4t5/OOPiNT/kACdRR6N4wr4wxR+Dy2oJOzzOnSJkcJZ5Fzy1mhcI4cOij3AUZOOYW2SaileKhqzoJ4vByX4rEQ3IzUyqD4KqkxHOqISs47xcOV2yZKHkrRz1gencPbjXrSuFlxP1LKWaXkRZJunwJ/7hxujz3HnNQFxiWSdt8PKX2oTecB/LFz1+KVZ1encuGF0EbxCRrEbTsP4A+cuxKv4Mv4cyaS1jRA8bEmcbvOA/gj5/yVKpZ62DhQwemxAk33FL9t8KPO4VWHP3MewOPKWB7EW9bE4dlVnsz+N/sUfjdeKTSjAdsJ09NKYfAbCgvjCuAhxt9Nt+yrRx/AFjX8HaddPBihsAaCnoyMjD/nCzG9idWH5LU8AAAAAElFTkSuQmCC>

[image14]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADMAAAAYCAYAAABXysXfAAABUklEQVR4Xu2WsUoDURBFh1hYBDs7wUJI6QeYRkE7EcEm36CiKAhiJVqKtSASUSwskl/wJywstBIFEUGsjaJ3mPfI5rruGoi7r3gHDhvmTsjMbnZZkUikdMbgBjyGE4l6PfE5eC7gF7yD87AGj+ATnHJZmWzBZS6moYN2YJUDsCOWX3NQAJfwXez31ZXe+Ccfkn/WNV/iYsHkLvMm1jTEAZG3bBFkLjMp1nDPQQrBL/Mp1jDCQaBkLuNvqkFxIvZETPMcnsFT2HS9+sTsB511lYuerGUW4SychjNwTvLvq/9GZ13jokfDFy469AzsSnfhbVjp6SgenWOdi56sK+PR/JaLv7APD/pwwb72Z3QWfTNJ5UasYZgDh15SzRsclITOssnFJP7q8F9oPJGFwKjYLIccMFfSHfzVHfdc1vZNJdESu68f4YM7Pou94kQikUgkTL4B0s1axWBMmh0AAAAASUVORK5CYII=>

[image15]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADoAAAAYCAYAAACr3+4VAAAB2klEQVR4Xu2WuUoEQRCGC4/EK9BAfQFR0EQQFcREMdPE2NhMDDRQfABBjEwUQVYMRQMTwRcw8sTISFARFS8MDDyrqGm259+endnZYcFlPvjZ4a+iqeprmyglpexoY62xRi1vxvr+91SzfljrrAbWIOuXtcB6t/JKySLrk/XF2oQY0s66R9OFNDWAJqk/j2YJeGN1e99NpHWIbEZYj1bswR/OJUO5gxjEl9VOiiE0HPSSrk695fWQ1nJseTaRGnXNliHILxQ5AjLWMAYcyJaV3Avww+qM3OgyBhJgg/SMdWEghG3Su8Km6EaXKDuI0aovo3AOSC+xVgzEpJ+0LpkAF5EaFaYot9lLX0Y4laxz1g2rFmLFIvXIv0IQEpeLqSDkHOXbJkgNaXOnpM0mzQ7rG01Aan1C02YcDY8tit5oI+uVtY+BBJgkHTsMqfUZTcMYaxpNj1mK3qjBrOwJqwJicehjXYEXVJP4gRNyxNpF00O2StwLSZqUsa9Jm49DC+sMTcrfqDwynJhzWAe+nImknn17pAU0YyAPVZStDXVo5dlI7ANNg2wzmX1Zckl88X4zVk5SrJC+Wzsw4EDe29ig0ZyV10l6Lm9Jd4/ojpJbpKKYQCMlJSUlpVz4A2KkhwL8DC/tAAAAAElFTkSuQmCC>

[image16]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADoAAAAYCAYAAACr3+4VAAAB1klEQVR4Xu2WzysFURTHT6IobESs7KRYSAklK9mIjbWFDTtZUEixVLInmydLsfE/sKKUlYUUEvJ7YeHn+XZnevd938x7M/e9FOZT3970PeeduefemTtXJCHhz9GkWlMNWt6Udf3rKVN9qtZV1ape1ZdqXvVi5f0kS6o31btqg2JMs+qazSDQVA+bYvw5Nn+AJ1W7d10jZhyQTb/q1ordZIazSUl2ER/4WO1cNLJRIJ1iVqfK8jrEjOXQ8mwiNRo0Wz5hPrOnOlVVcMABPLK47zH5+cYZudEVDjiwq3pWNXAgJlti9gqbghtdlnQRX6sZGfHB/7GJtHHAkW4x48IEBBGpUTAh2c2eZGS4sSim1gD5cUENfBXCQBwbUyz6JPdj4sK4mHojHIjAtuqDTQK179i0GWbDY1OK2ygOIKg3w4E8YIIe2QwAte/Z9BlSTbLpMS3FaXRMTJ1RDkSgS3VGXtiY4IdOyIFqh00PPCqFbEgLYm6Oj7oL9aojNiV3ozhkBOK/h5Xk451wPfbhnIxjWwsHYlAq6bGx9q08G8Re2fS5UJWIWXIkPni/KSsnKpgc1KnjgAM4b3ODvmatvFYx7+Wl6tzTlbgvUl5qVeVsJiQkJCT8N74BZKSGpJXfPGYAAAAASUVORK5CYII=>

[image17]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADkAAAAYCAYAAABA6FUWAAACB0lEQVR4Xu2XO2gUURSGfxPsJCGEQLQQkiJphFSJjYqClWCaQCCkCMFeLJImibWFSCwVm4C1lmJpCpsQsQvkUQZS5OWjUEISPYczl7377967d2bcBXU/+NnlP+fcx9ydmbNAmzb/BEOil6L7njfnff+ruSg6F70SdYluiX6JlkTfvbxUrooOYGOozkRfRMeik8z7Kep3BQXYR2UsJ/WCaMINNmH+Aps52IWNUY+PsFgvB3KiY+gBRVlBeCHq6ykXxV3hEBrTEy7KddgYyxxgYgsJ+alo/SqbHrG5U3gHq9dbLIqb6BkHSjIJG/cOBzzKbjK5/ikqyU4vqjKKsYHGC0heZACtPWUzxEPUbnSrKiM/KRtIyQkxBqvVQ8rNXZSb3KH1H9j0mIblNHxoBHgPq+/mADPBRsZrlNvkFKw+dj/qu7PMHEkHMS56xGbGPBIGiLCDeP0MLH6b/DxovV6oKJ9Eb9nM0OJ6Dx/tUHSBjYhd5Wuw2BMOZDwQ9bFJjMLGeM4Bxi3kEvlvEG7lXE0nBzx6YDna0fgMi9az2CDFHCOIXyDHZ1jOFQ4w2nJ1wDoOLdC+Uj9XvBxmEfZqmOWAMIDaXlJ/Eer9gP1yNKcRawj3oIeib6KjTF+R0NIV4R6snWomye++ZrHJRhPYZqOV3BQ9ZvMPsye6wGYrucxGE9D/om3a/E/8BrI2lUhEY7TsAAAAAElFTkSuQmCC>