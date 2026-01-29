# **iOS Design Specification: The Next-Generation Lexical Acquisition System**

## **1\. Executive Summary: The Strategic Design Mandate**

The current Mobile Assisted Language Learning (MALL) landscape is defined by a polarization that leaves the "intermediate plateau" learner underserved. On one end of the spectrum, market leaders like Duolingo prioritize "gamified habit formation" through aggressive streak mechanics and simplified, multiple-choice interactions. While effective for initiation, this model often fails to facilitate the deep cognitive processing required for active recall and spontaneous conversation. Conversely, retention-focused tools like Anki utilize powerful Spaced Repetition Systems (SRS) but suffer from utilitarian, high-friction user interfaces that alienate all but the most disciplined autodidacts. The strategic vision for the "Target System" is to occupy the "Blue Ocean" between these extremes. The objective is to synthesize the mathematical rigor of algorithmic retention with the immersive depth of contextual learning, wrapped in a user experience (UX) that reduces the friction of study to near-zero.

This comprehensive design specification translates the strategic requirements into a tangible iOS architecture. The guiding philosophy is the creation of a **"Personalized Lexical Ecosystem."** Unlike traditional apps that function as isolated destinations, this system permeates the user's digital environment through a "Home Screen Offensive" utilizing iOS 17 interactive widgets, deep system integrations, and intelligent, machine-learning-driven engagement loops. The design prioritizes "Recall Dominance" in study sessions, "Contextual Integrity" in acquisition, and "Invisible Technology" in algorithmic management. Every pixel, transition, and haptic response is engineered to support the "Plateaued Learner"—a user persona characterized by high motivation but low available time, requiring a system that fits seamlessly into the interstices of modern life.

## **2\. Information Architecture and Navigation Paradigms**

The structural foundation of the application must support complex data relationships—linking words to sentences, roots, and review schedules—while maintaining a flat, accessible hierarchy for the user. The architecture rejects deep nesting in favor of immediate access to core loops, specifically optimizing for the "interstitial" nature of mobile usage where sessions may last only seconds.

### **2.1 The Tab Bar Structure: Prioritizing Acquisition**

The application utilizes a standard iOS UITabBar as the primary navigation controller. The ordering of tabs is not arbitrary; it reflects the pedagogical priority of *Input* (Acquisition) as the primary driver of lexical growth, with *Review* (Maintenance) serving as the supporting engine. This aligns with the strategic shift from rote drills to "rich, authentic input".1

The following table outlines the Tab Bar architecture:

| Tab Name | SF Symbol Icon | Semantic Purpose | Primary View Controller Components |
| :---- | :---- | :---- | :---- |
| **Home (Reader)** | book.fill | Discovery & Input | **Curated Feed:** A algorithmic stream of articles/videos tailored to the user's level. **Importer Bridge:** Access to the share extension inbox. **Status Dashboard:** Visual density of "New" vs. "Known" words. |
| **Review** | rectangle.stack.fill | Retention Engine | **SRS Queue:** The primary study interface. **Brain Boost Triage:** Short-term recovery queue for failed items. **Deck Management:** Settings for FSRS optimization. |
| **Explore** | network | Morphology | **Word Matrix:** Force-directed graph of word families. **Etymology Trees:** Historical root visualization. **Search:** Deep dictionary lookup with corpus data. |
| **Stats** | chart.bar.xaxis | Metacognition | **Forgetting Curve:** Visualization of memory decay. **Heatmap:** Daily consistency tracking. **Growth Chart:** Velocity of lexical acquisition. |
| **Profile** | person.circle | Configuration | **Sync Status:** CRDT merge logs. **Notification Settings:** "Bandit" algorithm preferences. **Voice Settings:** TTS accent and speed control. |

### **2.2 Deep Linking and Widget Handoff Protocols**

A critical architectural requirement is the seamless transition from the "Home Screen Offensive" widgets to the main application. The Widget ecosystem is not merely a display surface but a functional extension of the app. Therefore, the Information Architecture must support complex deep linking that preserves the user's flow.

When a user interacts with a widget—for example, tapping on the "Word of the Day"—the system must not simply launch the HomeViewController. Instead, it must utilize a specific URL scheme (e.g., lexicalapp://word/{lemma\_id}) to instantiate a detail view directly on top of the current context. Similarly, tapping the background of the "Micro-Dose" widget during a review session should launch the app directly into the ReviewViewController, passing the current card's unique identifier to ensure continuity. This prevents the "ghost card" phenomenon, where a user might review a word on a widget, open the app, and see the same word again due to sync latency. The architecture mandates that the SceneDelegate handles these incoming URL contexts by modifying the TabBarController's selected index and pushing the relevant view controller onto the navigation stack without animation, creating the illusion of a continuous workspace.1

### **2.3 The "Thumb Zone" Mandate and Ergonomics**

Mobile interaction is predominantly thumb-driven. Research into "Thumb Zone" ergonomics indicates that the comfortable reach for a user holding a device one-handed is restricted to the bottom third of the screen.2 The design specification mandates that all primary "Write" actions—specifically grading flashcards, capturing new words, and confirming edits—must reside within this zone.

The "Thumb Zone" mandate explicitly prohibits placing high-frequency actions, such as the "Mark as Known" button or the "Add to Deck" confirmation, in the top navigation bar (a common pattern in iOS development). Instead, the design utilizes "Floating Action Buttons" (FABs) or fixed bottom toolbars. For the "Tap-to-Capture" interaction, the system employs UISheetPresentationController (Bottom Sheets) with a medium detent. This ensures that when a user taps a word in the top half of the screen, the interaction pane slides up from the bottom, meeting their thumb, rather than forcing a reach to the center or top. This ergonomic consideration is vital for the "Plateaued Learner" who may be studying while commuting, holding a coffee, or standing in a crowded train, necessitating one-handed operation.4

## **3\. Visual Identity System (VIS) and Accessibility**

The visual identity of the Target System is utilitarian and semantic. Unlike gamified apps that use color for decoration and reward, this system uses color to encode data: specifically, the memory state of vocabulary.

### **3.1 The Acquisition Palette: Functional Color Theory**

The core mechanic of the "Immersive Reader" is the real-time categorization of words into three states: **New (Blue)**, **Learning (Yellow)**, and **Known (White)**.1 This "traffic light" system provides immediate feedback on text difficulty and learner progress. However, implementing this requires rigorous attention to accessibility, particularly for users with color vision deficiencies (CVD) such as Deuteranopia or Tritanopia, and to ensure sufficient contrast ratios for readability.

Research indicates that yellow text on a white background is almost universally inaccessible due to low contrast.5 Therefore, the design specifies the use of **background highlights** (simulating a marker pen) rather than changing the text color itself for the "Learning" state.

The following table defines the semantic color tokens for Light and Dark modes, ensuring WCAG AA compliance:

| Semantic State | Token Name | Light Mode (Hex/Opacity) | Dark Mode (Hex/Opacity) | WCAG Contrast | Usage Rationale |
| :---- | :---- | :---- | :---- | :---- | :---- |
| **New (Unknown)** | vocab.new.bg | \#E3F2FD (Blue 50\) | \#1565C0 (Blue 800\) | 4.5:1 (Text) | Represents "Cool" potential. Highlight indicates interactivity. |
| **Learning (SRS)** | vocab.learning.bg | \#FFF9C4 (Yellow 50\) | \#FBC02D (Yellow 700\) | 15:1 (Text) | Represents "Hot/Active" memory. Yellow alerts the user to focus. |
| **Known (Passive)** | vocab.known.bg | Transparent | Transparent | 21:1 (Text) | Absence of color signifies mastery/safety. Standard text color. |
| **Root (Morphology)** | vocab.root.bg | \#E8F5E9 (Green 50\) | \#2E7D32 (Green 800\) | 4.5:1 (Text) | Used in the "Explore" tab to signify the generative root of a word. |
| **Critical/Fail** | ui.alert.error | \#FFEBEE (Red 50\) | \#C62828 (Red 800\) | 4.5:1 (Text) | Used for "Again" grading and high-urgency notifications. |

To support users who cannot distinguish between the Blue and Yellow hues (Tritanopia), the design includes a **"Pattern Mode"** toggle in the Accessibility settings. When enabled, this applies a secondary visual cue:

* **New Words:** Dotted Underline (NSUnderlineStylePatternDot).  
* **Learning Words:** Solid Highlight \+ Dashed Underline (NSUnderlineStylePatternDash).  
* **Known Words:** No decoration. This dual-coding strategy ensures that color is never the sole vector of information, adhering to strict accessibility guidelines.7

### **3.2 Typography: Optimizing for Recognition vs. Recall**

The typographic system is bifurcated to support the two distinct cognitive modes of the application: *Reading* (flow/recognition) and *Studying* (focus/recall).

* **Interface and Controls:** The application utilizes **San Francisco (SF Pro)** for all UI elements, navigation titles, and control labels. This ensures the app feels native to the iOS platform and leverages the system's optimized legibility at small sizes.1  
* **Immersive Content:** For the "Reader" tab, where users consume long-form articles, the design mandates **New York (SF Serif)**. Research suggests that serif fonts guide the eye more effectively along horizontal lines of text, reducing eye strain during extended reading sessions on high-density displays.8  
* **Lexical Isolation:** Within the Flashcard interface, the target word (Lemma) is rendered in **SF Pro Rounded**. This subtle typographic shift visually distinguishes the word as an "object" to be manipulated and memorized, separating it from the context sentence which remains in the standard serif or sans-serif face.

All text elements must support **Dynamic Type**. The "Immersive Reader" text engine (built on TextKit 2\) is required to reflow content and adjust highlight bounds dynamically as the user changes their preferred text size in iOS settings. This is a non-negotiable requirement for an app focused on reading.7

## **4\. The Home Screen Offensive: Interactive Widget Ecosystem**

The strategic differentiator of the Target System is its aggressive utilization of the Home Screen. By moving the core interaction loop *outside* the application sandbox, we lower the barrier to entry for study. The design leverages iOS 17's **App Intents** architecture to create widgets that are not merely informational but fully interactive.1

### **4.1 The "Micro-Dose" Flashcard Widget**

**Objective:** Enable "interstitial learning"—clearing 5-10 cards while waiting for a coffee or bus—without the cognitive load of opening the app. **Technical Constraints:** iOS Widgets operate with limited memory and cannot support continuous gestures (like scrolling) or complex Core Animation transitions (like 3D flips).9

**Design Specification (SystemMedium & SystemSmall):**

* **Layout:** The widget is divided into two logical states, managed via a timeline reload.  
* **State 1: The Challenge (Front)**  
  * **Visuals:** The widget displays the context sentence with the target word occluded (Cloze deletion). The text is high-contrast (black on white or white on dark grey).  
  * **Action:** A prominent "Reveal" button is placed at the bottom. Tapping this triggers an AppIntent that updates the widget's local state.  
* **State 2: The Resolution (Back)**  
  * **Transition:** Due to the lack of 3D flip support, the transition is a **cross-dissolve**. The Cloze gap is filled with the target word, highlighted in the "Learning" yellow.  
  * **Grading Interface:**  
    * **Medium Widget:** Displays the full array of FSRS grading buttons (Again, Hard, Good, Easy).  
    * **Small Widget:** Due to touch target limitations, the Small widget collapses the grading into a binary choice: **"Forgot" (Red)** and **"Recalled" (Green)**. "Forgot" maps to the FSRS Again rating, while "Recalled" maps to Good.11  
* **Optimistic UI:** When a user grades a card, the widget must immediately display the next card. The data update (calculating the new interval) happens asynchronously in the background. If the background update fails (e.g., no internet), the widget must queue the grade locally and sync later, ensuring no data loss.1

### **4.2 The "Word of the Day" (WOTD) Widget**

**Objective:** Discovery and habit formation.

**Design Specification:**

* **Content Strategy:** Unlike traditional WOTD widgets that are static for 24 hours, this widget supports **"Smart Rotation."** A "Shuffle" button allows the user to cycle through high-frequency words they haven't encountered yet.  
* **Audio Integration:** A speaker icon is prominently displayed. Tapping it triggers an AudioPlaybackIntent. To ensure zero latency, the audio files for the current WOTD queue are cached in the shared App Group container, allowing the widget to play pronunciation without launching the main app.10  
* **Capture Mechanic:** A "+" button sits in the top right corner. Tapping it executes a "Capture" intent, adding the word to the user's SRS deck. The icon instantly morphs into a checkmark to provide feedback.

### **4.3 The "Streak Keeper" Widget**

**Objective:** Visualizing "Loss Aversion" to drive daily engagement.1 **Design Specification (Lock Screen Accessory):**

* **Visual Metaphor:** A minimalist circular gauge.  
* **Data Visualization:** The ring represents the daily review goal (e.g., 20 words). As the user reviews words, the ring fills.  
* **Contextual Urgency:** The widget is context-aware.  
  * *Normal State:* Brand colors (Blue/Green).  
  * *Danger State:* If the time is past 8:00 PM and the goal is \<50% complete, the ring turns **Alert Orange** and a small "\!" icon appears. This visualizes the impending "loss" of the streak, triggering the user's impulse to "save" their progress.13

## **5\. Core Interaction Design: The Retention Engine (In-App)**

The "Review" tab is the functional heart of the application. The interaction design here must balance the mathematical precision of the FSRS algorithm with the pedagogical goal of "Recall Dominance."

### **5.1 Flashcard UX: Recall Dominance**

The fundamental principle of the flashcard interface is that the answer must never be shown passively. The user must actively retrieve the information.

**Screen Anatomy and Interaction:**

1. **The Prompt (Front):**  
   * The screen is dominated by the **Context Sentence**. The target word is replaced by a blank space \[ \_\_\_\_\_ \].  
   * **Distraction-Free:** No grading buttons are visible. No navigation bars are visible. The focus is entirely on the text.  
   * **Multimedia Anchor:** If the word was captured from a video source (e.g., YouTube), a thumbnail appears. Tapping it plays the specific 5-second clip where the word is spoken, providing prosodic context.1  
2. **The Interaction:**  
   * The entire screen acts as a gesture target. A tap anywhere reveals the answer. This removes the cognitive load of hunting for a "Show Answer" button.  
3. **The Resolution (Back):**  
   * **Transition:** Rather than a skeletal 3D flip, the design uses a **"Morph" transition**. The \[ \_\_\_\_\_ \] gap expands and fills with the target word, highlighted in Yellow. Additional metadata (definition, phonetic IPA, morphological root) fades in below the sentence.  
   * **Grading Array (The Thumb Zone):** The FSRS algorithm relies on four inputs: Again, Hard, Good, Easy.14 These buttons appear *fixed* at the bottom of the screen.  
     * **Again:** Red tint / xmark.circle icon / Haptic: Heavy Impact.  
     * **Hard:** Orange tint / exclamationmark.circle icon / Haptic: Medium Impact.  
     * **Good:** Blue tint / checkmark.circle icon / Haptic: Light Impact.  
     * **Easy:** Green tint / star.circle icon / Haptic: Success Notification.  
   * **Feedback:** Upon grading, a "toast" notification momentarily appears (e.g., "Review in 4 days"), explicitly visualizing the spacing effect to the user.9

### **5.2 The "Brain Boost" Triage Visualization**

Standard SRS algorithms often schedule failed cards for "tomorrow." This is inefficient for immediate learning. The Target System implements a "Brain Boost" loop where failed cards reappear within the *same* session.1

**UI Differentiation:**

When a card re-enters the queue via Brain Boost:

* **Visual Mode:** The background of the card shifts slightly (e.g., a subtle warm tint \#FFF8E1) or acquires a pulsing orange border. This signals to the user: "This is a short-term drill, not a long-term review."  
* **Progress Indicator:** A distinct circular progress indicator appears in the top-right corner of the card, visualizing the "graduation" criteria (e.g., 2 consecutive correct answers needed to exit Brain Boost).1

## **6\. Contextual Acquisition: The Immersive Reader UI**

This module creates the environment for "Contextual Incidental Learning," transforming passive reading into active collection.

### **6.1 TextKit 2 Rendering and Interaction**

The Reader View must handle potentially long texts (book chapters) with thousands of interactive tokens. The design specifies the use of **TextKit 2** for high-performance rendering. Unlike UIWebView, TextKit 2 allows for native text handling with custom attribute rendering for the "Blue/Yellow" highlights.

**Interaction Model:**

* **Single Tap:** Selects a word. The word highlights (inverting color) and the **"Capture Card"** slides up.  
* **Long Press:** Triggers **Collocation Selection**. The NLP engine expands the selection to include surrounding words that form a statistically significant phrase (e.g., tapping "decision" might select "make a decision"). The Capture Card then offers to save the *phrase* rather than the isolated word.1

### **6.2 The "Capture Card" (Bottom Sheet)**

This component is the bridge between consumption and retention.

* **Sheet Architecture:** A standard iOS sheet with a medium detent. This keeps the user's context (the article) visible in the background.  
* **Content:**  
  * **Header:** The Word (Lemma) \+ Pronunciation.  
  * **Frequency Badge:** A badge indicating the word's rank in the COCA corpus.  
    * *High Frequency (1-5000):* Green Badge. "Essential."  
    * *Mid Frequency (5000-15000):* Yellow Badge. "Advanced."  
    * *Low Frequency (15000+):* Red Badge. "Rare."  
    * *Strategic Ignoring:* If a beginner user taps a "Rare" word, a warning banner appears: *"This word is very rare. Focus on high-frequency words first?"*.1  
  * **Context Editing:** The sentence from the article is pre-filled. The user can edit this sentence to make it a better flashcard prompt (e.g., shortening it).  
  * **Action:** A large "Add to Deck" button.  
* **Visual Feedback:** Upon adding, the sheet dismisses, and the word in the article performs a **color transition animation** from Blue (New) to Yellow (Learning), visually confirming the capture.

### **6.3 The Safari Extension (Importer Bridge)**

To support the "Personalized Lexical Ecosystem," the design includes a Safari Action Extension.

* **DOM Injection:** The extension injects a JavaScript layer into web pages (e.g., NYTimes, Wikipedia).  
* **UI Consistency:** This layer applies the same CSS styling as the native app (Blue highlights for new words).  
* **Performance:** To prevent rendering lag on complex websites, highlights are "lazy loaded" only for the viewport as the user scrolls.  
* **Interaction:** Tapping a highlighted word in Safari opens a lightweight HTML overlay that replicates the native "Capture Card," allowing users to save words without leaving the browser.1

## **7\. Structural Analysis: The Morphology Matrix**

This feature targets the analytical learner, visualizing *why* a word means what it means. It shifts the mental model from "memorizing strings" to "understanding structures."

### **7.1 Force-Directed Graph Visualization**

**Strategy:** Visualize the etymological family tree of a word.1 **Visualization Implementation:**

* **Graph Library:** The design specifies the use of a lightweight force-directed graph library (custom SwiftUI Layout or a library like Grape).15  
* **Node Architecture:**  
  * **Central Node:** The Root (e.g., *SPECT* meaning "to look").  
  * **Branch Nodes:** Prefixes (*IN-*, *RE-*, *SU-*).  
  * **Leaf Nodes:** Derived words (*Inspect, Respect, Suspect*).  
* **Color Coding:** The nodes are colored according to the user's SRS status (Blue/Yellow/Known). This allows the user to instantly see "knowledge gaps"—for example, seeing that they know *Inspect* and *Respect* (White) but *Suspect* is New (Blue), inviting them to "complete the set."

**Interaction Design:**

* **Physics-Based:** The graph should feel organic. Dragging a node pulls its connected neighbors (spring physics), making the structural relationship tactile.  
* **Expansion:** Double-tapping a leaf node (e.g., *Respect*) re-centers the graph on that word, potentially revealing *its* own derivatives (*Respectful, Respectable*), allowing for infinite traversal of the lexical web.16

## **8\. Engagement Architecture: The "Bandit" Notification System**

Static notifications ("It's time to study\!") lead to fatigue. The design implements a dynamic, varied notification strategy based on a "Multi-Armed Bandit" algorithm.1

### **8.1 "Bandit" Visual Templates**

The design supports multiple notification UI templates ("Arms") that the algorithm can choose from:

1. **The "Streak Defense" Arm (Loss Aversion):**  
   * **Visual:** A rich notification displaying the "Streak Flame" icon.  
   * **Content:** "🔥 Your 45-day streak is crumbling\! Save it in 5 minutes."  
   * **Action:** Tapping leads directly to a "Speed Review" session.  
2. **The "Curiosity Gap" Arm:**  
   * **Visual:** A question mark icon.  
   * **Content:** "Do you know the English word for 'Schadenfreude'?"  
   * **Action:** Tapping reveals the word (*Epicaricacy*) and deep-links to its dictionary entry.  
3. **The "Passive-Aggressive" Arm:**  
   * **Visual:** The App Mascot looking skeptical or sad.  
   * **Content:** "These reminders don't seem to be working. We'll stop sending them for now."  
   * **Psychology:** This "break-up" message often triggers a re-engagement effect.1

### **8.2 Interruptibility Modeling**

The system uses the CoreMotion framework to detect user state transitions (e.g., transitioning from "Walking" to "Stationary").

* **Smart Trigger:** If the user has pending reviews and the system detects they have just sat down (e.g., on a bus), a "Smart Notification" is triggered.  
* **Visual Cue:** When this specific notification is tapped, the app launch animation is bypassed, and the user is taken *immediately* to the review screen, minimizing friction during these opportunistic windows.1

## **9\. Data Visualization: The Metacognition Dashboard**

The "Stats" tab visualizes the invisible algorithmic processes, building trust in the system.

* **The Forgetting Curve Plot:** A line chart plotting the user's average Retrievability (![][image1]) over time. It shows a curve dropping from 100% to 90%. A dotted line projects the future: "If you don't study today, your retention will drop to 82%." This makes the abstract cost of skipping a day concrete.17  
* **Retention Heatmap:** A GitHub-style contribution graph (grid of colored squares) showing daily review activity. The intensity of the color (Green) corresponds to the number of cards reviewed, visualizing consistency.

## **10\. Technical Implementation and Asset Guidelines**

### **10.1 Data Synchronization (CRDTs)**

The design assumes an offline-first architecture using Conflict-free Replicated Data Types (CRDTs).

* **UI Implication:** All interactions (grading, capturing) must be **Optimistic**. The UI updates instantly. If the background sync fails, the app retains the state locally. A subtle "Cloud" icon in the Profile tab indicates sync status (Spinning \= Syncing, Checkmark \= Synced, Exclamation \= Offline/Pending).1

### **10.2 Asset Requirements**

* **Vector First:** All iconography must be SVG/PDF vectors to ensure perfect scaling across all device sizes (iPhone SE to iPad Pro).  
* **Dark Mode Compliance:** All assets (especially the "Empty State" illustrations for the review queue) must have specific Light and Dark variants to maintain visual harmony.

## **11\. Conclusion**

This Design Specification outlines a system that is radically different from current market leaders. It does not treat language learning as a game (Duolingo) nor as a spreadsheet (Anki). Instead, it treats it as a **Contextual Ecosystem**.

By rigorously applying **FSRS algorithms** for timing, **Contextual/Morphological** tools for content, and a **Widget-first** interaction model for engagement, the Target System effectively addresses the "intermediate plateau." The strict adherence to accessibility standards, the ergonomic "Thumb Zone," and the seamless handling of "interstitial" micro-sessions ensure that the technology remains invisible, allowing the learner to focus entirely on the complex, rewarding task of acquiring a new language. This is not just an app; it is a cognitive augmentation tool designed for the dedicated learner.

## **12\. References**

* 1 *English Vocabulary App Development Strategy.docx*  
* 1 *iOS App Requirements from Strategy.docx*  
* 9 Apple Developer Documentation on WidgetKit & App Intents.  
* 2 Research on Mobile Ergonomics and the "Thumb Zone".  
* 5 WCAG Accessibility Guidelines and Color Contrast standards.  
* 19 SwiftUI Animation Techniques (Transitions, Matched Geometry).  
* 15 Visualization of Etymological Trees and Force-Directed Graphs.  
* 14 Spaced Repetition Algorithms and Forgetting Curve visualization.  
* 12 Behavioral Psychology in UI (Loss Aversion, Streaks).  
* 7 Typography for Readability and Dynamic Type.

#### **Alıntılanan çalışmalar**

1. English Vocabulary App Development Strategy.docx  
2. Thumb-Zone Optimization: Cut Mobile User Effort by 55% | Medium, erişim tarihi Ocak 24, 2026, [https://medium.com/@webdesignerindia/thumb-zone-optimization-mobile-navigation-patterns-9fbc54418b81](https://medium.com/@webdesignerindia/thumb-zone-optimization-mobile-navigation-patterns-9fbc54418b81)  
3. Designing for thumbs. Why optimising for thumb usability matters in ..., erişim tarihi Ocak 24, 2026, [https://engineering.brighthr.com/blog-post/designing-for-thumbs](https://engineering.brighthr.com/blog-post/designing-for-thumbs)  
4. Design for Touch \- iOS Design Handbook \- Design+Code, erişim tarihi Ocak 24, 2026, [https://designcode.io/ios-design-handbook-design-for-touch/](https://designcode.io/ios-design-handbook-design-for-touch/)  
5. Yellow, Purple, and the Myth of “Accessibility Limits Color Palettes”, erişim tarihi Ocak 24, 2026, [https://stephaniewalter.design/blog/yellow-purple-and-the-myth-of-accessibility-limits-color-palettes/](https://stephaniewalter.design/blog/yellow-purple-and-the-myth-of-accessibility-limits-color-palettes/)  
6. Accessible Color Palette, erişim tarihi Ocak 24, 2026, [https://www.sussex.ac.uk/tel/resource/tel\_website/accessiblecontrast/](https://www.sussex.ac.uk/tel/resource/tel_website/accessiblecontrast/)  
7. Color Contrast \- Accessibility by Design, erişim tarihi Ocak 24, 2026, [https://www.chhs.colostate.edu/accessibility/best-practices-how-tos/color-contrast/](https://www.chhs.colostate.edu/accessibility/best-practices-how-tos/color-contrast/)  
8. Designing a Minimalist Mobile Dictionary App with Color and Type, erişim tarihi Ocak 24, 2026, [https://medium.com/@neema.tambo/designing-a-minimalist-mobile-dictionary-app-with-color-and-type-3cbc3c0338d0](https://medium.com/@neema.tambo/designing-a-minimalist-mobile-dictionary-app-with-color-and-type-3cbc3c0338d0)  
9. Widgets | Apple Developer Documentation, erişim tarihi Ocak 24, 2026, [https://developer.apple.com/design/human-interface-guidelines/widgets/](https://developer.apple.com/design/human-interface-guidelines/widgets/)  
10. Widgetsmith 5: Interactive Widgets for iOS 17 \- David-Smith.org, erişim tarihi Ocak 24, 2026, [https://www.david-smith.org/blog/2023/09/18/widgetsmith-5-interactive-widgets/](https://www.david-smith.org/blog/2023/09/18/widgetsmith-5-interactive-widgets/)  
11. Adding interactivity to widgets and Live Activities \- Apple Developer, erişim tarihi Ocak 24, 2026, [https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)  
12. Eight Mechanics of Gamification | Rocketmakers, erişim tarihi Ocak 24, 2026, [https://www.rocketmakers.com/blog/gamification-mechanics](https://www.rocketmakers.com/blog/gamification-mechanics)  
13. How to design an effective streak. \- Make it Toolkit, erişim tarihi Ocak 24, 2026, [https://www.makeit.tools/blogs/how-to-design-an-effective-streak-2](https://www.makeit.tools/blogs/how-to-design-an-effective-streak-2)  
14. Implementing and Automating the Spaced Repetition System | by ..., erişim tarihi Ocak 24, 2026, [https://doubletapp.medium.com/how-to-remember-and-not-forget-implementing-and-automating-the-spaced-repetition-system-4c011afff83e](https://doubletapp.medium.com/how-to-remember-and-not-forget-implementing-and-automating-the-spaced-repetition-system-4c011afff83e)  
15. SwiftGraphs/Grape: A Swift library for graph visualization ... \- GitHub, erişim tarihi Ocak 24, 2026, [https://github.com/SwiftGraphs/Grape](https://github.com/SwiftGraphs/Grape)  
16. etytree \- SisInfLab, erişim tarihi Ocak 24, 2026, [https://sisinflab.poliba.it/publications/2017/PADS17/etytree%20-%20A%20graphical%20and%20interactive%20etymology%20dictionary%20based%20on%20Wiktionary.pdf](https://sisinflab.poliba.it/publications/2017/PADS17/etytree%20-%20A%20graphical%20and%20interactive%20etymology%20dictionary%20based%20on%20Wiktionary.pdf)  
17. Review \- Spaced Repetition \- Apps on Google Play, erişim tarihi Ocak 24, 2026, [https://play.google.com/store/apps/details?id=fred.tasks](https://play.google.com/store/apps/details?id=fred.tasks)  
18. How to use interactive widgets in iOS 17 \- AppleInsider, erişim tarihi Ocak 24, 2026, [https://appleinsider.com/inside/ios-17/tips/how-to-use-interactive-widgets-in-ios-17](https://appleinsider.com/inside/ios-17/tips/how-to-use-interactive-widgets-in-ios-17)  
19. Animating views and transitions — SwiftUI Tutorials \- Apple Developer, erişim tarihi Ocak 24, 2026, [https://developer.apple.com/tutorials/swiftui/animating-views-and-transitions](https://developer.apple.com/tutorials/swiftui/animating-views-and-transitions)  
20. Mastering SwiftUI Animations in iOS 17+: Smooth Transitions ..., erişim tarihi Ocak 24, 2026, [https://medium.com/@sanjaychavare1/mastering-swiftui-animations-in-ios-17-smooth-transitions-matchedgeometryeffect-beyond-03b89be3f463](https://medium.com/@sanjaychavare1/mastering-swiftui-animations-in-ios-17-smooth-transitions-matchedgeometryeffect-beyond-03b89be3f463)  
21. Flip a card in SwiftUI | Software Development Notes, erişim tarihi Ocak 24, 2026, [https://swdevnotes.com/swift/2021/flip-card-in-swiftui/](https://swdevnotes.com/swift/2021/flip-card-in-swiftui/)  
22. Gamification That Works \- Behavioral Design That Makes A Difference, erişim tarihi Ocak 24, 2026, [https://imotions.com/blog/insights/research-insights/gamification-that-works/](https://imotions.com/blog/insights/research-insights/gamification-that-works/)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAYCAYAAAAlBadpAAAAy0lEQVR4Xu2SMQ8BURCER6XSqiVahd8gWr3/4g8olCqVH6KlUGkQnUonR0hEEGaz7708e+/UivuSSS4zs5fbzQElI+pMvZ1u1JF6RF7Dl4vwRcsM6jdtECOFuTVJB5qtbeDpQwtdG5AJNJsaP7BB+pOFonUCqUKbelJ74+eQQbnwklpRd+dV41IKv68cJmbr/J/skC4NoX7dBjGpfYUr1K/YIEYKC2ui+KWBAbTQswHyw+F5TF2oDHrlE/XyoaMFHThA//fad1zy53wAhPQ9J2j9tisAAAAASUVORK5CYII=>