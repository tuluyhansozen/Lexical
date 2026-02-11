---
name: metal-refraction-physics
description: Use when writing Metal Shading Language (MSL) code for refraction, caustics, SDFs, or thin-film interference.
version: 2.0
tags: [metal, msl, physics, math, shader, caustics, interference]
author: Antigravity Graphics Team
---

# Metal Refraction & Physics Skill

## Strategic Usage

**Use this skill when:**

- Writing `.metal` shader files for custom UI effects.
- Implementing `[[stitchable]]` functions for SwiftUI integration.
- Calculating physically accurate light transport (Snell's Law, Fresnel, Dispersion).
- Implementing Signed Distance Functions (SDF) for organic shape morphing.
- Simulating iridescent materials (thin-film interference).

## Mathematical Implementations & MSL Patterns

### 1. Refraction & Chromatic Dispersion

**Objective:** Simulate the wavelength-dependent bending of light. Do not use simple texture lookups.

**Physics:**
- Snell's Law: `n₁ sin θ₁ = n₂ sin θ₂`
- Dispersion: IOR (`n`) varies with wavelength (Cauchy's equation).

**MSL Implementation Strategy:**

1. **Inputs:** View Direction (`V`), Surface Normal (`N`), Base IOR (`η`), Dispersion Power (`δ`).
2. **Algorithm:** Compute three distinct refraction vectors.
   - Red Channel IOR: `η_r = η - δ`
   - Green Channel IOR: `η_g = η`
   - Blue Channel IOR: `η_b = η + δ`
3. **Fourier Interpolation (Advanced):** For high fidelity, use a 5-tap approximation (R, G, B + interpolated Yellow/Cyan) weighted by spectral sensitivity.

```cpp
// MSL Snippet: Chromatic Refraction
half3 refract_chromatic(float3 V, float3 N, float baseIOR, float dispersion, texture2d<half> bg, sampler s, float2 size) {
    // Red Channel
    float3 R_r = refract(V, N, 1.0 / (baseIOR - dispersion));
    float2 uv_r = calculate_uv(R_r, size); // Custom projection logic
    half red = bg.sample(s, uv_r).r;

    // Green Channel
    float3 R_g = refract(V, N, 1.0 / baseIOR);
    float2 uv_g = calculate_uv(R_g, size);
    half green = bg.sample(s, uv_g).g;

    // Blue Channel
    float3 R_b = refract(V, N, 1.0 / (baseIOR + dispersion));
    float2 uv_b = calculate_uv(R_b, size);
    half blue = bg.sample(s, uv_b).b;

    return half3(red, green, blue);
}
```

### 2. Fresnel Effect (Schlick's Approximation)

**Objective:** Simulate the "Rim Light" where reflectivity increases at grazing angles.

**Equation:**
`F(θ) = F₀ + (1 - F₀)(1 - cos θ)⁵`

**MSL Optimization:**
Use `saturate` to clamp the dot product. This is critical for preventing artifacts when normals are perturbed by noise maps.

```cpp
half fresnel_schlick(float3 V, float3 N, half f0) {
    float cosTheta = saturate(dot(N, -V));
    return f0 + (1.0h - f0) * pow(1.0 - cosTheta, 5.0);
}
```

### 3. Fluid Morphing via SDFs

**Objective:** Create "gooey" liquid merges between shapes.

**Mathematics:** Use the **Polynomial Smooth Minimum** (`smin`).

```
h = max(k - |d₁ - d₂|, 0.0) / k
smin(d₁, d₂, k) = min(d₁, d₂) - h³ · k · (1/6)
```

- **Parameter `k`:** The "Viscosity." Range `0.05` (water) to `0.3` (syrup).
- **Raymarching:** When rendering 3D liquid buttons on a 2D quad, use a Raymarching loop (Sphere Tracing) with a fixed step limit (e.g., 64 steps) to find the SDF surface. Use `dfdx`/`dfdy` to compute normals on the fly for lighting.

### 4. Thin-Film Interference (Iridescence)

**Objective:** Simulate soap bubbles or oil slicks.

**Physics:** Constructive/Destructive interference based on Optical Path Difference (OPD).

```
OPD = 2·n·d·cos(θ)
```

**MSL Implementation:**

1. Calculate OPD based on viewing angle `θ` and film thickness `d`.
2. Use a cosine-based spectral palette function to map OPD to RGB colors.
3. **Optimization:** Precompute the spectral palette into a 1D texture if the palette is complex, otherwise use analytic cosine approximation:
   ```
   col = 0.5 + 0.5 * cos(6.28 * (OPD * freq + phase))
   ```

### 5. Real-Time Caustics (Area Ratio)

**Objective:** Focus light through the glass.

**Mathematics:** Light intensity is inversely proportional to the area spread of the refracted rays.

**MSL Implementation:**

Use the Jacobian determinant of the refraction mapping.

```cpp
// Coordinate of the refracted ray hitting the background
float2 refractedUV = ...;

// Calculate screen-space derivatives
float2 dRx = dfdx(refractedUV);
float2 dRy = dfdy(refractedUV);

// Jacobian determinant approximates the area expansion/contraction
float areaRatio = abs(dRx.x * dRy.y - dRx.y * dRy.x);

// Intensity increases where area contracts (focus)
float causticIntensity = 1.0 / (areaRatio + 0.001); // Epsilon to prevent division by zero
```

- **Note:** Clamp `causticIntensity` to a reasonable maximum (e.g., `5.0`) to prevent fireflies (single bright pixels).

## Shader Conventions & Best Practices

- **Coordinate Systems:** SwiftUI passes coordinates in *points*. You must divide by the view size to get normalized UVs (0..1).
- **Layer Sampling:** When using `SwiftUI::Layer`, always clamp sampling coordinates to the `[0, 1]` range (or slightly inside, e.g., `0.001` to `0.999`) to avoid smearing edge pixels when distorting.
- **Precision:** Use `half` precision for all color vectors (`half4`) and lighting calculations. Use `float` only for UV coordinates and SDF position calculations to prevent precision banding.
