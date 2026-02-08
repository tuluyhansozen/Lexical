# Lexical Database Guide

## Goal
Define a SwiftData architecture for Lexical that is offline-first, CRDT-safe, and aligned with:
- `docs/App Requirements Merged With iOS Strategy.md`
- `docs/SwiftData Vocabulary App Database Design.md`

## Core Decision
Use a **dual-store topology** with strict separation of concerns.

1. Static Corpus Store: canonical linguistic truth (read-mostly, app-shipped data).
2. User Progress Store: mutable cognitive state and events (write-heavy, sync-enabled).

Do not mix dictionary truth and user memory state in the same entity.

## Why This Is Required
Current state in code (`VocabularyItem`) combines:
- canonical fields (`lemma`, `definition`, context)
- user memory fields (`stability`, `difficulty`, `nextReviewDate`, etc.)

That coupling creates avoidable problems for sync, migrations, and seed updates. It also conflicts with the merged strategic docs, which require scalable rank-aware calibration, CRDT replay, and efficient on-device reader lookups.

## Store Topology

### Store A: Static Corpus (Immutable Truth)
Purpose:
- high-frequency read path for reader token lookup
- lexical rank and CEFR metadata
- morphology and collocation graph source

Persistence characteristics:
- local SQLite store bundled or OTA-updated
- excluded from cloud sync
- indexed for lookup speed

Suggested entities:
- `LexemeDefinition`
- `MorphologicalRoot`
- `LexemeRootLink`
- `LexemeRelation`
- `SeedMetadata`

Recommended `LexemeDefinition` fields:
- `lemmaId` (stable ID from seed, unique)
- `lemma` (indexed)
- `rank` (indexed)
- `cefrLevel`
- `partOfSpeech`
- `ipa`
- `basicMeaning`
- `audioFilename` (optional)
- `rootId` (indexed optional)

### Store B: User Progress (Cognitive Shadow)
Purpose:
- FSRS memory state and scheduling
- immutable review history for replay/sync
- adaptive profile, interests, ignored words, and generated content metadata

Persistence characteristics:
- read/write SQLite in app group container
- cloud sync candidate (private scope)
- CRDT merge semantics

Suggested entities:
- `UserWordState`
- `ReviewEvent`
- `UserProfile`
- `GeneratedContent`
- `WidgetInteractionInbox` (optional safety buffer)

## Required User-Centric Models

### `UserProfile`
Required by merged strategy docs:
- `userId` (Sign in with Apple identity key)
- `lexicalRank` (estimated vocab size)
- `interestVector` (topic -> weight)
- `ignoredWords` (or equivalent blacklist set)
- `easyRatingVelocity` (rolling easy ratio)
- `cycleCount` (daily matrix progression)
- `stateUpdatedAt` (LWW merge support)

### `UserWordState`
- `userId`
- `lemmaId`
- `status` (`new`, `learning`, `known`, `ignored`)
- `stability`
- `difficulty`
- `retrievability`
- `nextReviewDate`
- `lastReviewDate`
- `reviewCount`
- `lapseCount`
- `stateUpdatedAt` (LWW merge support)

### `ReviewEvent` (Append-Only)
Keep immutable, event-sourced, and replayable:
- `eventId` (UUID, unique)
- `userId`
- `lemmaId`
- `grade` (Again/Hard/Good/Easy)
- `reviewDate`
- `durationMs`
- `scheduledDays`
- `reviewState` (explicit state for optimizer/replay)
- `deviceId`

### `GeneratedContent`
Use ephemeral-first lifecycle:
- `articleId`
- `title`
- `bodyText`
- `targetRank`
- `targetLemmaIds`
- `isSaved`
- `createdAt`

Sync policy:
- unsaved generated articles remain local cache
- only `isSaved == true` articles are sync candidates

## Calibration + Warm Start Requirements
Merged docs require calibration beyond coarse CEFR.

Implementation rule:
1. Run adaptive lexical calibration (CAT/IRT style) to estimate `lexicalRank`.
2. Warm start `UserWordState` using rank bands.
3. For words below known threshold, create synthetic `ReviewEvent` records (high-confidence known state).
4. Avoid direct scalar hacks only; preserve history so FSRS replay remains valid.

## CRDT Merge Strategy

### G-Set for `ReviewEvent`
- immutable events
- sync merge = union by `eventId`
- no updates/deletes in normal operation

### LWW for mutable state
- `UserWordState.status`, `UserProfile` mutable fields use `stateUpdatedAt`
- latest timestamp wins for conflict resolution

### Deterministic FSRS Replay
After ingesting remote review events:
1. Group events by `lemmaId`.
2. Sort chronologically.
3. Replay FSRS from baseline.
4. Write resulting `stability/difficulty/retrievability/nextReviewDate` into `UserWordState`.

Do not merge FSRS scalars directly without replay.

## Brain Boost Persistence Rule
Brain Boost queue is session-transient, not long-term progress.

Rule:
- keep short-term queue in memory
- optional fallback to local JSON session snapshot (e.g., `ActiveSession.json`)
- only commit durable results to `ReviewEvent` + `UserWordState` on card graduation

## Reader and Matrix Performance Rules

### Reader
- build in-memory lookup structures at launch for status/rank filters
- avoid per-token disk fetch during render
- lazy-load heavy details on tap

### Daily Matrix
- daily root should be deterministic and offline-safe (`epochDay % rootCount`)
- enforce fixed 1 root + 6 satellites visual contract
- satellites chosen by lexical-rank relevance

## Notification Triage Data Contract
Notification actions require persisted user feedback:
- `Reveal`: local UI event
- `Add to Deck`: create/activate `UserWordState`, seed first review state
- `Ignore`: persist to `ignoredWords`/blacklist set and reduce recommendation weight

This feedback must influence future candidate selection.

## Indexing Checklist

Static Corpus indexes:
- `LexemeDefinition.lemma` unique/indexed
- `LexemeDefinition.rank` indexed
- `LexemeDefinition.rootId` indexed
- `LexemeRootLink(rootId, lemmaId)`

User Progress indexes:
- `UserWordState(userId, nextReviewDate)`
- `UserWordState(userId, status)`
- `ReviewEvent(userId, reviewDate)`
- `ReviewEvent(userId, lemmaId, reviewDate)`
- `GeneratedContent(createdAt)`

## Migration Plan From Current Models
1. Introduce new entities in parallel with existing models.
2. Backfill canonical and user stores from current `VocabularyItem` + `ReviewLog`.
3. Stop destructive seeding of user data.
4. Move feature reads/writes in slices:
- review queue
- stats
- reader lookup
- generated content
- notifications/widgets
5. Enable cloud sync only after replay-based merge tests pass.

## Immediate Actions
1. Replace current seeder reset path with canonical-only upsert.
2. Add `UserProfile` with lexical-rank and ignored-word fields.
3. Add `ReviewEvent.reviewState` and `scheduledDays` fields for replay quality.
4. Prepare `VersionedSchema` and explicit migration plan before cloud rollout.

## Implementation Snapshot (2026-02-08)
- Implemented:
  - `LexemeDefinition` canonical entity and schema registration.
  - `UserProfile` adaptive fields (`lexicalRank`, `interestVector`, `ignoredWords`, `easyRatingVelocity`, `cycleCount`).
  - `UserWordState` model scaffold with per-user unique key and FSRS shadow fields.
  - `ReviewEvent` append-only event model (`scheduledDays`, `reviewState`, `deviceId`, `sourceReviewLogId`).
  - `VocabularySeeder` moved to non-destructive canonical upsert.
  - Runtime review/session, stats, reader capture, explore, intents, widgets, and reset paths now use `LexemeDefinition` + `UserWordState` + `ReviewEvent`.
  - `VersionedSchema` migration expanded to `V1 -> V2 -> V3`; active persistence now targets `LexicalSchemaV3` (legacy tables removed from runtime schema).
  - Legacy `VocabularyItem`/`ReviewLog` usage remains only inside migration compatibility/backfill logic.
  - Added sync verification suite `LexicalCoreTests/SyncConflictResolverTests.swift` and fixed resolver merge/replay behavior to satisfy determinism, idempotency, and convergence checks.
- Remaining:
  - begin Phase 10 adaptive acquisition loop (`RankPromotionEngine`, rank-bounded content/notification feedback).

## References
- `docs/App Requirements Merged With iOS Strategy.md`
- `docs/SwiftData Vocabulary App Database Design.md`
- Apple WWDC23: Meet SwiftData
  - https://developer.apple.com/videos/play/wwdc2023/10187/
- Apple WWDC23: Model your schema with SwiftData
  - https://developer.apple.com/videos/play/wwdc2023/10195/
- Apple WWDC24: What’s new in SwiftData
  - https://developer.apple.com/videos/play/wwdc2024/10137/
- Apple SwiftData relationships docs
  - https://developer.apple.com/documentation/swiftdata/defining-data-relationships-with-enumerations-and-model-classes
- FSRS optimizer schema references
  - https://github.com/open-spaced-repetition/fsrs-optimizer
