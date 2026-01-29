# Skill: CRDT Sync Orchestrator

## Description
This skill defines the Offline-First synchronization strategy using Conflict-Free Replicated Data Types (CRDTs). It ensures mathematical consistency of user data across iPhone, iPad, and Widgets without central locking.

## 1. Data Structures

### 1.1 Review Log (G-Set: Grow-Only Set)
- **Definition:** An immutable, append-only set of review events.
- **Conflict Resolution:** Union. $Set_A \cup Set_B$.
- **Logic:** We never delete a review. If Device A has 5 reviews and Device B has 3 different reviews, the merged set has 8 reviews.
- **Schema:**
  ```swift
  struct ReviewLog: Identifiable, Hashable {
      let id: UUID
      let cardID: UUID
      let grade: Int
      let timestamp: Date // Crucial for sorting
      let deviceID: String
  }
  ```

### 1.2 Vocabulary State (LWW-Element-Set)
- **Definition:** Last-Write-Wins Element Set for mutable properties (e.g., `isKnown`, `contextSentence`).
- **Conflict Resolution:** Max Timestamp Wins.
- **Logic:**
  - Device A: Sets "run" to Known at 10:00.
  - Device B: Sets "run" to New at 10:05.
  - Result: "run" is New.

## 2. The Recalculation Service
- **Philosophy:** "State is a function of History."
- **Process:**
  1. Merge Sync Logs (Union G-Sets).
  2. Fetch all logs for Card X.
  3. Sort by Timestamp.
  4. Instantiate a fresh `FSRSScheduler`.
  5. Replay logs sequentially through the scheduler.
  6. The final result is the Canonical State (S, D, R).
  7. Update the `VocabularyItem` cache.

## 3. Transport & Persistence
- **App Groups:** Use `FileManager.containerURL(forSecurityApplicationGroupIdentifier: ...)` to share the SQLite/SwiftData store between App and Widget.
- **CloudKit:** Use `CKRecord` to transport binary blobs of ReviewLogs (or individual records if volume permits).
