# Lexical App: Project Implementation Plan

> **Generated:** 2026-01-31
> **Last Updated:** 2026-01-31
> **Status:** Milestones 1-4 Completed | Milestones 5-7 Pending

---

## Overview

This document outlines the complete implementation roadmap for the Lexical App, an agent-first vocabulary acquisition system. Each phase is divided into three sections for clear implementation guidance.

---

# ✅ COMPLETED PHASES

---

## Phase 1: Foundation & Environment Setup

**Status:** ✅ Complete

### Section 1: Objective
Construct the "Digital Shipyard" by initializing the Antigravity IDE, configuring agent personas, and establishing hardware control via MCP.

### Section 2: Key Activities
- Initialize `.agent` directory structure with `rules/`, `skills/`, `memory.md`
- Configure `uv` package manager for PEP 723 inline scripts
- Set up MCP (`ios-simulator-mcp`) for simulator control
- Create agent personas: Architect, Senior Engineer, QA Engineer

### Section 3: Deliverables
- [x] `.agent/` configuration package
- [x] 19 Skill files (FSRS, Liquid Glass, CRDT, etc.)
- [x] `mcp_config.json` with iOS Simulator integration
- [x] `verification_report.md` artifact

---

## Phase 2: Architecture & Core Logic

**Status:** ✅ Complete

### Section 1: Objective
Implement the offline-first data layer (SwiftData), FSRS 4.5 algorithm, and CRDT synchronization engine.

### Section 2: Key Activities
- Design SwiftData schema: `VocabularyItem`, `ReviewLog`, `MorphologicalRoot`
- Implement `FSRSV4Engine` (Swift Actor) with stability/difficulty calculations
- Build CRDT foundation: G-Set for logs, LWW-Set for state
- Create `BanditScheduler` stub for future engagement optimization

### Section 3: Deliverables
- [x] `Lexical/Models/` - SwiftData entities
- [x] `Lexical/Services/FSRSV4Engine.swift`
- [x] `Lexical/Sync/CRDTLog.swift`
- [x] Unit tests for FSRS math and SwiftData persistence

---

## Phase 3: Core UI Implementation

**Status:** ✅ Complete

### Section 1: Objective
Build the "Liquid Glass" design system and primary navigation structure.

### Section 2: Key Activities
- Create `LexicalTheme` with Midnight/Cloud color palette
- Implement `GlassEffectContainer` using `UIVisualEffectView`
- Build `LiquidBackground` with animated gradients
- Develop `AppTabNavigation` with Home, Library, Profile tabs

### Section 3: Deliverables
- [x] `Lexical/UI/DesignSystem/` - Theme, Glass, Background
- [x] `Lexical/UI/Navigation/AppTabNavigation.swift`
- [x] `Lexical/UI/Screens/Home/HomeDashboardView.swift`
- [x] `Lexical/UI/Screens/Library/LibraryListView.swift`

---

## Phase 4: The Acquisition Engine (Immersive Reader)

**Status:** ✅ Complete

### Section 1: Objective
Build the "Input" interface using TextKit 2 to facilitate contextual vocabulary acquisition with "Blue/Yellow/Known" state visualization.

### Section 2: Key Activities
- **TextKit 2 Integration:** Implemented `ReaderTextView` UIViewRepresentable with vocabulary highlighting
- **NLP Pipeline:** Created `TokenizationActor` for background lemmatization using `NaturalLanguage` framework
- **Tap-to-Capture:** Built capture sheet with sentence boundary extraction
- **SwiftData Models:** Created `VocabularyItem`, `ReviewLog`, `MorphologicalRoot`

### Section 3: Deliverables
- [x] `ReaderView.swift` - Full reader with highlighting integration
- [x] `ReaderTextView.swift` - UIKit text view with vocabulary coloring
- [x] `TokenizationActor.swift` - Background NLP processing
- [x] `LemmaResolver.swift` - SwiftData batch lookups with caching
- [x] `VocabularyItem.swift`, `ReviewLog.swift`, `MorphologicalRoot.swift`

---

# 🔲 PENDING PHASES

## Phase 5: The Retention Engine (FSRS Review Loop)

**Status:** 🔲 Not Started

### Section 1: Objective
Build the "Output" interface enforcing "Recall Dominance" with FSRS-driven study sessions and Brain Boost integration.

### Section 2: Key Activities
- **Flashcard UI:** Create `FlashcardView` with Cloze display, hidden answers, and Liquid Glass morphing transitions
- **Grading System:** Implement 4-button FSRS grading (Again/Hard/Good/Easy) with interval feedback toasts
- **Brain Boost:** Build intra-session repetition queue for failed cards with visual cues

### Section 3: Deliverables
- [ ] `FlashcardView` with `matchedGeometryEffect` transitions
- [ ] `SessionManager` for FSRS-driven card scheduling
- [ ] `BrainBoostQueue` for failed card re-injection
- [ ] `TTSManager` and `VideoAnchorPlayer` for multimedia

---

## Phase 6: Home Screen Offensive (Widgets & Intents)

**Status:** 🔲 Not Started

### Section 1: Objective
Enable "Micro-Dose" learning via iOS Interactive Widgets and App Intents for frictionless study.

### Section 2: Key Activities
- **Shared Persistence:** Migrate SwiftData container to App Group for widget access
- **Widget Development:** Build `MicroDoseWidget` (Cloze card) and `WOTDWidget` (Word of the Day)
- **App Intents:** Implement `GradeCardIntent` and `PlayAudioIntent` for background operations

### Section 3: Deliverables
- [ ] Widget Extension target with 2 widget types
- [ ] `GradeIntent`, `CaptureIntent`, `AudioIntent`
- [ ] App Group entitlement configuration
- [ ] Timeline refresh logic for instant updates

---

## Phase 7: Intelligent Engagement & Integration

**Status:** 🔲 Not Started

### Section 1: Objective
Implement adaptive notifications via Bandit Algorithms, Morphology Matrix visualization, and final system integration.

### Section 2: Key Activities
- **Bandit Scheduler:** Implement Epsilon-Greedy MAB for notification optimization with interruptibility modeling
- **Morphology Matrix:** Build force-directed graph visualizing etymological word relationships
- **Final Integration:** Merge all modules, run agentic QA automation, prepare for App Store release

### Section 3: Deliverables
- [ ] `BanditScheduler` with notification templates
- [ ] `WordMatrixView` with physics-based graph
- [ ] End-to-end QA walkthrough artifacts
- [ ] Production-ready `.ipa` and Privacy Manifests

---

## Implementation Priority

| Phase | Priority | Estimated Effort | Dependencies |
|-------|----------|------------------|--------------|
| Phase 5 | 🔴 High | 2 weeks | Phase 2, 4 |
| Phase 6 | 🟡 Medium | 1 week | Phase 5 |
| Phase 7 | 🟡 Medium | 2 weeks | Phase 4, 5, 6 |

---

## Next Steps

1. Begin **Phase 5** with FlashcardView and FSRS session integration
2. Implement SessionManager for review scheduling
3. Build Brain Boost queue for failed card re-injection
