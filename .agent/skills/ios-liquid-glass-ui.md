# Skill: iOS Liquid Glass UI System

## Description
This skill defines the "Liquid Glass" design language for the Lexical App, specifically tailored for iOS 17+. It focuses on semantic color usage, morphing transitions, and thumb-accessible layouts.

## 1. Core Visual Materials

### 1.1 Glass Containers
- **Component:** `GlassEffectContainer`
- **Implementation:**
  ```swift
  ZStack {
      Material.ultraThinMaterial
      Color.white.opacity(0.1) // Tint
  }
  .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
  .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
  ```

### 1.2 "Morph" Transitions
- Use `.matchedGeometryEffect` for all card transitions.
- **Front:** Context Sentence with `[ _____ ]`.
- **Back:** Context Sentence with `[ Word ]` highlighted Yellow.
- **Timing:** `.spring(response: 0.6, dampingFraction: 0.8)` for a fluid, organic feel.

## 2. Semantic Color Palette

| State | Light Mode | Dark Mode | Meaning |
| :--- | :--- | :--- | :--- |
| **New** | `#E3F2FD` (Blue 50) | `#1565C0` (Blue 800) | Potentially interactive. Tap to capture. |
| **Learning** | `#FFF9C4` (Yellow 50) | `#FBC02D` (Yellow 700) | Active memory. SRS engaged. |
| **Known** | Transparent | Transparent | Mastered. Background noise. |

## 3. Typography Rules
- **Interface:** `Font.system` (SF Pro).
- **Reader Content:** `Font.custom("New York", size: ...)` (SF Serif).
- **Flashcard Target:** `Font.system(..., design: .rounded)` (SF Rounded).
- **Dynamic Type:** ALL fonts must use `.scaledFont` wrappers. No fixed sizes.

## 4. The Thumb Zone
- **Primary Actions:** (Grade, Capture, Confirm) MUST be in the bottom 30% of the screen.
- **Bottom Sheets:** Use `.presentationDetents([.medium])`.
- **Avoid:** Top navigation bar buttons for critical study actions.

## 5. Accessibility Overrides
- **Reduce Transparency:** If enabled, replace `Material.ultraThin` with solid Opaque colors.
- **Differentiate without Color:**
  - **New:** Dotted Underline.
  - **Learning:** Dashed Underline.
