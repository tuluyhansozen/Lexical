# Explore Figma Parity Design

**Date:** 2026-02-20  
**Status:** Approved

## Objective
Refactor the Explore tab to match the provided Figma Explore page visual design as closely as possible (color, typography, blur, glass, spacing, connector tone), while preserving existing app behavior and adaptive dark mode support.

## Scope
- In scope:
  - Explore screen visual shell and geometry.
  - Liquid/glass rendering for root and leaf nodes.
  - Header typography and spacing.
  - Connector line styling.
  - Preserve existing bottom tab integration and only tune visuals if parity requires it.
- Out of scope:
  - Data model/persistence changes.
  - Changes to review logic, scheduling, or resolver selection logic.
  - New dependencies.

## Decisions
- Use dynamic daily resolver content (not static Figma demo words).
- Keep adaptive dark mode behavior for dark mode users.
- Keep existing interactions: node tap -> detail sheet, add-to-deck flow.
- Keep reduced-transparency fallback behavior.
- End with boot/build/open simulation in iOS Simulator and capture artifact.

## Architecture
- Keep `/Users/tuluyhan/projects/Lexical/Lexical/Features/Explore/ExploreView.swift` as tab entry.
- Add strict Figma reference geometry and style constants in the Explore feature.
- Rework `/Users/tuluyhan/projects/Lexical/LexicalCore/DesignSystem/LiquidGlassButton.swift` to align leaf/root glass layering and highlights with Figma.
- Keep `/Users/tuluyhan/projects/Lexical/Lexical/Features/Common/CustomTabBar.swift` structure; adjust visual metrics only if needed for parity.

## Components
- **ExploreView shell**
  - Light background tone and top status/header spacing.
  - Figma-like title/subtitle typography hierarchy and tracking.
  - Matrix anchor positions and node diameters matched to Figma reference.
- **Node buttons**
  - Root: coral/pink glass with center label stack and specular highlights.
  - Leaf: green dark glass spheres with metallic gradient overlays and subtle strokes.
- **Connectors**
  - Thin low-contrast links from root to leaves with soft blended tones.

## Data Flow
- Keep `DailyRootResolver` + current fallback topology.
- Keep current lexeme/user-state mapping for detail sheets and status ring logic.
- Visual refactor only; no behavior rewrite.

## Error Handling and Accessibility
- Retain fallback matrix rendering when resolver has no result.
- Preserve reduced-transparency fallback for blur-heavy surfaces.
- Maintain existing accessibility labels/hints.

## Validation Plan
- TDD for stable layout/style reference values through helper tests.
- Run targeted test suite for Explore-related behavior.
- Boot/build/open app in simulator and navigate to Explore tab.
- Save screenshot artifact to verify parity direction.
