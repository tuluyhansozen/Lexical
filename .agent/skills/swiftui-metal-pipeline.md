---
name: swiftui-metal-pipeline
description: Use when optimizing Metal shaders, configuring SwiftUI view modifiers for performance, or targeting 120fps ProMotion on iOS.
version: 1.0
tags: [optimization, 120fps, performance, memory, pipeline]
author: Antigravity Performance Engineering
---

# High-Performance SwiftUI & Metal Pipeline Skill

## Strategic Usage

**Use this skill when:**

- Selecting between `.layerEffect`, `.distortionEffect`, and `.colorEffect` for specific visual outcomes.
- Optimizing shader code for Apple Silicon TBDR (Tile-Based Deferred Rendering) architectures.
- Debugging frame drops, stuttering, or thermal throttling.
- Implementing high-frequency animation loops (`TimelineView`).

## Architectural Decision Matrix

| Requirement | Recommended API | Performance Profile | Rationale |
| :--- | :--- | :--- | :--- |
| **Glass Refraction** | `.distortionEffect` | **High** | Modifies sampling coordinates only. Best for "Lensing" logic where color math is simple. |
| **Chromatic Aberration** | `.layerEffect` | **Medium** | Requires multiple texture samples (Red/Green/Blue) which `.distortionEffect` cannot handle. |
| **Simple Tinting** | `.colorEffect` | **Very High** | Modifies pixel output directly in registers; no texture sampling overhead. |
| **Complex Fluid Physics** | `Canvas` + Metal | **Variable** | Required if the simulation needs *state* (persistence) between frames, which stitchable shaders do not support. |

## Optimization Instructions

### 1. Data Types & Precision Strategy

**Rule:** Default to `half` precision types (`half4`, `half2`) for all color, lighting, and vector math.

- **Rationale:** Apple Silicon FP16 ALUs are 2x faster than FP32. Using `float` increases register pressure, reducing thread occupancy.
- **Exception:** Use `float` *only* for:
  - UV Coordinate calculations (position mapping).
  - SDF Position accumulation (to prevent stair-stepping artifacts in raymarching).
  - Time counters (`float time`).

### 2. Stitchable Function Signatures

Ensure all shaders meant for SwiftUI modifiers are marked `[[stitchable]]`. Match signatures exactly to avoid runtime linking failures.

- **Layer Effect:**
  ```cpp
  [[stitchable]] half4 liquid_layer(float2 pos, SwiftUI::Layer layer, float4 bounds, float time, args...)
  ```

- **Distortion Effect:**
  ```cpp
  [[stitchable]] float2 liquid_distortion(float2 pos, float time, args...)
  ```

### 3. The Animation Loop & Time

Drive continuous animations using `TimelineView`.

```swift
TimelineView(.animation) { context in
    let time = context.date.timeIntervalSinceReferenceDate
    ContentView()
        // Pass time as a float argument to the shader
       .distortionEffect(ShaderLibrary.glassWave(.float(time)), maxSampleOffset: .zero)
}
```

- **Critical:** `maxSampleOffset` in `.distortionEffect` must be set correctly. If set to `.zero`, pixels moved outside their original bounds will be clipped. Set this value to the maximum possible displacement (e.g., the blur radius or refractive shift magnitude).

### 4. ProMotion & Frame Pacing

- **Target:** 8.33ms per frame (120fps).
- **Profiling:** Use the Metal System Trace in Instruments. Monitor "Fragment Shader Execution Time."
- **Warning Signs:**
  - **High Register Pressure:** If the shader uses too many variables, the GPU creates "spills" to memory, killing performance. Refactor complex equations into smaller helper functions.
  - **Dependent Texture Reads:** Calculating UVs *and then* sampling is slower than sampling with fixed UVs. In `layerEffect`, try to minimize dependent reads.

### 5. Latency Management

- **Double Buffering:** For critical low-latency touch response (e.g., dragging a liquid blob), consider setting `CAMetalLayer.maximumDrawableCount = 2` if managing a custom `MTKView`. This reduces input-to-display latency but requires strict adherence to the 8.33ms budget to avoid dropped frames.
- For SwiftUI views, the system handles this, but minimizing main-thread layout work is crucial to allow the Render Server to grab the drawable in time.

## Quick Reference Tables

### Shader Modifier Selection Logic

| Effect Type | SwiftUI Modifier | MSL Return Type | Mathematical Operation | Performance Cost |
| :--- | :--- | :--- | :--- | :--- |
| **Refraction** | `.distortionEffect` | `float2` (New Position) | UV displacement via Snell's Law | Low |
| **Chromatic Aberration** | `.layerEffect` | `half4` (New Color) | Multi-sample with per-channel IOR | Medium |
| **Liquid Morphing (SDF)** | `.layerEffect` | `half4` (New Color) | Raymarching + `smin` | High |
| **Simple Tinting** | `.colorEffect` | `half4` (New Color) | Direct color transform | Very Low |

### Physical Constants for Simulation

| Material Property | Variable | Typical Value | Usage in Shader |
| :--- | :--- | :--- | :--- |
| **Refractive Index** | IOR | 1.50 (Glass), 1.33 (Water) | Snell's Law input (`refract` function) |
| **Dispersion** | Abbe No. / `δ` | 0.01–0.05 | Offset for RGB channels in aberration |
| **Smoothness** | `k` | 0.1–0.25 | Polynomial smooth min factor |
| **Fresnel Power** | `pow` | 5.0 | Exponent in Schlick's approximation |
| **Film Thickness** | `d` | 300nm–800nm | Thin-film interference phase calculation |
