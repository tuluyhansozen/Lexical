# Lexical Project Memory

## Architectural Decisions
- **Agent-First Architecture**: Shift from manual coding to orchestration within Antigravity IDE.
- **Offline-First**: Use SwiftData and CRDTs for data consistency across devices.
- **FSRS v4.5**: Core retention algorithm used for spaced repetition.
- **Liquid Glass UI**: Modern, glassmorphic design system for iOS.
- **Pre-seeded Vocabulary**: Seed pipeline in place; starter seed included (expand to 500–1000 words).

## Core Components
- **FSRS Engine**: Spaced repetition scheduling.
- **Immersive Reader**: TextKit 2 based reading experience with "Tap-to-Capture".
- **CRDT Sync**: Decentralized synchronization logic.
- **NLP Pipeline**: `TokenizationActor` + `LemmaResolver` for lemmatization.
- **Review Engine**: `SessionManager` + `FlashcardView` with Brain Boost re-queueing.
- **Bandit Scheduler**: Epsilon-Greedy MAB for notification timing optimization.
- **Collocation Matrix**: Force-directed graph visualization of semantic connections.
- **Vocabulary Seeding**: `VocabularySeedService` + `vocab_seed.json` first-launch seeding.
- **Debug Verification**: Seed count overlay (DEBUG) + `--lexical-debug-autocycle` tab cycling for simulator checks.

## SwiftData Models
- `VocabularyItem`: Core model with FSRS fields and `collocations` (Many-to-Many self-reference)
- `ReviewLog`: Immutable append-only for CRDT sync

## Current Placeholder Status
- **Explore Tab (Tab 1)**: ✅ `ExploreView.swift` (Matrix + Search)
- **Stats Tab (Tab 3)**: Mock data (hardcoded) - needs real SwiftData queries
- **Profile (Tab 4)**: ✅ `SettingsView.swift`

## Completion Phases (8-10)
- **Phase 8**: Vocabulary Seeding & Personalized Articles
  - ✅ VocabularySeedService for first-launch seeding
  - 🟡 Article Personalization (ArticleGenerator, InterestProfile)
- **Phase 9**: Authentication & Cloud Sync (Sign in with Apple, CloudKit)
- **Phase 10**: Production Polish & App Store (Onboarding, Privacy Manifests)

## Environment Notes
- **MCP Servers**: `ios-simulator`, `filesystem`, `context7` for agentic interactions.
- **uv Integration**: Python script execution via uv for zero-setup utility tasks.
- **Simulator**: iPhone 16e (98FACCED-3F83-4A94-8D7B-F8905AAF08D1)

## Progress
- ✅ Phase 1: Foundation & Environment Setup
- ✅ Phase 2: Architecture & Core Logic
- ✅ Phase 3: Core UI Implementation
- ✅ Phase 4: The Acquisition Engine (Immersive Reader)
- ✅ Phase 5: The Retention Engine (FSRS Review Loop)
- ✅ Phase 6: Home Screen Offensive (Widgets & Intents)
- ✅ Phase 7: Intelligent Engagement & Integration
- 🟡 Phase 8: Vocabulary Seeding & Personalized Articles (Seeding ✅, Articles 🟡)
- 🔲 Phase 9: Authentication & Cloud Sync
- 🔲 Phase 10: Production Polish & App Store Release
