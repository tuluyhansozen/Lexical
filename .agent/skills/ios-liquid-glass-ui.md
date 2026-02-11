---
name: ios-liquid-glass-ui
description: Use when implementing UI features using the iOS 26+ Liquid Glass API, GlassEffectContainer, or fluid morphing design patterns.
version: 1.0
tags: [swiftui, ios26, design-system, accessibility, morphing]
author: Antigravity Architecture Team
---

# Liquid Glass UI & Design System Skill

## Strategic Usage

**Use this skill when:**

- Implementing navigation layers (Tab Bars, Toolbars, Sidebars) using the iOS 26 design language.
- Grouping multiple translucent elements that must physically blend or morph.
- Designing "Floating Action Buttons" (FABs) that expand into menus with fluid transitions.
- Implementing accessibility fallbacks for transparency-sensitive users.

**Do not use this skill when:**

- Writing low-level Metal Shading Language (MSL) code (use `metal-refraction-physics` instead).
- Optimizing the render loop for 120fps (use `swiftui-metal-pipeline` instead).
- Applying effects to the content layer (lists, cards, images); glass is strictly for the *control* layer.

## Core Design Principles (iOS 26)

1. **Lensing over Blurring:** Liquid Glass bends light; it does not just scatter it. Background content should remain discernible but distorted, creating optical depth.
2. **Fluidity & Tension:** Elements are not rigid. They possess surface tension. When close, they should merge; when separating, they should exhibit elasticity.
3. **Hierarchy:** Glass floats *above* content. Never stack glass on glass, as this creates muddy visuals and breaks the refractive illusion.

## Technical Instructions

### 1. Container Architecture & Surface Tension

The `GlassEffectContainer` is the fundamental unit of the Liquid Glass system. It creates a shared sampling buffer for all child elements, enabling mathematically correct blending.

- **Rule:** Always wrap groups of glass elements in a `GlassEffectContainer`.
- **Surface Tension (`spacing`):** Use the `spacing` parameter to define the morphing threshold (`k`).
  - `spacing: 0` → Sharp edges, no merging.
  - `spacing: 20` → Standard system behavior; elements "kiss" and merge when adjacent.
  - `spacing: >40` → High viscosity; elements stretch to connect over long distances.

```swift
// Correct Usage: Grouping distinct controls into a unified glass manifold
GlassEffectContainer(spacing: 20.0) {
    HStack {
        Button(action: { /*...*/ }) {
            Image(systemName: "mic.fill")
               .glassEffect(.regular.interactive())
        }
        // These buttons will fluidly merge if they move within 20pt of each other
        Button(action: { /*...*/ }) {
            Image(systemName: "phone.fill")
               .glassEffect(.regular.interactive())
        }
    }
}
```

### 2. Material Variants & Interactivity

- **The `.glassEffect` Modifier:** Apply this to define the material properties.
- **Ordering:** Apply `.glassEffect()` *after* frame/shape definitions but *before* layout padding if the padding defines the "touch target" rather than the visual bounds.
- **Interactivity:** Always append `.interactive()` for tappable elements. This enables the system-standard "specular bounce" and "shimmer" animation on touch down.
  - `.regular`: The default. Adapts to light/dark mode automatically.
  - `.clear`: High transparency. Use **only** for overlays on media-rich content (photos/maps) where obscuring pixels is detrimental.
  - `.prominent`: Thicker, higher refractive index. Use for modal backgrounds.

### 3. Morphing and Identity

To enable fluid state transitions (e.g., a button expanding into a panel), utilize `glassEffectID` coupled with a SwiftUI `Namespace`.

- **Mechanism:** SwiftUI uses the ID to track the "material identity" across the render graph. The `GlassEffectContainer` interpolates the SDF (Signed Distance Field) of the shapes between states.
- **Implementation Pattern:**

```swift
@Namespace var glassNamespace

// Within a GlassEffectContainer
if isExpanded {
    MenuContent()
       .glassEffect(.regular)
       .glassEffectID("sharedID", in: glassNamespace)
       .transition(.scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity))
} else {
    FabButton()
       .glassEffect(.regular.interactive())
       .glassEffectID("sharedID", in: glassNamespace)
}
```

### 4. Accessibility Mandates

Liquid Glass inherently reduces contrast. You must implement robust fallbacks.

- **Environment Check:** Monitor `@Environment(\.accessibilityReduceTransparency)`.
- **Fallback Strategy:** If `true`, the agent must generate code that swaps `.glassEffect()` for a solid, high-contrast material.
- **Legibility:** When using `.tint()`, ensure opacity is between **0.7–0.9**. Full opacity (1.0) defeats the refractive purpose; too low (<0.5) compromises text legibility.

## Common Pitfalls

- **Nesting:** Never nest a `GlassEffectContainer` inside another. This causes undefined sampling behavior and performance degradation.
- **Content Layer:** Do not apply glass effects to scrolling content cells (e.g., inside a `List`). It creates excessive overdraw. Glass belongs in the overlay or `safeAreaInset` of the view hierarchy.
