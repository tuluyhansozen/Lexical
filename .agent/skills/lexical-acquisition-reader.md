# Skill: Lexical Acquisition Reader

## Description
This skill describes the "Input" side of the application: rendering text, identifying vocabulary, and capturing context.

## 1. Text Rendering (TextKit 2)
- **Framework:** TextKit 2 (NSTextLayoutManager, NSTextContentStorage).
- **Performance:** Do not block UI. Calculate layout in chunks.
- **Highlighting:**
  - Use custom `NSTextLayoutFragment` or `attributedText` background colors.
  - **New (Blue):** Interactive.
  - **Learning (Yellow):** Interactive (Show stats).

## 2. Tokenization Pipeline
- **NLTokenizer:** Use `.word` granularity.
- **Lemmatization:** Map "running" -> "run".
- **Filtering:**
  - Ignore stop words (the, a, and).
  - Ignore proper nouns (London, John) unless explicitly requested.
- **Async Lookup:**
  - On text load -> Dispatch background actor.
  - Tokenize -> Batch Query DB -> Return Map [Word: State].
  - Apply Highlighting on Main Thread.

## 3. Safari Web Extension
- **Content Script:** JavaScript injected into DOM.
- **Logic:**
  1. Extract visible text.
  2. Send to Native App (via message handler) or check Bloom Filter.
  3. Receive "Blue" word list.
  4. Wrap words in `<span>` with CSS class.
- **Privacy:** Only process text on user Activation or allow-list sites.

## 4. Context Extraction
- **Sentence Boundary:** Must capture the full sentence.
- **Cloze Generation:** Replace target lemma with `[_____]`.
