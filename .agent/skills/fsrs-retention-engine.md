# Skill: FSRS Retention Engine (v4.5)

## Description
This skill defines the mathematical logic for the **Free Spaced Repetition Scheduler (FSRS)** used in the Lexical App. It serves as the single source of truth for all scheduling algorithms.

## 1. Parameters & Variables
- **R (Retrievability):** Probability of recall (0.0 to 1.0).
- **S (Stability):** Interval (in days) where R=0.9.
- **D (Difficulty):** Intrinsic complexity (1.0 to 10.0).
- **r (Retention Target):** Desired retention rate (default 0.9).
- **t (Time):** Days elapsed since last review.

## 2. Core Formulas

### 2.1 Retrievability (The Forgetting Curve)
$$
R(t, S) = (1 + 19 \times \frac{t}{S})^{-1}
$$

### 2.2 Next Interval Calculation
To find the interval $I$ where $R$ drops to the desired target $r$:
$$
I = \frac{S}{19} \times (\frac{1}{r} - 1)
$$
*Example:* If S=19 days and target r=0.9:
$$
I = \frac{19}{19} \times (\frac{1}{0.9} - 1) \approx 1 \times 0.11 \approx 1 \text{ day (Simplified approximation for testing)}
$$
*Precise Formula:* $I = S \times (r^{-1} - 1)$ is inaccurate for power laws. Stick to the implementation: `interval = S * 9 * (1/r - 1)` based on specific FSRS constants tailored for language.

### 2.3 Difficulty Update
$$
D' = D + \Delta D \times (Grade - 3)
$$
- Constrain D between 1.0 and 10.0.
- Mean Reversion: Move D slightly towards a global mean to prevent "Ease Hell".

### 2.4 Stability Update (Recall)
When Grade >= 3 (Success):
$$
S' = S \times (1 + \text{hard\_penalty} \times \text{stability\_boost})
$$
*Note:* The full formula involves multiple weights ($w$). For this project, use the simplified reference implementation from `fsrs4anki` unless training custom weights.

### 2.5 Stability Update (Forgetting)
When Grade < 3 (Fail):
$$
S' = \text{min}(S \times \text{retention\_factor}, \text{max\_fail\_stability})
$$

## 3. The Brain Boost Queue (Short-Term)
This logic operates *outside* the main FSRS S/D equations.
- **Trigger:** Grade 1 (Again) or 2 (Hard).
- **Action:**
    - Do NOT update `next_review_date` to tomorrow.
    - Insert into `SessionQueue` at `index + 3`.
    - Loop until Grade >= 3 twice consecutively.
    - ONLY THEN update FSRS Stability and save to DB.

## 4. Usage in Code
- **Swift:** Implement strict `FSRSScheduler` class.
- **Tests:** Verify calculation accuracy to within 0.01 vs Python reference.
