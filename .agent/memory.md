# Lexical Project Memory

## Architectural Decisions
- **Agent-First Architecture**: Shift from manual coding to orchestration within Antigravity IDE.
- **Offline-First**: Use SwiftData and CRDTs for data consistency across devices.
- **FSRS v4.5**: Core retention algorithm used for spaced repetition.
- **Liquid Glass UI**: Modern, glassmorphic design system for iOS.

## Core Components
- **FSRS Engine**: Spaced repetition scheduling.
- **Immersive Reader**: TextKit 2 based reading experience with "Tap-to-Capture".
- **CRDT Sync**: Decentralized synchronization logic.
- **NLP Pipeline**: `TokenizationActor` + `LemmaResolver` for lemmatization.
- **Review Engine**: `SessionManager` + `FlashcardView` with Brain Boost re-queueing.

## SwiftData Models
- `VocabularyItem`: Core model with FSRS fields (stability, difficulty, retrievability)
- `ReviewLog`: Immutable append-only for CRDT sync
- `MorphologicalRoot`: Etymology tracking

## Environment Notes
- **MCP Servers**: `ios-simulator` and `filesystem` for agentic interactions.
- **uv Integration**: Python script execution via uv for zero-setup utility tasks.
- **Simulator**: iPhone 16e (98FACCED-3F83-4A94-8D7B-F8905AAF08D1)

## Progress
- ✅ Phase 1: Foundation & Environment Setup
- ✅ Phase 2: Architecture & Core Logic
- ✅ Phase 3: Core UI Implementation
- ✅ Phase 4: The Acquisition Engine (Immersive Reader)
- ✅ Phase 5: The Retention Engine (FSRS Review Loop)
- 🔲 Phase 6: Home Screen Offensive (Widgets & Intents)
- 🔲 Phase 7: Intelligent Engagement & Integration
