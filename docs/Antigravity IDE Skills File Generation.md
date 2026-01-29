# **Engineering the Agentic Ecosystem: A Strategic Blueprint for Specialized Skills in the Antigravity IDE**

The paradigm of Mobile Assisted Language Learning (MALL) is currently undergoing a structural transformation, shifting from static, human-led development toward an agent-centric orchestration model where autonomous entities plan, implement, and verify complex lexical systems. The development of a next-generation English vocabulary application—designed to address the "intermediate plateau" through a synthesis of algorithmic spaced repetition, immersive contextual reading, and modern design principles—requires a development environment that transcends the limitations of traditional integrated development environments (IDEs). The Google Antigravity IDE facilitates this shift through the engineering of specialized "Agent Skills," which are modular protocols encoding proprietary logic, architectural standards, and domain-specific knowledge directly into an agent’s reasoning window.1 This report provides an exhaustive analysis of the necessary skills for this lexical ecosystem and articulates the creation of these skill files in accordance with the skill.md open standard and Antigravity’s proprietary architecture.

## **The Architecture of Agentic Specialization**

In the Antigravity ecosystem, development is no longer a sequence of manual keystrokes but a series of "strategic supervisions." Specialized skills are engineered as directory-based packages that function as cognitive maps for Large Language Models (LLMs), ensuring they operate within the defined boundaries of modern Swift 6.2 and iOS 26 conventions.1 These skills are categorized into two primary scopes: workspace-specific skills located in /.agent/skills/ and global utilities residing in \~/.gemini/antigravity/skills/.1 The discovery of these skills is facilitated by YAML frontmatter containing a semantic description trigger. When an agent identifies a user's request as matching this description, it loads the full instructional set, thereby avoiding "context saturation" and optimizing token expenditure by only incorporating relevant domain knowledge.1

The following table delineates the core skill taxonomy required for the implementation of the lexical acquisition system, mapping strategic objectives to specific agentic modules:

| Skill Domain | Skill File Name | Strategic Objective | Technical Focus |
| :---- | :---- | :---- | :---- |
| **Memory Engineering** | fsrs-retention-engine.md | Optimize lexical retention via mathematical modeling. | FSRS 4.5 Algorithm, Stability/Difficulty variables. |
| **Acquisition Mechanics** | lexical-acquisition-reader.md | Facilitate contextual incidental learning. | TextKit 2, Tokenization, Lemma Tracking. |
| **Design Language** | ios-liquid-glass-ui.md | Enhance engagement via modern design systems. | GlassEffectContainer, Morphing Transitions, iOS 26\. |
| **Engagement Loops** | bandit-engagement-ml.md | Mitigate notification fatigue via reinforcement learning. | Multi-Armed Bandit (MAB), Core Motion transitions. |
| **Widget Architecture** | ios-interactive-widgets.md | Reduce friction via interstitial learning. | WidgetKit, App Intents, Shared App Groups. |
| **Persistence & Sync** | crdt-sync-orchestrator.md | Ensure multi-device eventual consistency. | Conflict-free Replicated Data Types (CRDTs). |
| **Persistence Framework** | ios-swiftdata-standard.md | Standardize data modeling and migrations. | SwiftData, \#Unique and \#Index macros. |
| **Identity & Security** | apple-auth-passkeys.md | Implement passwordless, secure authentication. | ASAuthorization, Passkey lifecycle. |

## **Engineering the FSRS Retention Engine Skill**

At the center of the Target System lies the mathematical core responsible for combating the Ebbinghaus Forgetting Curve. Traditional Spaced Repetition Systems (SRS) often utilize the aging SM-2 algorithm, which relies on a simplistic "Ease Factor" to determine review intervals.1 This approach frequently leads to "ease hell," where intervals become stagnant, trapping users in redundant review cycles. To achieve professional-grade retention efficiency, the Target System implements the Free Spaced Repetition Scheduler (FSRS).1

The FSRS algorithm models memory using three interdependent variables: Retrievability (![][image1]), Stability (![][image2]), and Difficulty (![][image3]). The retrievability of a lexical item is defined as the probability of successful recall at a specific time (![][image4]) following the last review, calculated using the power approximation ![][image5].1 Stability represents the time required for retrievability to drop to 90%, while difficulty measures the intrinsic complexity of the memory trace. The agent skill must be engineered to guide the LLM in implementing these difference equations during database updates, ensuring that successful recall of "Hard" items—which were on the verge of being forgotten—results in a significant "memory boost" or stability increase.1

Furthermore, the system must implement a "Brain Boost" triage queue. Unlike standard SRS which may schedule a failed word for the following day, the "Brain Boost" logic injects failed items back into the active session (e.g., 3 and 10 cards later) to ensure successful encoding before the session terminates.1

### **Created Skill File: fsrs-retention-engine.md**

## ---

**name: fsrs-retention-engine description: Use when implementing or modifying the Free Spaced Repetition Scheduler (FSRS) and memory retention logic.**

# **FSRS Retention Engine Skill**

## **Use this skill when**

* Implementing the FSRS 4.5 algorithm for interval calculation.  
* Updating memory state variables (Stability, Difficulty, Retrievability) post-review.  
* Configuring the "Brain Boost" triage queue for failed cards.  
* Designing database schemas for lexical items and review logs.

## **Do not use this skill when**

* Handling general UI layout unrelated to the study session.  
* Implementing non-SRS discovery features or dictionary lookups.

## **Instructions**

1. **Memory State Modeling**: Implement memory variables at the Lemma level. Every entry must track Stability (![][image2]), Difficulty (![][image3]), and the last\_review timestamp as Float64/Date.  
2. **Interval Calculation**: Determine the next review interval (![][image6]) based on the user’s target retention (![][image7], default 0.9) using the formula: ![][image8].  
3. **State Update Logic**:  
   * If grade is **Again** (1): Reset stability to the minimum threshold but retain a "residual savings" factor; increase difficulty.  
   * If grade is **Hard** (2), **Good** (3), or **Easy** (4): Apply the geometric growth formula ![][image9].  
4. **Brain Boost Implementation**: For items graded \< 3, bypass the FSRS scheduler and place them in a ShortTermQueue. The item must reappear within the same session after 3 cards. It graduates back to the long-term FSRS queue only after two consecutive "Good" ratings.  
5. **Persistence**: Ensure review logs are stored as immutable events to support deterministic replaying of the FSRS state during multi-device synchronization.

## **Lexical Acquisition and the Immersive Reader Skill**

The second pillar of the ecosystem is the transition from intentional rote learning to contextual incidental learning. Research indicates that the "intermediate plateau" is often caused by a lack of exposure to authentic, rich input.1 The "Target System" solves this by implementing an immersive reader that categorizes every word in a text into a visual "Blue/Yellow/Known" paradigm.1 New words are highlighted in Blue, words currently in the learning (SRS) phase are in Yellow, and known words remain transparent.1

The technical challenge lies in real-time tokenization and lemma tracking across long-form content. Utilizing Apple’s TextKit 2 framework allows for high-performance rendering where thousands of interactive tokens can be managed without UI latency.1 The agent skill must ensure the LLM understands the distinction between a surface word (e.g., "running") and its lemma ("run"), tracking progress at the atomic root level to prevent database bloat.1

### **Created Skill File: lexical-acquisition-reader.md**

## ---

**name: lexical-acquisition-reader description: Use when building the Immersive Reader UI, handling text tokenization, or managing Blue/Yellow/Known vocabulary states.**

# **Lexical Acquisition Reader Skill**

## **Use this skill when**

* Developing the ImmersiveReaderView using TextKit 2 or SwiftUI.  
* Implementing the Blue/Yellow/Known highlight logic for articles and subtitles.  
* Configuring the "Tap-to-Capture" bottom sheet for word ingestion.  
* Integrating COCA corpus frequency data for word prioritization.

## **Do not use this skill when**

* Modifying the SRS scheduling algorithm.  
* Building the morphology word matrix visualization.

## **Instructions**

1. **Tokenization Strategy**: Use the NaturalLanguage framework to tokenize text into words and sentences. Perform lemmatization for every token to check its status in the user's VocabularyDB.  
2. **Visual State Overlay**:  
   * **New (Blue)**: Apply \#E3F2FD background to tokens not found in the DB.  
   * **Learning (Yellow)**: Apply \#FFF9C4 highlight to tokens with stability \< 365 days.  
   * **Known (White)**: Do not apply decoration.  
3. **Ergonomic Capture**: Place the "Mark as Known" and "Add to Deck" actions in the ergonomic "Thumb Zone" (bottom 30% of the screen) using UISheetPresentationController.  
4. **Contextual Metadata**: When a word is captured, automatically extract the surrounding sentence. For video sources, capture the timestamp to enable "Video Flashcards" that loop the specific 5-second media segment.  
5. **Frequency Filtering**: Display the COCA frequency rank on the capture card. If a user attempts to capture a word with a rank \> 20,000, trigger a "Rare Word" nudge to encourage focus on high-frequency lexical items.

## **Orchestrating the Liquid Glass Design System**

The visual identity of the Target System is governed by the "Liquid Glass" design language introduced in iOS 26\.3 This system represents a departure from static "glassmorphism" toward dynamic, physics-based materials that respond to user presence and interaction. Key components include the GlassEffectContainer, which blends overlapping glass shapes into a single cohesive unit, and morphing transitions that allow UI elements to fluidly transform between states.3

For a vocabulary application, the strategic use of Liquid Glass is not merely aesthetic; it serves to reduce cognitive load by providing a clear visual hierarchy. Navigation and control layers float on top of the content layer as translucent glass surfaces, allowing the underlying text to shine through without creating "blur piles".1 The agent skill must enforce specific modifier ordering (e.g., applying .glassEffect() before .interactive()) and ensure that accessibility fallbacks—such as checking for the Reduce Transparency system setting—are implemented from day one.1

### **Created Skill File: ios-liquid-glass-ui.md**

## ---

**name: ios-liquid-glass-ui description: Use when implementing UI features using the iOS 26+ Liquid Glass API and glass-morphism design patterns.**

# **Liquid Glass UI Skill**

## **Use this skill when**

* Building the GlassEffectContainer for navigation and menu systems.  
* Applying .glassEffect() and .interactive() modifiers to SwiftUI views.  
* Implementing morphing transitions with @Namespace and .glassEffectID.  
* Designing accessibility fallbacks for transparency-sensitive users.

## **Do not use this skill when**

* Handling backend data synchronization or SRS logic.  
* Building low-level NLP parsers.

## **Instructions**

1. **Container Management**: Use GlassEffectContainer to group multiple glass elements. This ensures the system blends their paths and optimizes rendering performance.  
2. **Interactive Glass**: Always append .interactive() to the .glassEffect() modifier for tappable elements. This enables native scaling, bouncing, and shimmering effects on touch.  
3. **Morphing Logic**: To enable fluid state transitions:  
   * Wrap the changing views in a GlassEffectContainer.  
   * Use a shared @Namespace to identify morphing pairs.  
   * Apply .glassEffectID(\_:in:) to ensure the system recognizes the view identity across the transition.  
4. **Material Selection**: Use .ultraThinMaterial for maximum transparency in navigation bars and .regularMaterial for cards to maintain text legibility.  
5. **Accessibility Mandate**: Check @Environment(\\.accessibilityReduceTransparency). If enabled, provide high-contrast opaque fallbacks (e.g., standard system backgrounds) to ensure readability for all users.

## **The Home Screen Offensive: Interactive Widgets**

The strategic vision for the "Target System" acknowledges that relying on users to voluntarily open an educational app is a losing strategy in the attention economy. Instead, the system must "colonize" the home screen through an interactive widget ecosystem.1 By utilizing iOS 17’s App Intents framework, widgets are transformed from passive displays into active microsystems where users can complete flashcard reviews or save the "Word of the Day" directly from their home screen without a full app launch.1

A critical technical requirement for this "Micro-Dose" learning is low-latency synchronization and zero-friction audio playback. Widgets cannot support continuous scrolling or complex gestures, so the agent skill must guide the LLM toward binary grading (e.g., "Forgot" vs "Recalled") on small widgets to maintain accessible touch targets.1

### **Created Skill File: ios-interactive-widgets.md**

## ---

**name: ios-interactive-widgets description: Use when developing iOS interactive widgets, App Intents, and home screen learning features.**

# **Interactive Widget & App Intent Skill**

## **Use this skill when**

* Developing the "Micro-Dose Flashcard" or "Word of the Day" widgets.  
* Implementing AppIntent for background database updates from the widget.  
* Configuring WidgetCenter timeline reloads and shared App Group persistence.  
* Implementing low-latency audio via AudioPlaybackIntent.

## **Do not use this skill when**

* Designing the main app’s immersive reader or morphology graph.  
* Handling server-side notification scheduling.

## **Instructions**

1. **Data Sharing**: Ensure all SRS data and review logs are stored in a shared AppGroup container. This allows the widget process to access and update the user's memory state without launching the main app.  
2. **Intent Flow**: When a user taps "Reveal" on a widget:  
   * Trigger an AppIntent to update the widget’s local state.  
   * Use cross-dissolve transitions as 3D flips are not supported in WidgetKit.  
   * Tapping a grading button (e.g., "Good") must trigger a second intent that updates the FSRS database and calls WidgetCenter.shared.reloadTimelines().  
3. **Audio Integration**: Use AudioPlaybackIntent to play pre-cached pronunciation files from the shared container. Audio files must be downloaded in advance by the main app to ensure zero latency.  
4. **Visual Urgency**: Implement the "Streak Keeper" widget using color-coded rings (Green for goal met, Alert Orange for goal at risk) to leverage loss aversion.  
5. **Text Constraints**: For small and medium widgets, use ViewThatFits to handle variable context sentence lengths. Prefer truncating the sentence over shrinking the font size to maintain legibility.

## **Behavioral Engagement: The Bandit Notification Engine**

To solve the ubiquitous problem of notification fatigue, the system adopts a dynamic re-engagement strategy powered by a "Multi-Armed Bandit" (MAB) algorithm.1 Instead of sending static, time-based reminders, the system treats various notification types—such as "Streak Defense," "Curiosity Gap," or "Social Proof"—as arms in a reinforcement learning model. The objective is to maximize the open-rate reward by delivering the most effective message type at the most "interruptible" moment.1

Interruptibility is modeled using the Core Motion framework. The system identifies "transition moments," such as the transition from "Active" (walking) to "Stationary," which typically correlates with a user arriving home or sitting down for a commute.1 The agent skill must ensure the LLM understands how to balance "Exploration" (trying new message variants) with "Exploitation" (sending the historically best performer).1

### **Created Skill File: bandit-engagement-ml.md**

## ---

**name: bandit-engagement-ml description: Use when implementing the Bandit notification algorithm, reinforcement learning engagement loops, and Core Motion interruptibility modeling.**

# **Bandit Engagement Engine Skill**

## **Use this skill when**

* Developing the Multi-Armed Bandit (MAB) logic for notification delivery.  
* Integrating CMMotionActivityManager for context-aware scheduling.  
* Designing dynamic message templates with psychological triggers (Loss Aversion, Curiosity).  
* Implementing "Cool-Down" logic to prevent notification fatigue.

## **Do not use this skill when**

* Handling local SRS scheduling or widget interactions.  
* Building the UI for the stats dashboard.

## **Instructions**

1. **Algorithm Strategy**: Implement an Epsilon-Greedy or Thompson Sampling model to select notification templates. Exploit the best performer 80% of the time and explore new variants 20% of the time.  
2. **Interruptibility Modeling**: Utilize Core Motion to detect the transition from "Walking/Automotive" to "Stationary." Trigger a "Smart Nudge" 2 minutes after this transition to capture the user's window of availability.  
3. **Template Architecture**: Define a database of templates mapped to psychological triggers.  
   * **Streak Defense**: "Danger\! Your streak expires in 2 hours."  
   * **Curiosity Gap**: "Do you know the English word for?"  
   * **Reverse Psychology**: "These reminders don't seem to be working. We'll pause for now."  
4. **Fatigue Management**: If a user ignores three consecutive notifications, the system must enter a "Silence Mode" for 48 hours. No raw location data should leave the device; all processing must remain local.  
5. **Reward Function**: Define the reward as a NotificationResponse event. Update the bandit weights asynchronously to ensure the scheduling engine adapts to shifting user preferences.

## **Multi-Device Consistency: The CRDT Sync Orchestrator**

The "Target System" functions as a "Personalized Lexical Ecosystem" that must remain consistent across iPhone, iPad, and potentially desktop platforms.1 Standard "Last-Write-Wins" (LWW) database logic is fatal for SRS systems, as it can lead to the loss of review data when a user studies on an offline device. To solve this, the system implements Conflict-free Replicated Data Types (CRDTs), mathematically guaranteeing eventual consistency without a central locking mechanism.1

The sync architecture is built on an append-only log of review events. Every review is an immutable record containing a UUID, a lemma identifier, a grade, and a timestamp. When devices sync, they simply union their sets of review logs and re-run the FSRS calculations deterministically to arrive at the same memory state.1

### **Created Skill File: crdt-sync-orchestrator.md**

## ---

**name: crdt-sync-orchestrator description: Use when implementing the sync engine, CRDT data structures, and multi-device data consistency protocols.**

# **CRDT Sync Orchestrator Skill**

## **Use this skill when**

* Building the synchronization layer via CloudKit or custom WebSockets.  
* Implementing G-Set (Grow-only Set) for review logs and LWW-Set for word status.  
* Designing deterministic FSRS state replaying logic.  
* Managing background sync tasks and delta-based data exchange.

## **Do not use this skill when**

* Implementing frontend UI animations or Liquid Glass modifiers.  
* Building the Bandit notification algorithm.

## **Instructions**

1. **Event-Based Persistence**: Never modify an existing review log. Treat all reviews as immutable events. This is the foundation of the G-Set CRDT pattern.  
2. **Deterministic Replay**: Upon synchronization, merge local and remote review sets. The FSRS Stability (![][image2]) and Difficulty (![][image3]) for each word must be recalculated by replaying the merged log in chronological order.  
3. **LWW for Metadata**: Use Last-Write-Wins (LWW) semantics for non-cumulative metadata, such as the "Marked as Known" status of a word. Ensure high-precision timestamps (Int64) are used for conflict resolution.  
4. **Optimistic Updates**: The UI must reflect grading and capture actions immediately. The sync engine should handle the eventual consistency in the background, updating the "Sync Status" indicator only once the delta exchange is confirmed.  
5. **Binary Delta Sync**: To conserve battery and bandwidth, only transmit the "Delta" (the difference between the local and remote vector clocks) rather than the entire database.

## **Technical Standards for Data Persistence and Security**

The reliability of the lexical ecosystem depends on robust data modeling and secure, frictionless identity management. The system utilizes SwiftData for its local persistence layer, leveraging macros like \#Unique for compound constraints and \#Index for query acceleration.1 Security is handled through passwordless authentication via Apple’s Passkey APIs, ensuring that the user’s lexical history is protected across the ecosystem without the friction of traditional passwords.1

The following tables provide a technical comparison of the persistence and security requirements that the agent skills must enforce:

| Database Entity | Key Attributes | Constraints & Indices |
| :---- | :---- | :---- |
| **VocabularyItem** | lemma: String, stability: Double, difficulty: Double | \#Unique(lemma), \#Index(lemma) |
| **ReviewLog** | id: UUID, card\_id: UUID, grade: Int, timestamp: Date | \#Index(card\_id, timestamp) |
| **ContextSentence** | text: String, source\_url: String, word\_id: UUID | Linked via Relationship to VocabularyItem |

| Security Component | Implementation Standard | Strategic Rationale |
| :---- | :---- | :---- |
| **Authentication** | ASAuthorization (Passkeys) | Remove password friction to maximize retention. |
| **Data Privacy** | On-Device ML (Bandit & Motion) | Ensure sensitive motion data never leaves the device. |
| **Storage** | Encrypted App Group Container | Protect lexical history from unauthorized app access. |

### **Created Skill File: ios-swiftdata-standard.md**

## ---

**name: ios-swiftdata-standard description: Use when designing data models, schema migrations, and persistence logic using SwiftData.**

# **SwiftData Standard Skill**

## **Use this skill when**

* Defining @Model classes for Vocabulary, Reviews, and Sentences.  
* Configuring \#Unique and \#Index macros for performance and integrity.  
* Implementing schema migrations and versioning.  
* Handling data fetches and predicates for the SRS queue.

## **Instructions**

1. **Modeling Standards**: Use Codable and @Model for all persistent entities. Ensure VocabularyItem has a unique constraint on the lemma field to prevent duplicate entries.  
2. **Performance Optimization**: Apply \#Index to high-frequency query fields, specifically the due\_date and lemma fields. This is critical for the "Reader" view which performs hundreds of lookups per second.  
3. **Relationship Mapping**: Use @Relationship(.cascade) for review logs to ensure that deleting a vocabulary item cleans up its associated memory history.  
4. **Migration Strategy**: Use SchemaMigrationPlan to handle updates. Ensure that adding a new field (e.g., etymology\_root) does not invalidate existing SRS stability data.  
5. **Thread Safety**: Perform heavy database operations (e.g., initial article parsing) on a background ModelContext to maintain 120fps scrolling on ProMotion displays.

## **The Morphology and Etymology Engine**

The final strategic requirement is the integration of morphological analysis. This addresses the analytical learner by shifting vocabulary acquisition from arbitrary memorization to logical deduction.1 The system visualizes the "Word Matrix"—a force-directed graph showing the etymological relationships between words.1 When a learner acquires a root (e.g., "spect"), the system applies a "Stability Boost" to related words (e.g., "inspect," "respect"), reflecting the "multiplier effect" of structural knowledge.1

### **Created Skill File: morphology-matrix.md**

## ---

**name: morphology-matrix description: Use when building the Word Matrix visualization, etymological root mapping, and morphological logic.**

# **Morphology Matrix Skill**

## **Use this skill when**

* Implementing the force-directed graph for word families.  
* Mapping lemmas to roots using etymological databases (Etymonline/Wiktionary).  
* Implementing "Stability Boosting" for related words in the SRS engine.  
* Designing the "Rootcast" audio interface for historical word stories.

## **Instructions**

1. **Structural Logic**: Every VocabularyItem should optionally link to a MorphologicalRoot. When a word is captured, use the NLP framework to attempt a root match.  
2. **Graph Visualization**: Use a physics-based layout for the matrix. The root node should be the largest, with prefixes and suffixes branching out. Color nodes based on their SRS state (Blue/Yellow/Known).  
3. **Stability Inheritance**: If a user learns a root, apply a 1.15x multiplier to the Stability of all related words in the database. This reflects the cognitive ease of acquiring words within a known family.  
4. **Mnemonic Keywords**: For words without clear roots, use an LLM-based asset to generate keyword mnemonics (e.g., "Coward" \-\> "Cow" \+ "Scared") and store them in the mnemonics field.  
5. **Etymological Feed**: Integrate a "Root of the Day" feature that pulls historical data to provide the "narrative hook" for learning, which research shows is "stickier" than a dictionary definition.

## **Synthesis: The Agentic Development Workflow**

The creation of these specialized skills transforms the development of the lexical acquisition system from a manual engineering task into a high-level orchestration of domain expertise. The Antigravity IDE, guided by these skills, acts as a self-aware assistant that enforces pedagogical rigor and technical excellence at every stage.1

The future outlook for this "Personalized Lexical Ecosystem" suggests a move toward even deeper integration, where the agent not only implements the code but also manages the content lifecycle—crawling web sources for user interests, generating context-rich flashcards via LLMs, and monitoring the MAB algorithm's performance in real-time.1 By adhering to the skill.md standard, the development team ensures that the Target System is built on a foundation of "Invisible Technology," where the complexity of the algorithms and the design system serves the learner’s goal of achieving fluency without being distracted by the underlying mechanisms.1 This strategic blueprint, encoded into Antigravity Agent Skills, provides the definitive path to solving the "intermediate plateau" through a synthesis of modern engineering and cognitive science.

#### **Alıntılanan çalışmalar**

1. Modern Development in iOS 26 and Google Antigravity IDE  
2. A unique alternative to Anki \- Reddit, erişim tarihi Ocak 25, 2026, [https://www.reddit.com/r/Anki/comments/1qhielr/a\_unique\_alternative\_to\_anki/](https://www.reddit.com/r/Anki/comments/1qhielr/a_unique_alternative_to_anki/)  
3. Understanding GlassEffectContainer in iOS 26 \- DEV Community, erişim tarihi Ocak 25, 2026, [https://dev.to/arshtechpro/understanding-glasseffectcontainer-in-ios-26-2n8p](https://dev.to/arshtechpro/understanding-glasseffectcontainer-in-ios-26-2n8p)  
4. deep/CLAUDE.md at main · actonbp/deep \- GitHub, erişim tarihi Ocak 25, 2026, [https://github.com/actonbp/deep/blob/main/CLAUDE.md](https://github.com/actonbp/deep/blob/main/CLAUDE.md)  
5. Technology News 18.11.2025 \- Bez Kabli, erişim tarihi Ocak 25, 2026, [https://www.bez-kabli.pl/technology-news-18-11-2025/](https://www.bez-kabli.pl/technology-news-18-11-2025/)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAYCAYAAAAlBadpAAAAy0lEQVR4Xu2SMQ8BURCER6XSqiVahd8gWr3/4g8olCqVH6KlUGkQnUonR0hEEGaz7708e+/UivuSSS4zs5fbzQElI+pMvZ1u1JF6RF7Dl4vwRcsM6jdtECOFuTVJB5qtbeDpQwtdG5AJNJsaP7BB+pOFonUCqUKbelJ74+eQQbnwklpRd+dV41IKv68cJmbr/J/skC4NoX7dBjGpfYUr1K/YIEYKC2ui+KWBAbTQswHyw+F5TF2oDHrlE/XyoaMFHThA//fad1zy53wAhPQ9J2j9tisAAAAASUVORK5CYII=>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAAYCAYAAAAh8HdUAAAAqklEQVR4XmNgGLJADYhnArEvklgJEhsFsALxPyCeDcR8QGwHxP+BuAaIPyOpQwEgBTboggwQ8Sp0QRBYwACRxAZA4iBXYACQBD5NWAFMUy+6BD7QzYDQCMMzUFTgAHkMmBpvoaggAFwY8PuTIRhdAAoWM+DQ5AfEBeiCUFDKgEPTWSBehy4IBX8ZcAQGzN08aOJrGfAknSdAzATEHxggmt9D6QVIakbBwAEAIrItoSGpzDcAAAAASUVORK5CYII=>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABEAAAAXCAYAAADtNKTnAAAAsUlEQVR4XmNgGAWEQBcQfwTi/1D8HYjfoYldh6smAGAasIGfDLjlUABI0SF0QSjgYYDIN6CJo4AIBogiR3QJJIDPpWBwjYGAAgYiDCGogIEINSDJA+iCSMCNAaIGZyzBwsMBTRwZ3GaAqBFDl4ABQs40ZIDI16FLIAOQAlA6wAVA8k/QBZGBCgNEUTO6BBDIMUDk1qFLwEAgEJ9kQHjlDhAfh+KzUDFQ0jeFaRgFIw4AAFhqNpdzGLpuAAAAAElFTkSuQmCC>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAcAAAAYCAYAAAA20uedAAAAcklEQVR4XmNgGOTgGxCfQheEgf9AXIAuCAL6DBBJJmRBGyD2AuLdUElfKB8MioC4BCrxFsoHYRQAksxFFwQBXQaIJCO6BAisYYBIYgUgiXfogjAAkgQ5CgaOILHBkipQ9k9kCRDoYYAo+AHELGhywwEAAMS4F/hUVNxNAAAAAElFTkSuQmCC>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAKIAAAAYCAYAAAB5oyYIAAAFF0lEQVR4Xu2aWcydQxjHH6JEKZoIiqSWkDZcuKC9aYnGUsR+40J7QdoEsYaIEumNaIS0TSTWVC2JC0uQSBDkQ+yRVINqL9CgsdTWFlXr88/MOHP+55l5l3PO63y+95f8c77zn3nPzJn3OTPPzPuJtLS0tEwgDlT9yeb/gTlsjFP2ZiPiHDaGwAVsRBzDRk1uUy1S/c0F451fVDuxOQ65XDWTTc961b5s1mSB6lbVUZG30L8epno/8plBBc+JUuGzblf9JO4C6FfVd6rfI++QUPk/4lXVCWxGXKu6hM0RJXVjEDQ3sel5Wtx161S7UBmzWFzds1V7qpaqvldtUc3uVJOVqnui9zGHqn5gswaVAjEQgo55UZx/OBc0BAbF6tejqh3S6fel3cWNcpDYfWR2FjeeDHzr+n3E+TP8+2n+/a7/1ujmVLE/Z6nYvuUFfladyWZFagfi62wq88SVfcgFDYFf5rlsEv0G4i1sVOQJKTfgD6mmsKm8IG6GYsKPLOYDSW8AUPc6NsWlNPw54GFJL9FHiH0NVsyUnonqgcqBiOQVF5zEBcq94spWk98UZb5Iv4G4jI2KoH0sf0Wkvgt8a8mFv4G8O7xvAf8yNj3PsiFu05T6LICyyWxWoHIgfiTpC+CnyobNRVKu7X4DEXlyHU5TnS6ufcx2+Hv/rhodcJRhzXrYOFjfcbo4fw35N3s/LNeBMOtBB1NZDtTfi00PyrD7rUvlQLSCDdv4P1Sfkd8k76i+ZNOg30DELFMV7G6vUd0trn38De0RV4pYy4YHN5rHPgCfZ8QHvX8++SDcxyCcNMzqqtEL6t3Apgcpw29slgRLNVaJzaofxV5te0BnsFPGjccvEI3D2y2uVADyDUuYKTB4D6hWqe5X3eevKeIv1WtsGqCvqSWpDHUCMVA2P8R3sXhF0tfD53wQnwPfygXBm9IbkMd11egG5bg/FuFH1gghP8SmJAZHBY11IkFukGJQD+dzZTjW0COGF1QE2savPscpqovZ9Gz0sgi78QP8exzoj3lvrvdyjImr+w35MZi53mLTc700GAM4RLUaQwIPfz8uaBC0v5pNA9S7gs0EZxl6yvCCikDbV7JJbGMj4lPJpz+TVI+JS1HOELeqoM14c4NjmxSoa93fAI5p3mPTg1k3d+1ASXUUgwcfSXAZkOtUURm2i1u6ikA/r2KzAnWX5qPFtY1zwBy5Gek5SS/bFm9L7/3i5TsGdZ9nMwLlT7LpuUt62xoaaOgNNiUdoE2CM67P2TRAP69mswJ1A/Fx6R4jPAFi8NQnl6NhJ50a50+ktwzvefedmjAwm6IMrylQvoRND34k2PAMnRvFdcQ6QedA5AFpgvC4Kgd2r6hT9wgG1A3Ed6XTP+xOkdwzRf0/UtJ1kL/FZXgkx3XDWaD1SA4zbdFKgWunsulB2Qo2B8mdqq3iOo/dMrbXPL2HZWeTuAGxngg0AQ98AHnTt6ovxM2aeP1a3GO/qtQNRBCCxUo3sGSPsWmA663lHed7KMNmCPcHMySDdudL5wkYhLwPr0X/SYOjptT4glyQTjgwGCezOWD6CcQc2FikDotjkEP2+5ixDpjBcfxkgUPxXJBOOPCrrpLMjxJlb+TuUr7uIMm1idXyPDYnOkgPipaZUQNL2nI2M7wszf4rGx4VpmZhPKb8is0WB+ewo85LbJQAOS7+h3DYINA+ZjMiN1O2iHuIPl6ou6xdyMYQyB3+H89GS0tLS8uw+QcL6GRe7nclKQAAAABJRU5ErkJggg==>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAYCAYAAADDLGwtAAAAa0lEQVR4XmNgGHrgIhB/B+L/SPg9igo0AFOEF7AwQBSdR5dAB2UMEIXe6BLo4BMDEdaCAEnuO40ugQ4qGCAKfdAl0AF13cfMAFF0AV0CHUxggCiMQpeAgWsMELe9A+K3QPwBiP+gqBgFhAAASvkf/u64jGAAAAAASUVORK5CYII=>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAYCAYAAAAlBadpAAAAyklEQVR4XmNgGJZAGogLgHgmECshiVshsTHAYiD+D8S3gdgbiFWBeBoQPwdiS6gcVgCS+A3E3OgSQFDJAJG/hC4BAn8Y8JgKBSD5IHTBD1AJZnQJNIBhuC5U8CG6BBaAofkvVJAXXYIYANKIYSKxAJ9mfyB2BmJ7IHYAYhcGtHABaXyNLIAEsoG4ngFhQTkQMyErwGczDIDkb6ELgsA1BogkO7oEFOQyQOTD0SVgAGY7ipOAQA5JDi/Yy4BQ+A5KN0Ll1sAUjYIhBwDP2zLKnm6VTgAAAABJRU5ErkJggg==>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAKgAAAAYCAYAAABugbbBAAAEAklEQVR4Xu2aWahNURjHP2MSD8iYTEWKQkhJhLyYkvIiGSIyFB5M8YLyIA+GQuYhChEPCi8ekJAQeaL7gELmeeb79+117zrf3Xufdc7e++xztX717577/9ZZe629v73XsA+Rx+Px5Mwi1nhtejxh9NFGhoxgLWD9pepO0IHa8NRnGWsdq7vlDbU+pwESxQUk8VrWTlZby59rfS6Fak9Q4HRu7rG+khQ2eltQonJ0Zj0gacM+FUuTXaw/rNGs9qzjrPskx21qlUvKC5L647hKctzrrLGsAawLrCusJSTtLIdqSVC04YQ2A3pSCblmkjMvzLDUOPh/HpV/ceLYxPqpTeYypdv/mayX2rRoRnK816xGKgYuksS364Aj+O4EbVaIlayPVJdTJwvDBXxmTdKmBk8NVHRHByoEkhLH36Z8eDuUlxTUGTaMD2N90mYCcJxO2rRAHBcnDpRpF3yeTzLSRalFUM6A7xa98BWgWIL2JocHAzI+zztuGsnxpyvf3IFpMZikvn46wPRnrdBmmXSh+Ha79sulTBT47mRt5kCxBAUo01KbNh8o2clIykGS409RPob4NNuFp6RJjtgTkpAjrB/aDMC8EsfHvLcYv7VRAmHnMw9cE3SzNm1c7+ismEVy/KyfoMDUafSK1bWgRHKQWMe0GZBFn2yGs96TzG2hYtOIrHFJ0Eus79o0mPnnLR2IYS/raIQOsw6xDrD2B2Vdpg5og14QZHExMVerofqJam/tJAX1bdRmQBZ9qmbQ11PaVOymmHOymiQ4UQcqjGmH4Tzrm/LCSHLBsZJ+Qm4nEaCcy7CLcnO0yQwhidXoQAAWNWNYo0i2wMYVhjMFbXNVKaC/p7WpWEUx1zDv+afNINYN1jWSJ5pL8rmUAYu1YYHvP9JmCKUk6GxtkuxxRt0MrUjmp1uork/LC0pkCxZUrioF9OOMNhVYnEZeQ9cLbLOBZFLrqnK3O9AuPOHSIK6PiK3RZgJQ33ptBiAWtg9r6EtSZo8ONFDQl7PaVODFSej1aUISuKsDOYB22G8VzEZ2R8tLQugJYHpRdKxcUB/m42GYt3ZRYDhEPG4PtSGBvpzTpgJvzr5oE2wlqUCvnvMA7aix/n9DMtynAebXqP+28jGswscPLNIEW0iYP4dhXkqEJelIio41RJqT9AVTtjhQBrlYy0OSuSeSAFsR71i/7AI5MJukoY+Dv2m+i7/J6sZaSHUJgH1K7LN2sMqlRQ8qnmSmn5B5LTgjiKG9DRnMpbF994xkivaU9Zxk9AgDfW+jTU+2+JPuBvagi93MngxYSukt8P5nsO6Yqk1PZcC0qbU2PbVgAYyh35MjfviKxp+bKgC/9cRPyjyFYMfC4/F4PKnyDzAZJ0MAJZzWAAAAAElFTkSuQmCC>

[image9]: <data:image/png;base64,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>