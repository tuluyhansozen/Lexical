# Word DB Quality Audit Report

Date: 2026-02-16  
Scope: `Lexical/Resources/Seeds/seed_data.json` (5,022 lexeme rows)

## Method
I ran a heuristic audit over:
- lemma text quality
- synonym quality and relevance signals
- sentence safety and cloze integrity (`cloze_index` vs tokenized sentence)

Checks included:
- offensive/high-risk language patterns (profanity, sexual violence, self-harm, extremism)
- placeholder/markup garbage (`<...>`, bracket artifacts, symbolic noise)
- suspicious synonyms (too short, abbreviation-like, long explanatory phrases, likely unrelated)
- cloze consistency and index bounds

Note: “unrelated” is reported as candidate-level (heuristic), not perfect semantic truth.

## Executive Summary
- `seed_data.json` contains meaningful quality debt in synonyms and sentence alignment.
- Existing validator `scripts/db/validate_seed_safety.py` currently **passes**, but misses several unsafe/profane patterns found in this audit.

### High-priority findings
1. Safety-sensitive content still exists in production seed data.
2. Synonym field includes malformed and non-synonym metadata fragments.
3. Cloze alignment errors are common and will degrade review UX quality.

## Findings

### 1) Offensive / High-risk content

#### Lemmas flagged (3)
- `id=1143` lemma=`rape`
- `id=3036` lemma=`suicide`
- `id=3089` lemma=`terrorist`

#### Synonyms flagged (4 entries)
- `id=1617` lemma=`straight` synonym=`basic bitch`
- `id=1882` lemma=`ride` synonym=`fuck`
- `id=3425` lemma=`ton` synonym=`shitton`
- `id=5836` lemma=`mendacious` synonym=`bastard`

#### Sentences flagged (29 entries across 23 lemmas)
Category distribution:
- extremism: 10
- self_harm: 8
- profanity: 8
- sexual_violence: 3

Examples:
- `id=1724` lemma=`finish`: `Fucked my cousin in her asshole ...`
- `id=1335` lemma=`stone`: `... stone fuck–up ...`
- `id=3036` lemma=`suicide`: repeated suicide-context examples
- `id=3089` lemma=`terrorist`: repeated terrorism-context examples

### 2) Synonym quality: unrelated / meaningless candidates

#### Counts
- `syn_unrelated_candidate`: 633 entries (526 lemmas)
- `syn_pos_mismatch_candidate`: 774 entries (666 lemmas)
- `syn_symbolic_or_markup`: 26 entries (25 lemmas)
- `syn_too_short`: 45 entries (40 lemmas)
- `syn_long_phrase_non_synonym`: 12 entries (10 lemmas)

#### Clear malformed examples
- `id=170` lemma=`management`: `mgmt.`
- `id=818` lemma=`silver`: `E174`, `☽`, `☾`
- `id=2981` lemma=`oxygen`: `E948[packaging gas]]>`
- `id=1662` lemma=`billion`: `trillion[short scale]]>`
- `id=1257` lemma=`employee`: `;`
- `id=2591` lemma=`yard`: `$100`

#### Long explanatory phrases in synonym field (should be definition/usage, not synonym)
- `id=1331` lemma=`palm`: `formalized in England as 4 inches and now chiefly used for the height of horses`
- `id=4122` lemma=`accompany`: `follow. The word conveys an idea of subordination.`
- `id=3475` lemma=`sink`: `washbasin for washing fixtures without water supply`

#### Likely unrelated examples
- `id=169` lemma=`way` synonym=`web`
- `id=247` lemma=`power` synonym=`arm`
- `id=254` lemma=`total` synonym=`make`
- `id=321` lemma=`private` synonym=`bits`
- `id=453` lemma=`experience` synonym=`have`

### 3) Sentence quality issues

#### Cloze integrity
- `sentence_invalid_cloze`: 91 entries (88 lemmas)
- `sentence_cloze_mismatch`: 692 entries (606 lemmas)

Examples (invalid index):
- `id=227` lemma=`file` cloze `11` but token count `11`
- `id=296` lemma=`profile` cloze `11` but token count `11`
- `id=976` lemma=`worldwide` cloze `11` but token count `11`

Examples (mismatch):
- `id=174` lemma=`united` cloze token=`kingdom`
- `id=183` lemma=`development` cloze token=`the`
- `id=289` lemma=`government` cloze token=`ranking`

#### Placeholder / markup leakage
- `sentence_placeholder`: 2 entries
- `id=1819` lemma=`subscription`: `When you buy a <xxx> television ...`
- `id=2330` lemma=`bold`: `In HTML, wrapping text in <b> and </b> ...`

#### Boilerplate template reuse
Template-like sentence patterns are present (low pedagogical quality), e.g.:
- `In class today, we practiced the word X in a clear context.`
- `Students wrote one sentence with X to improve recall and accuracy.`

Detected counts:
- class practice template: 15
- student recall template: 5

### 4) Lemma quality issues
- `lemma_shape_suspicious`: 1
- `id=5429` lemma=`modus_operandi` (underscore style inconsistent with the rest of corpus)

## Top risky entries (combined issue score)
1. `id=1143` `rape`
2. `id=3036` `suicide`
3. `id=3089` `terrorist`
4. `id=4122` `accompany`
5. `id=818` `silver`
6. `id=1331` `palm`
7. `id=3425` `ton`
8. `id=1882` `ride`
9. `id=2981` `oxygen`
10. `id=5429` `modus_operandi`

## Recommended remediation order
1. **Safety block (immediate):** remove/replace unsafe lemmas, profane synonyms, and high-risk sentence content.
2. **Synonym cleanup pass:** strip markup/symbolic values and long non-synonym phrases; keep only clean lexical synonyms.
3. **Cloze repair pass:** fix out-of-range indices and token mismatches.
4. **Template de-dup pass:** replace boilerplate with natural, lemma-specific examples.
5. **Validation hardening:** extend `scripts/db/validate_seed_safety.py` to include profanity/extremism/self-harm patterns and synonym-level checks.

## Important gap
Current safety script output:
- `python3 scripts/db/validate_seed_safety.py --seed-path Lexical/Resources/Seeds/seed_data.json`
- Result: `Seed safety validation passed.`

This indicates the current safety list is too narrow for the present corpus quality bar.
