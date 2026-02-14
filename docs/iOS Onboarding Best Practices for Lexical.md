# **Strategic Onboarding Architecture for Lexical: Orchestrating the First-Run Experience for the Plateaued Learner in iOS 26**

## **1\. Executive Summary: The Imperative of "Invisible" Onboarding**

The development of "Lexical," a next-generation vocabulary acquisition system, represents a significant departure from the prevailing paradigms of Mobile Assisted Language Learning (MALL). Unlike market leaders that prioritize gamified habit formation through simplified interactions, Lexical targets the "intermediate plateau"—a critical phase where learners stagnate between passive recognition and active retrieval.1 This strategic positioning necessitates a fundamentally different approach to user onboarding. The objective is not merely to teach interface mechanics but to align the user’s mental model with the application’s sophisticated hybrid architecture: the synthesis of Algorithmic Retention (FSRS), Contextual Acquisition (Immersive Reader), and Structural Analysis (Morphology).1

In the context of iOS 26, the onboarding experience serves as the bridge between the user's desire for fluency and the application's "Invisible Technology." The onboarding architecture must mitigate the inherent friction of advanced tools (like Anki) while avoiding the superficiality of gamified apps (like Duolingo).1 It must leverage the latest iOS capabilities—specifically the Passkey Account Creation API, Liquid Glass UI design system, and Interactive Widgets—to create a "Personalized Lexical Ecosystem" that permeates the user's digital life.4

This report outlines a comprehensive onboarding strategy for Lexical. It details the psychological, technical, and design mandates required to convert a high-motivation "Plateaued Learner" into a long-term active user. The analysis integrates over 150 research artifacts and specific project documentation to provide a granular blueprint for execution.1 The ultimate goal is to reduce the "Time-to-Value" to near-zero by moving core interactions outside the app sandbox and establishing trust in the algorithmic "Bandit" engines that drive engagement.1

## **2\. Strategic Context: The Cognitive Ergonomics of the First Run**

### **2.1 Analyzing the "Plateaued Learner" Persona and Pain Points**

Designing an effective onboarding flow requires a precise, data-driven understanding of the target user. The "Plateaued Learner" is distinct from the casual beginner who might be satisfied with basic gamification. This persona is characterized by high motivation but low available time, often squeezing study sessions into the "interstices of modern life"—waiting for coffee, commuting, or momentary breaks.4 They likely have a history of failed attempts with other apps, leading to skepticism regarding new tools. They suffer from the "Intermediate Plateau," a cognitive state where they can recognize words in passive contexts (like reading) but fail to retrieve them in active contexts (like speaking).1

Therefore, the Lexical onboarding must avoid generic "Welcome to the App" rhetoric. Instead, it must immediately demonstrate competence and depth. The "Trust Gap"—the distance between the app's promise and the user's belief—must be bridged instantly.6 This is achieved not by promising fluency, but by visualizing the mechanisms that will deliver it: the **Ebbinghaus Forgetting Curve** and the **Spaced Repetition System (SRS)**.1

The onboarding must address specific pain points identified in the strategy documents:

* **The Retrieval Gap:** Users need to know *immediately* that this app forces active recall, not just passive recognition.  
* **High Friction:** Advanced tools like Anki are powerful but unusable for the average mobile user. Lexical must prove in the first 60 seconds that it offers Anki-level power with Apple-level design.1  
* **Notification Fatigue:** This user is tired of "It's time to study\!" pestering. The onboarding must sell the "Bandit" algorithm—an intelligent agent that respects their time.4

### **2.2 The Shift from "How-To" to "Why-To"**

Traditional onboarding focuses on functional instruction: "Tap here to do X." For Lexical, the complexity of the **Free Spaced Repetition Scheduler (FSRS v4.5)** requires a shift to pedagogical instruction: "Why does the app schedule this card for 4 days?".6 Users familiar with static intervals (Day 1, Day 3\) must be re-educated on dynamic stability and difficulty metrics.

The onboarding flow must function as a micro-course in cognitive science, simplifying complex algorithmic concepts into intuitive visual metaphors. For instance, visualizing memory decay not as a mathematical formula, but as a "leaky bucket" that the FSRS algorithm patches at the optimal moment.10 This educational component is critical because FSRS relies on accurate user grading; if a user treats the "Hard" button as "I didn't know it" rather than "I recalled it with effort," the algorithm's predictive power collapses.11

### **2.3 The "Time-to-First-Wow" Mandate**

Research indicates that the average app loses 75% of users within the first 72 hours.13 To combat this, Lexical must deliver a "First-Wow" moment within the first 60 seconds.13 For Lexical, this "Wow" is not a badge or a streak animation—it is the realization of **Contextual Integrity**.

The onboarding must culminate in the user capturing a word from a real-world context (e.g., a news article or video transcript) and seeing it instantly transformed into a cloze-deletion flashcard.1 This demonstrates the "Input-First" mandate: distinguishing Lexical as a tool for consuming content, not just drilling isolated words.4 The user needs to feel that the app is an "Importer Bridge" that turns the entire internet into a textbook.

### **2.4 The Role of "Invisible Technology"**

The Lexical Project Plan emphasizes "Invisible Technology".4 The onboarding should not expose the raw CRDT sync logs or the FSRS coefficients unless the user digs for them. Instead, the first run must emphasize that the *complexity is handled by agents*. The user provides the input (reading, grading), and the system handles the logistics (scheduling, syncing, notifying). This creates a sense of relief for the Plateaued Learner, who is often overwhelmed by the management overhead of self-study.6

## **3\. Identity and Security: The Frictionless Entry**

### **3.1 Leveraging iOS 26 Passkey Account Creation API**

The barrier to entry for any app is the registration wall. Traditional username/password flows are high-friction and insecure. For Lexical, which requires data synchronization across the "Personalized Lexical Ecosystem" (iPhone, iPad, Mac), identity management is foundational.14 The onboarding must leverage the **iOS 26 Passkey Account Creation API** to eliminate passwords entirely.5

#### **3.1.1 Implementation Patterns**

* **The Zero-Typing Flow:** Instead of a form, the user is presented with a native system sheet (ASAuthorizationAccountCreationProvider). This sheet pre-fills the user's name and email from their Apple ID.  
* **Biometric Binding:** A single FaceID or TouchID scan generates a unique cryptographic key pair stored in the iCloud Keychain.16 This replaces the password.  
* **Copy Strategy:** The button should not say "Register." It should say "Create Secure Passkey" or "Continue with FaceID." This reframes registration as a security feature rather than a chore.18  
* **Automatic Upgrades:** If a user somehow has a legacy account, the system should trigger an "Automatic Passkey Upgrade" upon their first sign-in, migrating them to the passwordless future without friction.5

#### **3.1.2 Strategic Advantage**

This approach reduces onboarding friction by approximately 60-80% compared to traditional forms.19 It aligns with the "Invisible Technology" philosophy, making security transparent to the user. It also ensures that the "Personalized Lexical Ecosystem" is instantly available on all the user's Apple devices via iCloud Keychain sync, a critical requirement for the offline-first CRDT architecture.14

### **3.2 Privacy and Trust Architecture**

Given Lexical's reliance on "Bandit" algorithms for notification scheduling and "Core Motion" for interruptibility modeling, establishing privacy trust during account creation is paramount.4

* **Data Minimization:** The onboarding must explicitly state that motion data (used to detect "Sitting" vs. "Walking" states) is processed *on-device* and never transmitted to the cloud.14  
* **Transparency:** Utilizing the iOS "Privacy Nutrition Label" standards within the onboarding flow itself—rather than burying them in the App Store—builds credibility with the privacy-conscious "Plateaued Learner".20  
* **Bloom Filter Explanation:** For the Safari Extension, advanced users may worry about privacy. The onboarding should briefly explain the **Bloom Filter Optimization**: "We use on-device Bloom Filters to check for known words. Your browsing history never leaves your device".6 This technical assurance builds trust.

## **4\. The Pedagogical Handshake: Calibrating the Engines**

Once identity is established, the user enters the "Pedagogical Calibration" phase. This is the most critical section of Lexical’s onboarding, where the user is taught *how to learn* within the system. It replaces the traditional "tutorial" with an interactive calibration session.

### **4.1 Visualizing the Forgetting Curve (Metacognition)**

Before a single word is taught, Lexical must justify its existence. The "Stats" tab's forgetting curve visualization should be brought forward into the onboarding flow.4

* **The Visualization:** An animated line graph showing a memory trace decaying from 100% to near zero over time. As the user watches, a vertical "Review" bar intercepts the curve just before it drops, boosting the memory back to 100% and flattening the decay rate.8  
* **The Copy:** "Most apps let you forget. Lexical calculates the exact moment you are about to lose a memory and intervenes. We call this the 'Edge of Forgetting'."  
* **User Action:** The user taps a "Stabilize Memory" button to trigger the animation, physically enacting the concept of active intervention. This creates a "lightbulb moment" regarding the efficacy of Spaced Repetition.8

### **4.2 Calibrating the FSRS Engine (Grading Scale Education)**

The **Free Spaced Repetition Scheduler (FSRS)** is the mathematical heart of Lexical. Unlike simple "Thumbs Up/Down" systems, FSRS requires nuanced grading: Again, Hard, Good, Easy.1 Misuse of these buttons (e.g., using "Hard" for failed cards) corrupts the algorithm.11 The onboarding must simulate a review session to teach this grading logic.

#### **4.2.1 The Mock Review Simulation**

The onboarding includes a "Mock Review" session with dummy cards to teach the buttons:

* **Scenario 1 (Failure \- "Again"):** The user is shown a difficult/obscure word. They are guided to press **"Again" (Red)**.  
  * *Feedback:* "Use this when you cannot recall the word. The card will re-enter the 'Brain Boost' queue immediately.".4  
* **Scenario 2 (Struggle \- "Hard"):** The user is shown a word they recognize but hesitate on. They press **"Hard" (Orange)**.  
  * *Feedback:* "Use this when you remember, but it takes mental effort. We will schedule it sooner. Do not use this if you forgot the word\!".12  
* **Scenario 3 (Success \- "Good"):** The user presses **"Good" (Blue)**.  
  * *Feedback:* "The standard rating. You recalled it with normal effort."  
* **Scenario 4 (Mastery \- "Easy"):** The user presses **"Easy" (Green)**.  
  * *Feedback:* "You know this instantly. We won't show it for a long time."

#### **4.2.2 The "Memory Battery" Metaphor**

To explain FSRS variables without jargon, use a **"Memory Battery"** metaphor during this simulation.6

* **Retrievability (R) \= Charge Level:** Show a battery draining over time.  
* **Stability (S) \= Battery Capacity:** Explain that every successful review "upgrades the battery," making the charge drain slower.  
* **Difficulty (D) \= Energy Drain Rate:** Harder words drain the battery faster.  
* This metaphor simplifies the formula ![][image1] into a concept any user can understand: "Keep the battery charged.".22

### **4.3 The "Brain Boost" Triage Demonstration**

Standard SRS apps punish failure by scheduling the card for the next day, breaking the immediate learning loop. Lexical's "Brain Boost" keeps failed cards in the current session.1

* **The Demo:** During the mock review, after the user presses "Again," the card visually "shuffles" back into a short stack of cards. A counter appears: "Reappearing in 3 steps."  
* **The Payoff:** Three interactions later, the card reappears with a **pulsing orange border** and a specific background tint (\#FFF8E1).4 This visual cue teaches the user to distinguish "Short-Term Triage" from "Long-Term Review."

## **5\. Design System Integration: The Liquid Glass UI**

Lexical utilizes the iOS 26 "Liquid Glass" design system. This aesthetic—translucent, physics-based materials that refract light—is not merely decorative; it encodes hierarchy and state.14 The onboarding must acclimate the user to this new visual language.

### **5.1 Teaching "Contextual Integrity" via UI**

The onboarding must demonstrate that the UI is subservient to the content. The "Immersive Reader" walkthrough should be a central part of the first run.

* **The "Traffic Light" System:** The user is presented with a sample text. The onboarding highlights the color system:  
  * **Blue Words (New):** "Tap to Capture." The tutorial guides the user to tap a blue word (\#E3F2FD).  
  * **Yellow Words (Learning):** The word instantly morphs to yellow (\#FFF9C4). "Now Learning."  
  * **White Words (Known):** "Ignored words are assumed known."  
* **The Capture Card Interaction:** Tapping a blue word triggers the UISheetPresentationController (Bottom Sheet). The onboarding highlights the ergonomic **"Thumb Zone"** placement of the "Add to Deck" button.4 The user must explicitly perform the "Add" action to proceed, reinforcing the "Tap-to-Capture" behavior.

### **5.2 Liquid Glass Coach Marks**

Instead of using opaque overlays that obscure the interface, onboarding tips should use **Liquid Glass Tooltips**. These are frosted, semi-transparent bubbles that float above the UI, blurring the background slightly to draw focus to specific elements (like the "Explore" tab icon) without breaking immersion.23

* **Morphing Transitions:** When the user completes a step, the Glass tooltip should fluidly morph into the next UI element (e.g., transforming from a welcome bubble into the "Review" button), demonstrating the fluid physics of the iOS 26 design language.14

### **5.3 Accessibility: The "Pattern Mode" Check**

While "Liquid Glass" is beautiful, it can be an accessibility challenge. The onboarding must offer an "Accessibility Check" early on.4

* **The Readability Test:** Display sample text with the standard "Blue/Yellow" highlights. Ask: "Is this easy to read?"  
* **The Fallback:** If the user selects "No" or "Make it Clearer," instantly toggle **Pattern Mode**.  
  * Blue highlights gain **Dotted Underlines**.  
  * Yellow highlights gain **Dashed Underlines**.  
  * Translucency is reduced (fallback to opaque backgrounds).  
* **Persistence:** Save this preference immediately to UserDefaults or AppStorage so it propagates to the Reader and Widgets instantly.26

## **6\. The Home Screen Offensive: Widget Onboarding**

A critical USP of Lexical is the ability to study without opening the app via iOS 17 Interactive Widgets.4 Traditional onboarding ignores this "outside-the-app" experience. Lexical must aggressively onboard the user to the Home Screen to facilitate "Interstitial Learning."

### **6.1 The "Close the App" Challenge**

* **The Prompt:** At a key moment in onboarding, the app should pause and present a challenge: "Lexical lives on your Home Screen. Close the app now to add your first Widget."  
* **The Guide:** Before closing, a short video loop demonstrates the iOS "Jiggle Mode" and the process of adding the **"Micro-Dose" Widget**.27  
* **The Reward:** Once the widget is added and the user interacts with it (e.g., completing a single review on the Home Screen), the main app detects this event (via shared App Groups/UserDefaults) and unlocks a "Widget Master" badge or achievement upon the next launch.14

### **6.2 Configuring the "Word of the Day" (WOTD)**

The onboarding should guide the user to add the WOTD widget for "Discovery."

* **Smart Rotation:** Explain that this widget isn't static. Tapping it refreshes the word. The onboarding copy should emphasize: "Refresh your vocabulary every time you unlock your phone".4  
* **Audio Intent:** Explicitly mention that tapping the speaker icon on the widget plays audio instantly without launching the app, a feature enabled by the App Intent architecture.14

## **7\. The Importer Bridge: Safari Extension Onboarding**

The ability to capture words from any website is Lexical's "Killer Feature" for contextual learning. However, enabling Safari Extensions on iOS is a high-friction process involving multiple steps in the Settings app.30

### **7.1 The "Deep Link" Simulation**

Since iOS does not allow direct deep-linking to the specific Safari Extension toggle in Settings, Lexical must simulate the flow to build muscle memory.30

* **Interactive Simulation:** The app displays a mock Safari browser view. The user must tap the "AA" icon, select "Manage Extensions," and toggle "Lexical Importer" within the simulation to proceed. This effectively "trains" the user on the OS-level UI patterns they will encounter.32  
* **The Hook:** Explain the value proposition clearly: "Turn the New York Times into your textbook." Show a visualization of a web article being "scanned" and blue words appearing.1

### **7.2 The "Status Check" Loop**

Use a polling mechanism to check if the extension is enabled.

* **State:** Display a "Waiting for Activation..." spinner in the onboarding flow.  
* **Action:** When the user successfully enables the extension in Settings and returns to the app, the spinner turns into a **Green Checkmark** with a haptic success pulse. This closes the feedback loop and confirms the setup was successful.31

## **8\. Permission Architecture: Contextual Priming**

Lexical requires sensitive permissions: **Notifications** (for the Bandit algorithm) and **Core Motion** (for interruptibility modeling). Requesting these upfront is a UX anti-pattern that leads to high denial rates.21

### **8.1 The "Bandit" Algorithm Prime (Notifications)**

* **The "Why":** Do not ask "Allow Notifications?" Ask "Do you want us to find the best time for you to study?"  
* **The Explanation:** "Lexical uses a smart 'Bandit' algorithm that learns when you are most likely to study. It stops bothering you if you are busy and nudges you when you are free. We promise: No spam, just science.".4  
* **The Trigger:** Only request the system permission *after* the user accepts this value proposition button labeled "Turn on Smart Nudges."

### **8.2 The "Interruptibility" Prime (Core Motion)**

* **The "Why":** Lexical detects when a user transitions from "Walking" to "Sitting" (e.g., entering a train) to suggest a micro-session.  
* **The Explanation:** "Lexical can sense when you're settling in for a commute. Enable Motion & Fitness to get 'Transition Nudges'—perfect for filling dead time.".14  
* **Privacy Assurance:** "Motion data is processed strictly on your iPhone. We don't track your location.".38

## **9\. Phase-Gate Onboarding Structure & Flow**

The onboarding process is structured into distinct phases to manage cognitive load. This table outlines the specific flow, interaction models, and success metrics for each phase.

| Phase | Screen / Step | Objective | Interaction Model | Success Metric |
| :---- | :---- | :---- | :---- | :---- |
| **1\. Identity** | **Welcome / Account** | Zero-friction entry via Passkeys. | Single-tap "Continue with Passkey" sheet. | Successful Account Creation via FaceID/TouchID. |
| **2\. Philosophy** | **Forgetting Curve** | Visualize the problem (memory decay). | Tap to "Stabilize" graph animation. | User interaction with graph. |
| **3\. Calibration** | **FSRS Mock Review** | Teach grading buttons (Again, Hard, Good, Easy). | Simulation of reviewing 3 cards. "Memory Battery" metaphor. | Correct grading of mock cards. |
| **4\. Acquisition** | **Immersive Reader** | Teach "Blue/Yellow/Known" states & "Thumb Zone". | Tap blue word \-\> Bottom sheet \-\> "Add". | User captures 1 word. |
| **5\. Expansion** | **Widget Setup** | Install Home Screen "Micro-Dose" widget. | Video guide \+ "Close App" challenge. | Widget installed & interacted with. |
| **6\. Extension** | **Safari Importer** | Enable Safari Extension. | Interactive simulation of Safari Settings. | Extension enabled (verified via App Group check). |
| **7\. Permissions** | **Bandit & Motion** | Enable Smart Nudges & Interruptibility. | Contextual priming modals \-\> System prompt. | Permissions granted \> 60%. |
| **8\. Metacognition** | **Stats & Explore** | Show long-term value (Morphology/Streak). | View projected growth graph & Word Matrix. | User lands on Home Tab. |

## **10\. Long-Tail Retention & Metacognition**

### **10.1 The "Stats" Dashboard as Onboarding**

The final step of onboarding is the **Stats** tab. It shouldn't be empty.

* **Projected Growth:** Show a "Projected Forgetting Curve" based on the user's calibration performance. "If you study 10 minutes a day, you will master 1,000 words in 3 months." This anchors the user's motivation to tangible data.4  
* **Streak Defense:** Explain the "Streak Keeper" widget logic. "Your streak isn't just a number; it's your memory shield. If it breaks, your retention drops.".1

### **10.2 The "Explore" Tab Introduction (Morphology)**

For the analytical learner, a brief tour of the **Word Matrix** is necessary.

* **Force-Directed Graph:** Show a root word (e.g., *SPECT*) exploding into *Inspect*, *Respect*, *Suspect*.  
* **The Multiplier Effect:** Explain: "Learn one root, unlock ten words. We boost the stability of related words automatically.".4

## **11\. Implementation Guidelines for Development**

### **11.1 Swift Implementation of Onboarding Coordinator**

The onboarding flow should be managed by a dedicated OnboardingCoordinator utilizing the **Factory Pattern** to generate view controllers for each phase.

* **State Management:** Use UserDefaults or SwiftData to track hasCompletedOnboarding, hasAddedWidget, and hasEnabledExtension.  
* **Deep Linking:** Ensure SceneDelegate is configured to handle the lexicalapp://onboarding/step/{id} URL scheme to allow widgets to deep-link back into specific tutorial steps if the user gets stuck.4

### **11.2 Liquid Glass View Modifiers**

Developers must use the GlassEffectContainer for all onboarding overlays to ensure performance and visual consistency.

Swift

// Example SwiftUI Modifier for Onboarding Tooltips  
struct GlassTooltip: ViewModifier {  
    func body(content: Content) \-\> some View {  
        content  
           .padding()  
           .background(.ultraThinMaterial) // Liquid Glass Base  
           .clipShape(RoundedRectangle(cornerRadius: 16))  
           .shadow(color:.black.opacity(0.1), radius: 10, x: 0, y: 10)  
           .overlay(  
                RoundedRectangle(cornerRadius: 16)  
                   .stroke(.white.opacity(0.2), lineWidth: 1) // Glass Rim  
            )  
    }  
}

This ensures that even the tutorial elements feel like a native part of the iOS 26 ecosystem.23

## **12\. Conclusion**

The onboarding architecture for Lexical is not a mere introduction; it is a strategic indoctrination into a new way of learning. By synthesizing the mathematical precision of FSRS, the ergonomic efficiency of the "Thumb Zone," and the pervasive nature of iOS 26 Widgets, Lexical can successfully migrate users from the "Intermediate Plateau" to fluency. The success of this onboarding is measured not by how many users complete the tutorial, but by how many establish the "invisible" habits of interstitial learning that the system facilitates. This is the blueprint for a "Personalized Lexical Ecosystem" that respects the user's intelligence and time.

# ---

**Detailed Analysis: Component-Specific Onboarding Strategies**

## **13\. Deep Dive: FSRS Algorithmic Education & The "Why" of Scheduling**

The transition from SM-2 (or no algorithm) to FSRS v4.5 is a significant mental shift for users. The onboarding must demystify the variables of **Retrievability (R)**, **Stability (S)**, and **Difficulty (D)** without using academic jargon.6

### **13.1 The "Memory Battery" Metaphor \- Expanded**

Instead of showing raw probability formulas (![][image1]), the system must use the "Memory Battery" visual metaphor.

* **Retrievability \= Charge Level:** Show a battery draining over time.  
* **Stability \= Battery Capacity:** Explain that every successful review "upgrades the battery," making the charge drain slower (flattening the curve).  
* **Difficulty \= Energy Drain Rate:** Harder words drain the battery faster.  
* **The "Optimum Review" Point:** Highlight that Lexical prompts a review only when the "battery" is at 10% (90% Retrievability threshold). Reviewing too early is "wasteful charging"; reviewing too late is "power failure" (forgetting).1 This specifically counters the user behavior of "over-reviewing" which leads to burnout.

### **13.2 Handling the "Hard" Button Misconception**

A common failure mode in FSRS adoption is users pressing "Hard" when they actually forgot the card (which should be "Again").

* **Correction Logic:** During the mock review in onboarding, explicitly trap this behavior. If a user hesitates for \>10 seconds and then presses "Hard," show a gentle prompt: "That took a while\! If you couldn't recall it immediately, 'Again' might be better to reset the loop. 'Hard' is for when you *do* remember, but it's fuzzy.".12 This "Just-in-Time" correction is more effective than upfront text instructions.42

## **14\. Deep Dive: Interactive Widget Ecosystem Onboarding**

The "Home Screen Offensive" is a unique feature that requires specific onboarding because users often forget widgets exist after installation.4

### **14.1 The "Widget Preview" Canvas**

Inside the app onboarding, create a "Virtual Home Screen."

* **Interaction:** Allow the user to drag and drop a virtual Lexical widget onto a mock home screen within the app.  
* **Configuration:** Let them toggle between "Micro-Dose" (Flashcards) and "Word of the Day" modes.  
* **Visualization:** Show exactly how the widget updates in real-time. For example, grading a card in the virtual widget instantly updates the "Stats" graph below it, demonstrating the "Live Sync" capability.14

### **14.2 The "Lock Screen" Nudge**

Don't forget the Lock Screen widgets. For the "Streak Keeper," guide the user to add the circular accessory widget to their Lock Screen.

* **Copy:** "Keep your streak visible at a glance. Add the Lexical Streak Ring to your Lock Screen to never miss a day.".4

## **15\. Deep Dive: Safari Extension "Importer Bridge"**

The Safari Extension is the bridge to "Contextual Incidental Learning." Since enabling it involves leaving the app, the drop-off rate is high.

### **15.1 The "Problem/Solution" Setup**

* **The Problem:** Show a screenshot of a complex article in Safari with the caption: "Too many unknown words?"  
* **The Solution:** Animate the Lexical Extension activating. The complex words turn Blue. A "Tap" action captures them.  
* **The Call to Action:** "Enable Lexical in Safari to turn the entire web into your library."

### **15.2 The "Status Check" Loop**

Use a polling mechanism to check if the extension is enabled.

* **State:** Display a "Waiting for Activation..." spinner in the onboarding flow.  
* **Action:** When the user successfully enables the extension in Settings and returns to the app, the spinner turns into a **Green Checkmark** with a haptic success pulse. This closes the feedback loop and confirms the setup was successful.31

## **16\. Technical Implementation for "Pattern Mode" (Accessibility)**

While "Liquid Glass" is beautiful, it can be an accessibility nightmare for users with visual impairments. The onboarding must offer an "Accessibility Check" early on.4

### **16.1 The "Readability" Test**

* **Screen:** Display sample text with the standard "Blue/Yellow" highlights.  
* **Question:** "Is this easy to read?"  
* **Option:** If the user selects "No" or "Make it Clearer," instantly toggle **Pattern Mode**.  
  * Blue highlights gain **Dotted Underlines**.  
  * Yellow highlights gain **Dashed Underlines**.  
  * Translucency is reduced (fallback to opaque backgrounds).  
* **Persistence:** Save this preference immediately to UserDefaults / AppStorage so it propagates to the Reader and Widgets instantly.26

## **17\. Conclusion: The "Evergreen" Onboarding**

Onboarding does not end after the first run. The "Plateaued Learner" evolves. Lexical's onboarding architecture must be **progressive**.

* **Milestone 1 (Day 1):** Focus on Capture and Review.  
* **Milestone 2 (Day 7):** Introduce "Morphology" once the user has enough vocabulary to see connections.  
* **Milestone 3 (Day 30):** Introduce "Advanced FSRS Settings" (optimizing retention rates) only after the user has generated enough review logs to make optimization meaningful.6

By treating onboarding as a continuous, intelligent conversation rather than a one-time tutorial, Lexical ensures that the user grows *with* the system, ultimately conquering the intermediate plateau. This comprehensive strategy leverages every available iOS 26 technology to reduce friction, build trust, and ensure the "Invisible Technology" remains invisible, allowing the learner to focus on what matters: the language itself.

#### **Alıntılanan çalışmalar**

1. English Vocabulary App Development Strategy  
2. Mobile Onboarding UX: 11 Best Practices for Retention (2026), erişim tarihi Şubat 14, 2026, [https://www.designstudiouiux.com/blog/mobile-app-onboarding-best-practices/](https://www.designstudiouiux.com/blog/mobile-app-onboarding-best-practices/)  
3. Mobile App Onboarding, erişim tarihi Şubat 14, 2026, [https://www.businessofapps.com/guide/app-onboarding/](https://www.businessofapps.com/guide/app-onboarding/)  
4. iOS App Design Document Creation  
5. Apple's WWDC25 Passkey Updates: Fast Forwarding The Journey, erişim tarihi Şubat 14, 2026, [https://www.authsignal.com/blog/articles/apples-wwdc25-passkey-updates-fast-forwarding-the-journey-to-passwordless](https://www.authsignal.com/blog/articles/apples-wwdc25-passkey-updates-fast-forwarding-the-journey-to-passwordless)  
6. Lexical App Master Project Plan  
7. Antigravity IDE iOS Geliştirme Kılavuzu  
8. Using Repetition to Flatten the Forgetting Curve \- Pendo, erişim tarihi Şubat 14, 2026, [https://www.pendo.io/pendo-blog/how-to-use-repetition-to-flatten-the-forgetting-curve/](https://www.pendo.io/pendo-blog/how-to-use-repetition-to-flatten-the-forgetting-curve/)  
9. How to use the next-generation spaced repetition algorithm FSRS, erişim tarihi Şubat 14, 2026, [https://www.reddit.com/r/Anki/comments/zncitr/how\_to\_use\_the\_nextgeneration\_spaced\_repetition/](https://www.reddit.com/r/Anki/comments/zncitr/how_to_use_the_nextgeneration_spaced_repetition/)  
10. Forgetting Curve \- The Decision Lab, erişim tarihi Şubat 14, 2026, [https://thedecisionlab.com/reference-guide/psychology/forgetting-curve](https://thedecisionlab.com/reference-guide/psychology/forgetting-curve)  
11. FSRS Button strategy for new cards: good or again? \- Anki Forums, erişim tarihi Şubat 14, 2026, [https://forums.ankiweb.net/t/fsrs-button-strategy-for-new-cards-good-or-again/57340](https://forums.ankiweb.net/t/fsrs-button-strategy-for-new-cards-good-or-again/57340)  
12. fsrs4anki/docs/tutorial.md at main · open-spaced-repetition ... \- GitHub, erişim tarihi Şubat 14, 2026, [https://github.com/open-spaced-repetition/fsrs4anki/blob/main/docs/tutorial.md](https://github.com/open-spaced-repetition/fsrs4anki/blob/main/docs/tutorial.md)  
13. The Role of UI/UX Design in Mobile App User Retention \- Medium, erişim tarihi Şubat 14, 2026, [https://medium.com/@kodekx-solutions/the-role-of-ui-ux-design-in-mobile-app-user-retention-2025-guide-9-proven-hacks-3a18ea4ea170](https://medium.com/@kodekx-solutions/the-role-of-ui-ux-design-in-mobile-app-user-retention-2025-guide-9-proven-hacks-3a18ea4ea170)  
14. Antigravity IDE Skills File Generation  
15. Apple Passkey Account Creation API on iOS 26 \- Corbado, erişim tarihi Şubat 14, 2026, [https://www.corbado.com/blog/passkey-account-creation-api](https://www.corbado.com/blog/passkey-account-creation-api)  
16. Passkeys Handbook 2025 | Secure, Passwordless Authentication, erişim tarihi Şubat 14, 2026, [https://mojoauth.com/white-papers/passkeys-passwordless-authentication-handbook/](https://mojoauth.com/white-papers/passkeys-passwordless-authentication-handbook/)  
17. Apple's Passkey Account Creation API in iOS 26 Explained, erişim tarihi Şubat 14, 2026, [https://dev.to/corbado/apples-passkey-account-creation-api-in-ios-26-explained-230n](https://dev.to/corbado/apples-passkey-account-creation-api-in-ios-26-explained-230n)  
18. Passkey Best Practices: Dos and Don'ts for 2025 \- Hanko, erişim tarihi Şubat 14, 2026, [https://www.hanko.io/blog/the-dos-and-donts-of-integrating-passkeys](https://www.hanko.io/blog/the-dos-and-donts-of-integrating-passkeys)  
19. WWDC 2025 \- Advanced Passkeys Implementation in iOS 26, erişim tarihi Şubat 14, 2026, [https://dev.to/arshtechpro/wwdc-2025-advanced-passkeys-implementation-in-ios-26-5bg6](https://dev.to/arshtechpro/wwdc-2025-advanced-passkeys-implementation-in-ios-26-5bg6)  
20. Best practices for accessing and handling user permissions for iOS, erişim tarihi Şubat 14, 2026, [https://blog.appmysite.com/best-practices-for-accessing-and-handling-user-permissions-part-i-for-ios-apps/](https://blog.appmysite.com/best-practices-for-accessing-and-handling-user-permissions-part-i-for-ios-apps/)  
21. Mobile Permission Requests: Timing, Strategy & Compliance Guide, erişim tarihi Şubat 14, 2026, [https://www.dogtownmedia.com/the-ask-when-and-how-to-request-mobile-app-permissions-camera-location-contacts/](https://www.dogtownmedia.com/the-ask-when-and-how-to-request-mobile-app-permissions-camera-location-contacts/)  
22. A technical explanation of the FSRS algorithm : r/Anki \- Reddit, erişim tarihi Şubat 14, 2026, [https://www.reddit.com/r/Anki/comments/18tnp22/a\_technical\_explanation\_of\_the\_fsrs\_algorithm/](https://www.reddit.com/r/Anki/comments/18tnp22/a_technical_explanation_of_the_fsrs_algorithm/)  
23. Mastering iOS 26's Liquid Glass: A Comprehensive Developer's, erişim tarihi Şubat 14, 2026, [https://medium.com/@jaikrishnavj/mastering-ios-26s-liquid-glass-a-comprehensive-developer-s-handbook-2bba9965b024](https://medium.com/@jaikrishnavj/mastering-ios-26s-liquid-glass-a-comprehensive-developer-s-handbook-2bba9965b024)  
24. Applying Liquid Glass to custom views \- Apple Developer, erişim tarihi Şubat 14, 2026, [https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)  
25. Designing custom UI with Liquid Glass on iOS 26 \- Donny Wals, erişim tarihi Şubat 14, 2026, [https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/](https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/)  
26. iOS 26: Liquid Glass UI between design and accessibility \- Let's dev, erişim tarihi Şubat 14, 2026, [https://letsdev.de/en/blog/ios-26-in-detail-liquid-glass-ui-between-usability-and-accessibility.php](https://letsdev.de/en/blog/ios-26-in-detail-liquid-glass-ui-between-usability-and-accessibility.php)  
27. How to add and edit widgets on your iPhone \- Apple Support, erişim tarihi Şubat 14, 2026, [https://support.apple.com/en-us/118610](https://support.apple.com/en-us/118610)  
28. Getting started with iOS Widgets — Part I | by Ayush Khare \- Medium, erişim tarihi Şubat 14, 2026, [https://medium.com/healint-engineering-data/getting-started-with-ios-widgets-part-i-158bb92045e6](https://medium.com/healint-engineering-data/getting-started-with-ios-widgets-part-i-158bb92045e6)  
29. The Complete Beginner's Guide to iOS Widgets: From Zero to Hero, erişim tarihi Şubat 14, 2026, [https://medium.com/@jatin.v1997/the-complete-beginners-guide-to-ios-widgets-from-zero-to-hero-part-1-79a754aa72d8](https://medium.com/@jatin.v1997/the-complete-beginners-guide-to-ios-widgets-from-zero-to-hero-part-1-79a754aa72d8)  
30. Apple, Your New Mobile Safari Extensions are Great. Can Opting-In, erişim tarihi Şubat 14, 2026, [https://www.wildfire-corp.com/blog/to-apple-your-new-mobile-safari-extensions-are-great-can-opting-in-be-made-easier](https://www.wildfire-corp.com/blog/to-apple-your-new-mobile-safari-extensions-are-great-can-opting-in-be-made-easier)  
31. A Beginner's Guide to Write Your First IOS Safari Extension \- Coditude, erişim tarihi Şubat 14, 2026, [https://www.coditude.com/insights/how-to-write-your-first-ios-safari-extension/](https://www.coditude.com/insights/how-to-write-your-first-ios-safari-extension/)  
32. All Aboard: Maximize Mobile Engagement with Interactive Onboarding, erişim tarihi Şubat 14, 2026, [https://www.codemag.com/article/1509061/All-Aboard-Maximize-Mobile-Engagement-with-Interactive-Onboarding](https://www.codemag.com/article/1509061/All-Aboard-Maximize-Mobile-Engagement-with-Interactive-Onboarding)  
33. The Ultimate Mobile App Onboarding Guide (2026) \- VWO, erişim tarihi Şubat 14, 2026, [https://vwo.com/blog/mobile-app-onboarding-guide/](https://vwo.com/blog/mobile-app-onboarding-guide/)  
34. How to build an iOS Safari Web Extension | by Raza P. \- Medium, erişim tarihi Şubat 14, 2026, [https://medium.com/@razapadhani/how-to-build-an-ios-safari-web-extension-268cddfd6d65](https://medium.com/@razapadhani/how-to-build-an-ios-safari-web-extension-268cddfd6d65)  
35. Onboarding UX Patterns | Permission Priming | UserOnboard, erişim tarihi Şubat 14, 2026, [https://www.useronboard.com/onboarding-ux-patterns/permission-priming/](https://www.useronboard.com/onboarding-ux-patterns/permission-priming/)  
36. iOS Push Notification Permissions: The Best Practices, erişim tarihi Şubat 14, 2026, [https://blog.hurree.co/ios-push-notification-permissions-best-practises](https://blog.hurree.co/ios-push-notification-permissions-best-practises)  
37. CoreMotion API and Motion Permission \- Stack Overflow, erişim tarihi Şubat 14, 2026, [https://stackoverflow.com/questions/19915892/coremotion-api-and-motion-permission](https://stackoverflow.com/questions/19915892/coremotion-api-and-motion-permission)  
38. (PDF) Towards Sustainable Personalized On-Device Human Activity, erişim tarihi Şubat 14, 2026, [https://www.researchgate.net/publication/383701922\_Towards\_Sustainable\_Personalized\_On-Device\_Human\_Activity\_Recognition\_with\_TinyML\_and\_Cloud-Enabled\_Auto\_Deployment](https://www.researchgate.net/publication/383701922_Towards_Sustainable_Personalized_On-Device_Human_Activity_Recognition_with_TinyML_and_Cloud-Enabled_Auto_Deployment)  
39. I built a small web tool based on Ebbinghaus' Forgetting Curve to, erişim tarihi Şubat 14, 2026, [https://www.reddit.com/r/ProductivityApps/comments/1po11zn/i\_built\_a\_small\_web\_tool\_based\_on\_ebbinghaus/](https://www.reddit.com/r/ProductivityApps/comments/1po11zn/i_built_a_small_web_tool_based_on_ebbinghaus/)  
40. Best UX Practices for iOS App Design Success: Part 2 \- SJ Innovation, erişim tarihi Şubat 14, 2026, [https://sjinnovation.com/best-UI-practices-for-IOS-app-design-success-2](https://sjinnovation.com/best-UI-practices-for-IOS-app-design-success-2)  
41. A Step-by-Step Guide to Implementing App Widgets on iOS (Part 1), erişim tarihi Şubat 14, 2026, [https://dev.to/fauzibinfaisal/a-step-by-step-guide-to-implementing-app-widgets-on-ios-part-1-2bcd](https://dev.to/fauzibinfaisal/a-step-by-step-guide-to-implementing-app-widgets-on-ios-part-1-2bcd)  
42. Onboarding UX \- Smart Interface Design Patterns, erişim tarihi Şubat 14, 2026, [https://smart-interface-design-patterns.com/articles/onboarding-ux/](https://smart-interface-design-patterns.com/articles/onboarding-ux/)  
43. Choosing the right user onboarding UX pattern \- Appcues, erişim tarihi Şubat 14, 2026, [https://www.appcues.com/blog/choosing-the-right-onboarding-ux-pattern](https://www.appcues.com/blog/choosing-the-right-onboarding-ux-pattern)

[image1]: <data:image/png;base64,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>