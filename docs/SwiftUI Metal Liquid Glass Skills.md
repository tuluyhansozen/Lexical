# **Architectural Blueprints for Antigravity Agent Skills: Liquid Glass, Metal Physics, and High-Performance UI Systems**

## **Executive Summary**

The transition from manual user interface engineering to agentic orchestration—facilitated by environments like the Google Antigravity IDE—necessitates a fundamental reimagining of how development knowledge is codified. In this new paradigm, the role of the senior architect shifts from writing individual lines of code to engineering "Agent Skills." These skills are comprehensive, machine-readable directives that guide autonomous agents through complex implementation tasks, ensuring adherence to rigorous architectural, aesthetic, and performance standards. This report provides an exhaustive analysis and production-ready definition for three such skill files, specifically tailored for the implementation of the "Liquid Glass" design language and professional-grade User Interface systems on iOS.1

The "Liquid Glass" aesthetic, introduced as a core design paradigm in iOS 26, represents a significant leap in computational complexity over previous design systems.2 It moves beyond static Gaussian blurs (the hallmark of the "frosted glass" era) to simulate dynamic, physics-based materials that exhibit real-time lensing, chromatic aberration, spectral dispersion, and fluid morphing.4 Implementing such a system requires a synthesis of disparate domains: high-level declarative state management (SwiftUI), low-level graphics programming (Metal Shading Language), and optical physics (thin-film interference, raymarching, and caustic simulation).

This report is structured to provide deep theoretical backing and actionable code blueprints for three primary skill domains:

1. **ios-liquid-glass-ui.md**: A skill governing the high-level composition of the Liquid Glass system, focusing on GlassEffectContainer architecture, fluid morphing topology, and accessibility mandates.2  
2. **metal-refraction-physics.md**: A skill encoding the mathematical core of the rendering engine, detailing the implementation of Snell’s Law, Fourier-series dispersion approximations, and Signed Distance Field (SDF) mathematics for organic shape manipulation.6  
3. **swiftui-metal-pipeline.md**: A skill dedicated to the optimization of the render loop, ensuring 120fps throughput on ProMotion displays via memory alignment, half-precision arithmetic, and pipeline state management.9

By formally defining these skills, we enable the Antigravity agent to act not merely as a code completion tool, but as a specialized graphics engineer capable of reasoning about the physics of light and the intricacies of the Apple Silicon GPU architecture.

## ---

**Chapter 1: The Architecture of Agentic Specialization**

### **1.1 The Antigravity Paradigm: From Keystrokes to Strategic Supervision**

The Antigravity IDE operates on a model of "strategic supervision," where the developer defines the constraints and objectives, and the agent executes the implementation.1 For this model to function in high-stakes environments—such as the rendering of complex, physics-based UIs—the agent requires more than just generic programming knowledge; it requires domain-specific "guardrails." These guardrails are implemented as "Agent Skills," modular protocols stored as Markdown files that the agent ingests to augment its context window.1

In the context of iOS 26 development, the agent must navigate a complex dependency graph. It must understand that a GlassEffectContainer is not merely a visual grouper but a shared sampling region that enables morphing.2 It must recognize that "Liquid Glass" is a real-time simulation of light bending (lensing) that requires specific Metal modifiers, distinguishing it from legacy blurring techniques.3 The architecture of these skill files must therefore be hierarchical, separating high-level intent from low-level implementation while maintaining a cohesive vision.

### **1.2 The Taxonomy of Skill Files**

An effective Antigravity skill file is composed of three critical sections, designed to maximize agent performance while minimizing "context saturation" 1:

1. **Metadata Triggers**: YAML frontmatter that defines *when* the skill should be activated. This ensures the agent only loads heavy mathematical definitions when the user explicitly requests shader work or physics simulations, preserving token bandwidth for relevant tasks.  
2. **Strategic Heuristics**: High-level rules that guide decision-making (e.g., "Always prefer half precision over float for fragment shaders unless distinct banding artifacts appear").  
3. **Technical Blueprints**: The actual code patterns, mathematical formulas, and API constraints that the agent must adhere to.

This report details the creation of three specific skill files required for the Liquid Glass ecosystem, analyzing the "why" behind every instruction.

## ---

**Chapter 2: Skill File 1 — Orchestrating the Liquid Glass Design System (ios-liquid-glass-ui.md)**

### **2.1 Strategic Objective: Beyond Glassmorphism**

The primary objective of the ios-liquid-glass-ui.md skill is to codify the design language of iOS 26\. This system differs fundamentally from the "glassmorphism" trend of the early 2020s. While glassmorphism relied on static translucency and white borders, Liquid Glass mimics the optical properties of a variable-index fluid. It involves "Lensing"—the bending and concentration of light—rather than simple scattering.3

The agent must be instructed to treat UI elements as physical volumes that displace light. This necessitates strict adherence to the GlassEffectContainer API, which manages the blending of overlapping glass layers to prevent the visual artifacting known as "blur piles" or "double-blur," where stacked translucent views result in a muddy, grey appearance.1

### **2.2 Architectural Foundations of Fluid Morphing**

One of the defining characteristics of Liquid Glass is its "fluidity"—the ability of disparate UI elements to morph into one another when they come into proximity.2 The agent must understand the mathematical implications of the GlassEffectContainer in this context.

The container operates on a *threshold distance* principle, similar to the concept of "metaballs" in computer graphics. If two elements ![][image1] and ![][image2] are located at positions ![][image3] and ![][image4], their visual merging is a function of their Euclidean distance ![][image5] relative to a smoothing factor ![][image6], which is exposed in the API as the spacing parameter.

![][image7]  
When ![][image8], the renderer computes a smooth boolean union rather than rendering distinct geometries. The skill file must instruct the agent to utilize GlassEffectContainer(spacing: CGFloat) to control this ![][image6] factor, allowing the designer to tune the "surface tension" of the interface.2 High spacing values create a "sticky" interface where elements reach out to connect; low values create rigid, distinct elements.

### **2.3 The Accessibility Mandate**

A critical, often overlooked aspect of professional UI development is accessibility. Liquid Glass, by its nature, reduces contrast by allowing background content to bleed through control layers. A professional-grade implementation *must* account for this. The agent skill must enforce a "Robust Fallback" strategy.

Research indicates that users may have the "Reduce Transparency" system setting enabled.5 The agent must be trained to wrap every glass implementation in a conditional check that swaps the sophisticated glassEffect for a high-contrast, opaque material (e.g., .systemMaterial or a solid color) when this setting is active. Furthermore, when tinting glass, the agent must enforce opacity constraints (0.7–0.9) to ensure that the "glass" nature is preserved without sacrificing the legibility of text labels.5

### **2.4 The Skill File Content**

The following section presents the complete, machine-readable definition for ios-liquid-glass-ui.md.

#### ---

**File: ios-liquid-glass-ui.md**

YAML

name: ios-liquid-glass-ui  
description: Use when implementing UI features using the iOS 26\+ Liquid Glass API, GlassEffectContainer, or fluid morphing design patterns.  
version: 1.0  
tags: \[swiftui, ios26, design-system, accessibility, morphing\]  
author: Antigravity Architecture Team

# **Liquid Glass UI & Design System Skill**

## **Strategic Usage**

**Use this skill when:**

* Implementing navigation layers (Tab Bars, Toolbars, Sidebars) using the iOS 26 design language.2  
* Grouping multiple translucent elements that must physically blend or morph.  
* Designing "Floating Action Buttons" (FABs) that expand into menus with fluid transitions.  
* Implementing accessibility fallbacks for transparency-sensitive users.

**Do not use this skill when:**

* Writing low-level Metal Shading Language (MSL) code (use metal-refraction-physics instead).  
* Optimizing the render loop for 120fps (use swiftui-metal-pipeline instead).  
* Applying effects to the content layer (lists, cards, images); glass is strictly for the *control* layer.4

## **Core Design Principles (iOS 26\)**

1. **Lensing over Blurring:** Liquid Glass bends light; it does not just scatter it. Background content should remain discernible but distorted, creating optical depth.3  
2. **Fluidity & Tension:** Elements are not rigid. They possess surface tension. When close, they should merge; when separating, they should exhibit elasticity.  
3. **Hierarchy:** Glass floats *above* content. Never stack glass on glass, as this creates muddy visuals and breaks the refractive illusion.4

## **Technical Instructions**

### **1\. Container Architecture & Surface Tension**

The GlassEffectContainer is the fundamental unit of the Liquid Glass system. It creates a shared sampling buffer for all child elements, enabling mathematically correct blending.

* **Rule:** Always wrap groups of glass elements in a GlassEffectContainer.  
* **Surface Tension (spacing):** Use the spacing parameter to define the morphing threshold (![][image6]).  
  * spacing: 0 \-\> Sharp edges, no merging.  
  * spacing: 20 \-\> Standard system behavior; elements "kiss" and merge when adjacent.  
  * spacing: \>40 \-\> High viscosity; elements stretch to connect over long distances.

Swift

// Correct Usage: Grouping distinct controls into a unified glass manifold  
GlassEffectContainer(spacing: 20.0) {  
    HStack {  
        Button(action: { /\*...\*/ }) {  
            Image(systemName: "mic.fill")  
               .glassEffect(.regular.interactive())  
        }  
        // These buttons will fluidly merge if they move within 20pt of each other  
        Button(action: { /\*...\*/ }) {  
            Image(systemName: "phone.fill")  
               .glassEffect(.regular.interactive())  
        }  
    }  
}

### **2\. Material Variants & Interactivity**

* **The .glassEffect Modifier:** Apply this to define the material properties.  
* **Ordering:** Apply .glassEffect() *after* frame/shape definitions but *before* layout padding if the padding defines the "touch target" rather than the visual bounds.  
* **Interactivity:** Always append .interactive() for tappable elements. This enables the system-standard "specular bounce" and "shimmer" animation on touch down.2  
  * .regular: The default. Adapts to light/dark mode automatically.  
  * .clear: High transparency. Use **only** for overlays on media-rich content (photos/maps) where obscuring pixels is detrimental.4  
  * .prominent: Thicker, higher refractive index. Use for modal backgrounds.

### **3\. Morphing and Identity**

To enable fluid state transitions (e.g., a button expanding into a panel), utilize glassEffectID coupled with a SwiftUI Namespace.

* **Mechanism:** SwiftUI uses the ID to track the "material identity" across the render graph. The GlassEffectContainer interpolates the SDF (Signed Distance Field) of the shapes between states.  
* **Implementation Pattern:**  
  Swift  
  @Namespace var glassNamespace

  // Within a GlassEffectContainer  
  if isExpanded {  
      MenuContent()  
         .glassEffect(.regular)  
         .glassEffectID("sharedID", in: glassNamespace) // Identity preservation  
         .transition(.scale(scale: 0.8, anchor:.bottomTrailing).combined(with:.opacity))  
  } else {  
      FabButton()  
         .glassEffect(.regular.interactive())  
         .glassEffectID("sharedID", in: glassNamespace)  
  }

### **4\. Accessibility Mandates**

Liquid Glass inherently reduces contrast. You must implement robust fallbacks.

* **Environment Check:** Monitor @Environment(\\.accessibilityReduceTransparency).  
* **Fallback Strategy:** If true, the agent must generate code that swaps .glassEffect() for a solid, high-contrast material.  
* **Legibility:** When using .tint(), ensure opacity is between **0.7-0.9**. Full opacity (1.0) defeats the refractive purpose; too low (\<0.5) compromises text legibility.5

## **Common Pitfalls**

* **Nesting:** Never nest a GlassEffectContainer inside another. This causes undefined sampling behavior and performance degradation.  
* **Content Layer:** Do not apply glass effects to scrolling content cells (e.g., inside a List). It creates excessive overdraw. Glass belongs in the overlay or safeAreaInset of the view hierarchy.

### ---

**2.5 Analysis of the Skill**

This skill file abstracts the complexity of the iOS 26 rendering engine. By enforcing the usage of GlassEffectContainer, we ensure that the agent does not generate legacy code using UIVisualEffectView or simple blur modifiers. The inclusion of the "spacing" parameter allows the agent to reason about the *physics* of the interface (surface tension) without needing to write the physics code itself. The strict accessibility guidelines ensure the output is professional and App Store-ready, preventing common rejections related to usability.

## ---

**Chapter 3: Skill File 2 — The Physics of Light and Metal Shaders (metal-refraction-physics.md)**

### **3.1 Strategic Objective: Simulation vs. Approximation**

While the first skill handles high-level composition, metal-refraction-physics.md provides the agent with the mathematical competence to write the custom Metal Shaders (MSL) that power the Liquid Glass effect. In professional UI development, "faking it" with simple alpha blending is no longer sufficient. Users expect physically plausible optical interactions.

This involves three distinct mathematical domains:

1. **Optical Physics:** Refraction, Reflection (Fresnel), and Chromatic Dispersion.  
2. **Fluid Dynamics (SDFs):** Mathematical modeling of shapes for organic merging.  
3. **Thin-Film Interference:** Simulating iridescence (e.g., soap bubbles) via optical path differences.  
4. **Caustics:** Simulating the focusing of light rays through curved surfaces.

### **3.2 Mathematical Derivations for the Agent**

#### **3.2.1 Refraction and Chromatic Dispersion (Fourier Interpolation)**

Standard shaders often use a single Index of Refraction (IOR) for all light. However, real glass exhibits *dispersion*: different wavelengths bend at different angles. A naive implementation samples the texture three times (Red, Green, Blue) with slightly different offset vectors.8 A professional implementation uses **Fourier Interpolation** to simulate a continuous spectrum.8

The intensity ![][image9] at a pixel is the integral over the visible spectrum ![][image10]:

![][image11]  
Where ![][image12] is the background texture, ![][image13] is the UV coordinate, and ![][image14] is the displacement vector as a function of wavelength. Since real-time integration is too expensive, the agent must use a discrete approximation using spectral weights (RGB \+ Cyan/Magenta/Yellow intermediate samples) to smooth the banding artifacts common in basic chromatic aberration.8

#### **3.2.2 The SDF Smooth Union (The "Liquid" Math)**

To achieve the "gooey" merging of shapes within the shader, the agent must utilize the **Polynomial Smooth Minimum** function. Standard boolean unions (![][image15]) create sharp creases. The smooth union creates a meniscus-like blend.6

The mixing factor ![][image16] is derived as:

$$h \= \\frac{\\max(k \- |d\_1 \- d\_2|, 0.0)}{k}$$And the resulting distance field ![][image17] is:

![][image18]  
Here, ![][image6] represents the smoothness factor (viscosity). The agent must expose this ![][image6] as a uniform float to SwiftUI, allowing designers to animate the "stickiness" of the UI.

#### **3.2.3 Thin-Film Interference**

For "holographic" or "iridescent" effects, the agent must implement the physics of thin-film interference. This occurs when light reflects off the top and bottom surfaces of a thin layer (like oil on water). The phase difference ![][image19] depends on the film thickness ![][image20], refractive index ![][image21], and viewing angle ![][image22] 11:

![][image23]  
Constructive interference occurs when this phase difference aligns with the wavelength. The agent must implement this by calculating the **Optical Path Difference (OPD)**:

![][image24]  
This OPD value is then used to sample a spectral color ramp (e.g., a cosine-palette function) to determine the interference color for that pixel.

#### **3.2.4 Real-Time Caustics (Area Ratio Method)**

Caustics are the bright patterns formed when light is focused by a curved surface (like sunlight on a pool bottom). Ray-tracing caustics is too slow for mobile UI. The agent must use the **Area Ratio Method**.13

This technique approximates the intensity of light flux by comparing the area of a differential patch on the refractive surface to the area of that patch projected onto the receiving surface. In screen-space shaders, this can be approximated using the partial derivatives of the refracted ray positions:

![][image25]  
Where ![][image26] is the Jacobian matrix of the refraction mapping. In MSL, this is efficiently calculated using dfdx and dfdy instructions on the texture coordinates of the refracted ray.

### **3.3 The Skill File Content**

#### ---

**File: metal-refraction-physics.md**

YAML

name: metal-refraction-physics  
description: Use when writing Metal Shading Language (MSL) code for refraction, caustics, SDFs, or thin-film interference.  
version: 2.0  
tags: \[metal, msl, physics, math, shader, caustics, interference\]  
author: Antigravity Graphics Team

# **Metal Refraction & Physics Skill**

## **Strategic Usage**

**Use this skill when:**

* Writing .metal shader files for custom UI effects.  
* Implementing \[\[stitchable\]\] functions for SwiftUI integration.  
* Calculating physically accurate light transport (Snell's Law, Fresnel, Dispersion).  
* Implementing Signed Distance Functions (SDF) for organic shape morphing.  
* Simulating iridescent materials (thin-film interference).

## **Mathematical Implementations & MSL Patterns**

### **1\. Refraction & Chromatic Dispersion**

**Objective:** Simulate the wavelength-dependent bending of light. Do not use simple texture lookups.

**Physics:**

Snell's Law: ![][image27].

Dispersion: ![][image28] varies with wavelength (Cauchy's equation).

**MSL Implementation Strategy:**

1. **Inputs:** View Direction (![][image29]), Surface Normal (![][image30]), Base IOR (![][image31]), Dispersion Power (![][image19]).  
2. **Algorithm:** Compute three distinct refraction vectors.  
   * Red Channel IOR: ![][image32]  
   * Green Channel IOR: ![][image33]  
   * Blue Channel IOR: ![][image34]  
3. **Fourier Interpolation (Advanced):** For high fidelity, use a 5-tap approximation (R, G, B \+ interpolated Yellow/Cyan) weighted by spectral sensitivity.8

C++

// MSL Snippet: Chromatic Refraction  
half3 refract\_chromatic(float3 V, float3 N, float baseIOR, float dispersion, texture2d\<half\> bg, sampler s, float2 size) {  
    // Red Channel  
    float3 R\_r \= refract(V, N, 1.0 / (baseIOR \- dispersion));  
    float2 uv\_r \= calculate\_uv(R\_r, size); // Custom projection logic  
    half red \= bg.sample(s, uv\_r).r;

    // Green and Blue channels similarly...  
      
    return half3(red, green, blue);  
}

### **2\. Fresnel Effect (Schlick's Approximation)**

**Objective:** Simulate the "Rim Light" where reflectivity increases at grazing angles.

**Equation:**

**![][image35]**  
**MSL Optimization:**

Use saturate to clamp the dot product. This is critical for preventing artifacts when normals are perturbed by noise maps.

C++

half fresnel\_schlick(float3 V, float3 N, half f0) {  
    float cosTheta \= saturate(dot(N, \-V));  
    return f0 \+ (1.0h \- f0) \* pow(1.0 \- cosTheta, 5.0);  
}

### **3\. Fluid Morphing via SDFs**

**Objective:** Create "gooey" liquid merges between shapes.

**Mathematics:** Use the **Polynomial Smooth Minimum** (smin).

![][image36]  
![][image37]

* **Parameter k:** The "Viscosity." Range 0.05 (water) to 0.3 (syrup).  
* **Raymarching:** When rendering 3D liquid buttons on a 2D quad, use a Raymarching loop (Sphere Tracing) with a fixed step limit (e.g., 64 steps) to find the SDF surface.7 Use dfdx/dfdy to compute normals on the fly for lighting.

### **4\. Thin-Film Interference (Iridescence)**

**Objective:** Simulate soap bubbles or oil slicks.

**Physics:** Constructive/Destructive interference based on Optical Path Difference (OPD).

![][image24]  
**MSL Implementation:**

1. Calculate OPD based on viewing angle ![][image22] and film thickness ![][image20].  
2. Use a cosine-based spectral palette function to map OPD to RGB colors.  
3. **Optimization:** Precompute the spectral palette into a 1D texture if the palette is complex, otherwise use analytic cosine approximation: col \= 0.5 \+ 0.5 \* cos(6.28 \* (OPD \* freq \+ phase)).

### **5\. Real-Time Caustics (Area Ratio)**

**Objective:** Focus light through the glass.

**Mathematics:** Light intensity is inversely proportional to the area spread of the refracted rays.

**MSL Implementation:**

Use the Jacobian determinant of the refraction mapping.

C++

// Coordinate of the refracted ray hitting the background  
float2 refractedUV \=...; 

// Calculate screen-space derivatives  
float2 dRx \= dfdx(refractedUV);  
float2 dRy \= dfdy(refractedUV);

// Jacobian determinant approximates the area expansion/contraction  
float areaRatio \= abs(dRx.x \* dRy.y \- dRx.y \* dRy.x);

// Intensity increases where area contracts (focus)  
float causticIntensity \= 1.0 / (areaRatio \+ 0.001); // Epsilon to prevent division by zero

* **Note:** Clamp causticIntensity to a reasonable maximum (e.g., 5.0) to prevent fireflies (single bright pixels).13

## **Shader Conventions & Best Practices**

* **Coordinate Systems:** SwiftUI passes coordinates in *points*. You must divide by the view size to get normalized UVs (0..1).  
* **Layer Sampling:** When using SwiftUI::Layer, always clamp sampling coordinates to the \`\` range (or slightly inside, e.g., 0.001 to 0.999) to avoid smearing edge pixels when distorting.16  
* **Precision:** Use half precision for all color vectors (half4) and lighting calculations. Use float only for UV coordinates and SDF position calculations to prevent precision banding.17

### ---

**3.4 Analysis of the Skill**

This skill file functions as a physics textbook compressed into engineering directives. By explicitly detailing Schlick's approximation, the polynomial smooth-min, and the area-ratio caustic method, we ensure the agent generates performant, professional-grade graphics code. Calculating real Fresnel equations involves expensive trigonometry; Schlick's approximation is the industry standard for its balance of accuracy and speed.18 The inclusion of spectral dispersion and caustics logic elevates the output from "transparent UI" to "simulated material," meeting the high bar of iOS 26 design.

## ---

**Chapter 4: Skill File 3 — Pipeline Optimization for Professional UIs (swiftui-metal-pipeline.md)**

### **4.1 Strategic Objective: The 120fps Requirement**

Visual fidelity implies nothing without performance. The standard for professional iOS apps is 120fps on ProMotion displays. Dropping frames breaks the illusion of "fluidity" essential to Liquid Glass. Furthermore, the physics simulations (SDFs, Caustics) defined in Skill 2 are computationally expensive. This skill file, swiftui-metal-pipeline.md, guides the agent in optimizing the bridge between SwiftUI and the GPU to maintain this frame rate.

### **4.2 Architectural Patterns for Performance**

The agent must choose between two primary integration patterns defined in the research:

1. **Stitchable Shaders (The Modern Path):** Using .colorEffect, .distortionEffect, and .layerEffect. This allows SwiftUI to manage the pipeline state, effectively "stitching" the custom MSL code into its own render pass.9  
2. **MTKView / MetalKit (The Legacy/Control Path):** Manually managing the command buffer, render pipeline state, and drawables.

For Liquid Glass UI components, the **Stitchable** path is preferred for composability. However, the agent must distinguish between modifiers:

* **distortionEffect**: Modifies the *coordinate* from which a pixel is sampled (![][image38]). It is cheap because it doesn't change the color computation logic, only the memory address lookup. Ideal for refraction.16  
* **layerEffect**: Allows arbitrary color blending and sampling (![][image39]). It is more powerful (required for chromatic aberration where we sample multiple times) but potentially more expensive.19

### **4.3 120fps Optimization Heuristics**

To maintain 120fps (8.33ms frame time), the agent must enforce strict budgets:

* **Half-Precision Arithmetic:** Mobile GPUs (Apple Silicon) have dedicated FP16 execution units that are often 2x faster than FP32. Using float (32-bit) doubles register pressure and memory bandwidth. The agent must enforce half4, half3, and half types for all color/lighting math.17  
* **Double vs. Triple Buffering:** iOS defaults to triple buffering (maximumDrawableCount \= 3). This maximizes frame rate but increases input latency (lag). For "Liquid" interfaces that depend on touch responsiveness (dragging a blob), the agent should consider maximumDrawableCount \= 2 if the frame budget allows, to minimize the "rubber band" feel.10  
* **Pre-Compilation:** Shaders must not be compiled at runtime. The agent must ensure .metal files are included in the build target to generate the default .metallib.21

### **4.4 The Animation Loop: Physics Integration**

For physics-based UIs (springs, fluid ripples), standard SwiftUI animations (withAnimation) drive the *parameters* of the shader.

* **TimelineView(.animation)**: This is the heartbeat. It provides the context.date needed to drive continuous simulations (like water ripples or caustic shimmering).9  
* **Spring Dynamics:** The agent should use SwiftUI's spring interpolation to drive a float uniform (e.g., morphFactor) rather than implementing the spring physics *inside* the shader. This keeps the GPU logic stateless and deterministic.23

### **4.5 The Skill File Content**

#### ---

**File: swiftui-metal-pipeline.md**

YAML

name: swiftui-metal-pipeline  
description: Use when optimizing Metal shaders, configuring SwiftUI view modifiers for performance, or targeting 120fps ProMotion on iOS.  
version: 1.0  
tags: \[optimization, 120fps, performance, memory, pipeline\]  
author: Antigravity Performance Engineering

# **High-Performance SwiftUI & Metal Pipeline Skill**

## **Strategic Usage**

**Use this skill when:**

* Selecting between .layerEffect, .distortionEffect, and .colorEffect for specific visual outcomes.  
* Optimizing shader code for Apple Silicon TBDR (Tile-Based Deferred Rendering) architectures.  
* Debugging frame drops, stuttering, or thermal throttling.  
* Implementing high-frequency animation loops (TimelineView).

## **Architectural Decision Matrix**

| Requirement | Recommended API | Performance Profile | Rationale |
| :---- | :---- | :---- | :---- |
| **Glass Refraction** | .distortionEffect | **High** | Modifies sampling coordinates only. Best for "Lensing" logic where color math is simple.16 |
| **Chromatic Aberration** | .layerEffect | **Medium** | Requires multiple texture samples (Red/Green/Blue) which .distortionEffect cannot handle.19 |
| **Simple Tinting** | .colorEffect | **Very High** | Modifies pixel output directly in registers; no texture sampling overhead. |
| **Complex Fluid Physics** | Canvas \+ Metal | **Variable** | Required if the simulation needs *state* (persistence) between frames, which stitchable shaders do not support. |

## **Optimization Instructions**

### **1\. Data Types & Precision Strategy**

**Rule:** Default to half precision types (half4, half2) for all color, lighting, and vector math.

* **Rationale:** Apple Silicon FP16 ALUs are 2x faster than FP32. Using float increases register pressure, reducing thread occupancy.17  
* **Exception:** Use float *only* for:  
  * UV Coordinate calculations (position mapping).  
  * SDF Position accumulation (to prevent stair-stepping artifacts in raymarching).  
  * Time counters (float time).

### **2\. Stitchable Function Signatures**

Ensure all shaders meant for SwiftUI modifiers are marked \[\[stitchable\]\]. Match signatures exactly to avoid runtime linking failures.

* **Layer Effect:**  
  C++  
  \[\[stitchable\]\] half4 liquid\_layer(float2 pos, SwiftUI::Layer layer, float4 bounds, float time, args...)

* **Distortion Effect:**  
  C++  
  \[\[stitchable\]\] float2 liquid\_distortion(float2 pos, float time, args...)

### **3\. The Animation Loop & Time**

Drive continuous animations using TimelineView.

Swift

TimelineView(.animation) { context in  
    let time \= context.date.timeIntervalSinceReferenceDate  
    ContentView()  
        // Pass time as a float argument to the shader  
       .distortionEffect(ShaderLibrary.glassWave(.float(time)), maxSampleOffset:.zero)  
}

* **Critical:** maxSampleOffset in .distortionEffect must be set correctly. If set to .zero, pixels moved outside their original bounds will be clipped. Set this value to the maximum possible displacement (e.g., the blur radius or refractive shift magnitude).16

### **4\. ProMotion & Frame Pacing**

* **Target:** 8.33ms per frame (120fps).  
* **Profiling:** Use the Metal System Trace in Instruments. Monitor "Fragment Shader Execution Time."  
* **Warning Signs:**  
  * **High Register Pressure:** If the shader uses too many variables, the GPU creates "spills" to memory, killing performance. Refactor complex equations into smaller helper functions.  
  * **Dependent Texture Reads:** Calculating UVs *and then* sampling is slower than sampling with fixed UVs. In layerEffect, try to minimize dependent reads.

### **5\. Latency Management**

* **Double Buffering:** For critical low-latency touch response (e.g., dragging a liquid blob), consider setting CAMetalLayer.maximumDrawableCount \= 2 if managing a custom MTKView. This reduces input-to-display latency but requires strict adherence to the 8.33ms budget to avoid dropped frames.10 For SwiftUI views, the system handles this, but minimizing main-thread layout work is crucial to allow the Render Server to grab the drawable in time.

### ---

**4.6 Analysis of the Skill**

This skill ensures the agent produces code that respects the hardware limitations of mobile devices. The mathematical distinction between layerEffect and distortionEffect is crucial: one is ![][image40] (Color), the other is ![][image41] (Position). By forcing the agent to recognize this, we prevent inefficient implementations where an agent might try to implement refraction using a generic layerEffect that manually recalculates texture coordinates unnecessarily. The emphasis on half precision is a direct industry standard for mobile graphics, ensuring the "Liquid Glass" effect doesn't drain the user's battery.

## ---

**Chapter 5: Integration and Future Outlook**

### **5.1 Synthesis of Skills: A Practical Workflow**

The true power of this architectural blueprint lies in the interaction between the three skills. Consider a user request: *"Create a Liquid Glass Sidebar that morphs into a bubble when the user drags it."*

1. The **Design Skill (ios-liquid-glass-ui.md)** activates first. It determines the structure: a GlassEffectContainer grouping the sidebar items. It sets up the spacing parameter to allow for the "bubble" morphing and prepares the Accessibility Fallback structure.  
2. The **Physics Skill (metal-refraction-physics.md)** generates the MSL code. It writes a shader implementing Snell's law for the sidebar's refraction. It adds the "Area Ratio" caustic logic to give the bubble edges a realistic brightness boost. It uses smin (smooth minimum) to handle the geometric transition from "Rectangle" (Sidebar) to "Circle" (Bubble).  
3. The **Pipeline Skill (swiftui-metal-pipeline.md)** ensures the implementation uses .distortionEffect for the refraction to save performance. It types all color variables as half4. It wraps the interaction in a TimelineView to ensure the morphing animation runs at 120fps on an iPhone 15 Pro/16 Pro.

### **5.2 The "Intermediate Plateau" Solution**

The introductory snippets mentioned the "intermediate plateau" in language learning apps.1 Interestingly, there is a parallel "intermediate plateau" in UI development, where developers can build functional apps but fail to achieve the "native, premium" feel of Apple's own apps. These skill files bridge that gap. By encoding the "magic" (physics, optimization, advanced composition) into reusable skills, the Antigravity IDE allows developers to transcend this plateau, producing interfaces that are not just functional, but delightful and physically plausible.

### **5.3 Conclusion**

By implementing these three detailed Antigravity agent skill files, we establish a robust engineering environment capable of producing iOS 26-grade interfaces. The ios-liquid-glass-ui.md file ensures semantic and visual correctness via containerization and accessibility rules. The metal-refraction-physics.md file ensures mathematical plausibility through rigorous optical equations (Fresnel, Dispersion, Caustics). The swiftui-metal-pipeline.md file ensures that the resulting application performs with the fluidity expected of a professional Apple platform experience. This triad transforms the agent from a code generator into a specialized graphics engineer, capable of navigating the complex intersection of art, math, and performance.

### **Tables of Reference**

**Table 1: Shader Modifier Selection Logic**

| Effect Type | SwiftUI Modifier | MSL Return Type | Mathematical Operation | Performance Cost |
| :---- | :---- | :---- | :---- | :---- |
| **Refraction** | .distortionEffect | float2 (New Position) | ![][image42] | Low |
| **Chromatic Aberration** | .layerEffect | half4 (New Color) | ![][image43] | Medium |
| **Liquid Morphing (SDF)** | .layerEffect | half4 (New Color) | ![][image44] | High (if raymarching) |
| **Simple Tinting** | .colorEffect | half4 (New Color) | ![][image45] | Very Low |

**Table 2: Physical Constants for Simulation (Skill 2\)**

| Material Property | Variable | Typical Value | Usage in Shader |
| :---- | :---- | :---- | :---- |
| **Refractive Index** | IOR | 1.50 (Glass), 1.33 (Water) | Snell's Law input (refract function) |
| **Dispersion** | Abbe No. / ![][image19] | 0.01 \- 0.05 | Offset for RGB channels in aberration |
| **Smoothness** | k | 0.1 \- 0.25 | Polynomial smooth min factor (![][image16]) |
| **Fresnel Power** | pow | 5.0 | Exponent in Schlick's approximation |
| **Film Thickness** | d | 300nm \- 800nm | Thin-film interference phase calculation |

This concludes the architectural blueprint for the requested Antigravity Agent Skills.

#### **Alıntılanan çalışmalar**

1. Antigravity IDE Skills File Generation  
2. iOS 26 Liquid Glass: Comprehensive Swift/SwiftUI Reference \- GitHub, erişim tarihi Şubat 10, 2026, [https://github.com/conorluddy/LiquidGlassReference](https://github.com/conorluddy/LiquidGlassReference)  
3. Liquid Glass \- Wikipedia, erişim tarihi Şubat 10, 2026, [https://en.wikipedia.org/wiki/Liquid\_Glass](https://en.wikipedia.org/wiki/Liquid_Glass)  
4. Liquid Glass in Swift: Official Best Practices for iOS 26 & macOS Tahoe, erişim tarihi Şubat 10, 2026, [https://dev.to/diskcleankit/liquid-glass-in-swift-official-best-practices-for-ios-26-macos-tahoe-1coo](https://dev.to/diskcleankit/liquid-glass-in-swift-official-best-practices-for-ios-26-macos-tahoe-1coo)  
5. Build a Liquid Glass Design System in SwiftUI (IOS 26), erişim tarihi Şubat 10, 2026, [https://levelup.gitconnected.com/build-a-liquid-glass-design-system-in-swiftui-ios-26-bfa62bcba5be](https://levelup.gitconnected.com/build-a-liquid-glass-design-system-in-swiftui-ios-26-bfa62bcba5be)  
6. SDF in Metal: Adding the Liquid to the Glass | by Victor Baro | Medium, erişim tarihi Şubat 10, 2026, [https://medium.com/@victorbaro/sdf-in-metal-adding-the-liquid-to-the-glass-69abd57e2151](https://medium.com/@victorbaro/sdf-in-metal-adding-the-liquid-to-the-glass-69abd57e2151)  
7. Painting with Math: A Gentle Study of Raymarching, erişim tarihi Şubat 10, 2026, [https://blog.maximeheckel.com/posts/painting-with-math-a-gentle-study-of-raymarching/](https://blog.maximeheckel.com/posts/painting-with-math-a-gentle-study-of-raymarching/)  
8. Refraction, dispersion, and other shader light effects \- The Blog of, erişim tarihi Şubat 10, 2026, [https://blog.maximeheckel.com/posts/refraction-dispersion-and-other-shader-light-effects/](https://blog.maximeheckel.com/posts/refraction-dispersion-and-other-shader-light-effects/)  
9. SwiftUI & Metal: Creating a Custom Animated Background | by ..., erişim tarihi Şubat 10, 2026, [https://medium.com/@aniketbaneani/swiftui-metal-creating-a-custom-animated-background-b411d9990459](https://medium.com/@aniketbaneani/swiftui-metal-creating-a-custom-animated-background-b411d9990459)  
10. iOS Metal double-buffering at 120 fps \- Stack Overflow, erişim tarihi Şubat 10, 2026, [https://stackoverflow.com/questions/51138426/ios-metal-double-buffering-at-120-fps](https://stackoverflow.com/questions/51138426/ios-metal-double-buffering-at-120-fps)  
11. Thin Film Interference \- BYJU'S, erişim tarihi Şubat 10, 2026, [https://byjus.com/jee/thin-film-interference/](https://byjus.com/jee/thin-film-interference/)  
12. Thin Film Interference \- RainbowSpec, erişim tarihi Şubat 10, 2026, [https://rainbowspec.observer/thinfilm/](https://rainbowspec.observer/thinfilm/)  
13. Rendering Realtime Caustics in WebGL | by Evan Wallace \- Medium, erişim tarihi Şubat 10, 2026, [https://medium.com/@evanwallace/rendering-realtime-caustics-in-webgl-2a99a29a0b2c](https://medium.com/@evanwallace/rendering-realtime-caustics-in-webgl-2a99a29a0b2c)  
14. Shining a light on Caustics with Shaders and React Three Fiber, erişim tarihi Şubat 10, 2026, [https://blog.maximeheckel.com/posts/caustics-in-webgl/](https://blog.maximeheckel.com/posts/caustics-in-webgl/)  
15. Raymarching \- Simon Ashbery \- Medium, erişim tarihi Şubat 10, 2026, [https://si-ashbery.medium.com/raymarching-3cdf86c637ba](https://si-ashbery.medium.com/raymarching-3cdf86c637ba)  
16. Image Distortion Animation using SwiftUI and Metal | by Arif ahmed, erişim tarihi Şubat 10, 2026, [https://medium.com/@arifahmedauny/image-distortion-animation-using-swiftui-and-metal-2f2658bbe554](https://medium.com/@arifahmedauny/image-distortion-animation-using-swiftui-and-metal-2f2658bbe554)  
17. Metal for SwiftUI \- Alex Logan, erişim tarihi Şubat 10, 2026, [https://alexanderlogan.co.uk/blog/wwdc23/09-metal](https://alexanderlogan.co.uk/blog/wwdc23/09-metal)  
18. The Basics of Fresnel Shading \- Kyle Halladay, erişim tarihi Şubat 10, 2026, [https://kylehalladay.com/blog/tutorial/2014/02/18/Fresnel-Shaders-From-The-Ground-Up.html](https://kylehalladay.com/blog/tutorial/2014/02/18/Fresnel-Shaders-From-The-Ground-Up.html)  
19. SwiftUI: Get Start With Metal Shader Using Layer Effect Modifiers, erişim tarihi Şubat 10, 2026, [https://levelup.gitconnected.com/swiftui-get-start-with-metal-shader-using-layer-effect-modifiers-239df1a8ab96](https://levelup.gitconnected.com/swiftui-get-start-with-metal-shader-using-layer-effect-modifiers-239df1a8ab96)  
20. Performance cost of float ↔︎ half conversion in Metal, erişim tarihi Şubat 10, 2026, [https://stackoverflow.com/questions/66561048/performance-cost-of-float-%E2%86%94%EF%B8%8E-half-conversion-in-metal](https://stackoverflow.com/questions/66561048/performance-cost-of-float-%E2%86%94%EF%B8%8E-half-conversion-in-metal)  
21. twostraws/Inferno: Metal shaders for SwiftUI. \- GitHub, erişim tarihi Şubat 10, 2026, [https://github.com/twostraws/Inferno](https://github.com/twostraws/Inferno)  
22. MetalGraph: a new way of working with Metal shaders for SwiftUI, erişim tarihi Şubat 10, 2026, [https://medium.com/@victorbaro/metalgraph-a-new-way-of-working-with-metal-shaders-for-swiftui-bed1cf1a2b81](https://medium.com/@victorbaro/metalgraph-a-new-way-of-working-with-metal-shaders-for-swiftui-bed1cf1a2b81)  
23. The Meaning, Maths, and Physics of SwiftUI Spring Animation: Amos, erişim tarihi Şubat 10, 2026, [https://medium.com/@amosgyamfi/the-meaning-maths-and-physics-of-swiftui-spring-animation-amos-gyamfis-manifesto-0044755da208](https://medium.com/@amosgyamfi/the-meaning-maths-and-physics-of-swiftui-spring-animation-amos-gyamfis-manifesto-0044755da208)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABYAAAAYCAYAAAD+vg1LAAAA90lEQVR4XmNgGAX0BruA+D+RmCyAT7MUA245vICZAaLxIroEEiDL4BIGiEY/NPECJDZZBn9kwNToBcRxSHxzJDbRABa+lkDsCMRlUD5FABa+94G4DYinAPETqBhFoJwBYogHmvhdJLYwEDMi8Q2B+BQSHyv4zIDpOlYGSBjDwE8kdh0QT2UgwmB86RcERIF4H5pYIwMBg9kYIIaeRpdAAiB5FjQxggZPYMCefkEggAEihxwMMAAyGKtjVgHxHyD+x4AICmQMEv8NxN+B2ACqBxmADD6LLkgNADL4HLogNQDI4AvogpSCr0D8DojfMECKAvSIHQU0BAD4/EhBrQEE0gAAAABJRU5ErkJggg==>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABYAAAAYCAYAAAD+vg1LAAABD0lEQVR4XmNgGAX0BruA+D+RmCyAT7MUA245vICZAaLxIroEEiDL4BIGiEY/NPECJDZZBn9kwNToBcRxSHxzJDbRABa+lkDsCMRlUD5FABa+94G4DYinAPETqBhFoJwBYogHmvhdJLYwEDNC2fEMEPXfgFgZrgIL+MyA6TpWBkgYw8BPKG0HxDJQNjsDRB9ILVYAC19cQBSI90HZ8xhQ1YLYPUh8OGBjgEieRpdAAiB5FnRBKADJ+aALgsAEBogkevoFgQAGiBwsGNBBKhB/QBdcBcR/gPgfAyIokDFI/DcQfwdiA6geZMADxE/RBakBziGxQWmeKgCUSxOAOAmIS4HYGkWWTLCJATPYRgEdAQBmF0y/ZWKpjwAAAABJRU5ErkJggg==>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAYCAYAAAD6S912AAAAzUlEQVR4XmNgGAXUBhOA+CMQ/4fi70D8Dk1sFVw1CQCmGR3IM0DEd6FLEAIgTcfRBaEAl2U4QQQDRIM7ugQQcDKQYeA1Btwa1jNA5ALQJfABXC5wZICIT0SXIARgBn4A4vdA/APKvwzEwkjqiAKw8EtCl8ACpID4L7ogOrjJgN276KALiFMZiFCLK/ywAViY4gUgBXfQBXEAggZWM0AUpKNL4AA4DZwMxJ8ZIDEKyrdfgfgfigrsAKeB5ILBbSCsWHvDAMkALqjSo4ASAAD/dD/EHwDTBQAAAABJRU5ErkJggg==>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAYCAYAAAD6S912AAAA9klEQVR4XmNgGAXUBhOA+CMQ/4fi70D8Dk1sFVw1CQCmGR3IM0DEd6FLEAIgTcfRBaEAl2U4QQQDRIM7ugQQcDKQYeA1Btwa1jNA5ALQJfABXC5wZICIT0SXIARgBn4A4vdA/APKvwzEwkjqiAKw8EtCl0ADFkD8F4j/ALEDqhQquMmA3bvIQBCIg5H4IPW6SHwUgCv8kEEcA6oaUOI/g8RHASCFd9AFCQCQnh50QRCoZoBIpqNL4AFaDFh8NBmIPzNAYhSUb78C8T8UFbjBL3QBSsBbJPY6JDZZAOSjBCBOBOI8BkhwkQ2KGBCpAYZxJptRQDoAAKd4RNxDX5NwAAAAAElFTkSuQmCC>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEoAAAAYCAYAAABdlmuNAAAC90lEQVR4Xu2YTcgNURjHHx+hhNh4FxYIZYNSsrCTiJWUiHxFlLKwQhJiZ/EqCzYkX1lgZ6EsJFFSWKBIlFC+vyL5ev7OOe997n/OnJm5d255dX/1rzv/5znPmZkzZ86ZK9Kly7/EEjb6McvYqEqPahybyhnVHDb7MRNVd9gsw3HVb6+tFFuoukReYILqtTTa/lS9V73zv+G96Muuh5fSqA19VL1RfTNebLCZg6ojbJZhqrhOBpMPr4hnkp8XTr5O1ourOZ8Dygcp31/ZvCbOSrbhDtVt8mKkbkYq1ioPJb/mBXGxVRyIcEJamIIo/iXizSYvBvKus+npxI1K1fwuLjaDAxFGSX6dJg6o9vrfaLDTxIJXxFJxebFpMF1c7CYH2qTOgUHuSDYD28XdeTBZGsWH9mW4l3iZDu9JPG+4OP8xB9okDMw8DijPVb9UAzmQALVwPzJsEBccZry73rPsiXgxwk3GS/StuOmL40+qRSavLsLAoB/0h37COewzeWVBO6z6GRDgJRveV/LClqEI5DxlMwJG+T6bLRBuShHnxOU9Ug2imAXXfYPNBeIabyQf3m7yjnk/xXJxOWs5QBxVzZXiemUoMzCXze91ku4XT+YtNk9LttEk79mpCLZ5PwVGqyjHUiU3xkpxNVZzgECOfUpwPMIcWxA7z+YhH7CcNN4p4y82fh6IF+VYUrm72IjwRNI1YmDKp9oghv1iE2ElCuBD114sF+Rjy2hxcX7fpcirFzaJFzlAVB0YgFU39amCeriWDOFdAW32HpZUHI8JSR54M8kbr/os7nsO31hYdX6oZpmcPPIuEv2+kvw43iP4hkR/WF2xtclMlwjYnfeyaeAHp2UwwtfYbIOik8JNqAtsdjf530OkeY8YOCxudayFoourQqrWFNUKNlsETyieuDXiPqDzpnTqfCqDTRw+mNsBexVMVfwlg03ilebwXzD96yK8WqwYLB772WyXq6ppbNbMADY6yFjVAzbrIsz3/4EtbHTp0jn+AIcD4MbqN2wVAAAAAElFTkSuQmCC>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAsAAAAXCAYAAADduLXGAAAAoElEQVR4XmNgGJSAEYhV0QWxgadA/B+KiQJXGEhQDFJ4DV0QFwApjkAXxAaiGDCd0ATE/mhiYHCTAaGYC4jvAzEfEH+Dq0ACIIW3gVgQiDdCxX5CxTEASHAnEM9El0AHMxgQJsyGslUQ0qgAPTJA7INQdj6SOBiAJKeh8VuQ2HDACRUQRRL7CMQbgLgHiA2RxMHAE10ACDyAmANdcBTAAACQdCSKrBERiwAAAABJRU5ErkJggg==>

[image7]: <data:image/png;base64,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>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAG8AAAAYCAYAAAD04qMZAAAD2UlEQVR4Xu2ZWchNURTHlyFEiBLKg7mQoUgevCHihUhkFiHlwROSKTwpRDIUyZQylAdKeZBESYYHFIkImcfIvP/fOvve7X/32Xffe+7n67vdX62657/WHs4+e74iNWrUaHxMZqERM42FaqCLsW4sGo4ZG8liI6ansVssNjDNjfVnMYaDxv4ktpx8442dJ83Sw9hryaf9Zey9sXfJb2jPc9GV4YXk84Z9NPbG2DdH83VAZruxPSw2EC8lX/ey6CeaGD3AJSbDp5Iel6lSKSwQzXMsOwwfJL682Lj/wW/JUJ/jUph4lbGbpPkIfaCQr1zuS3qep0V9s9nh4ZDUz/Q5ioUIUOddLMaCxF882gjSfCDuCosJ9fHxQnl+F/UNYYeH9pKeTzmsFs1vNDuK0FU0HfYc0WwxtiH5jcQo3CXmxaaKxvmmsMGivmvsyEglOwti27FYIvuN/TQ2kB2R7JXCOm81Noy0OlaK9lDQR/Iv3DIXoRsVztDHHfHHtRHVH7IjI7azjGGH4Zno2tGUHQGQF9qjHLCR+yQ6crLgdrhexi6K7ogL2nVhIrZytNuJ5rLeo/mwBWOj8FZ06sUzXmqCE1cpbGdBOSgP5dg6bHTiYkE67LZjaSbaXtikoYNWAtRhn+hUbzuS+0FzQODtO7SvpNnjQzEQ85hFDxgNd1ksA+9LeTgpGvdAtMHTwHtfZdFDa9EPhg1cKL9SsevdCWPzyPcP40QDF5EObR1pBxI9xHTRmGChomsCdmDF8oshprNccH7Pl3C5GMHXWfTQUfQMe44dGdktWj973MKzl6NS+CK9E82dRsGKRA+BXl0sxqWUWB8zRfOYww4CMe5ownNb59kFvlMsBrAj8IaUtramgfJtuyBv/J6Sd+fZKYUNeNjRjjj6JEdPwy04hlDsGhY8PJJwHj7QwKE08OE8WyrIFyP2iWijlwvKd893eF7i/M5hd4AWXDa7H4Bfkp9dOoj6ef0MkZafPVifZQfh1jUW7HZD12DID++ShTOiG7bO7CgCjigo302H5wHGOhnb7Oh12LUHtjTR7NUM5nUXaENJ627ss+j9Je4UsdvDGWe4E5NGWsOj3FeS7se6hPUG5aGRcMyJmepwy7KNRQfuzFnZYeyH6FVjDBOlsPy1iZb5iIWRcJnFDHBFGXyYSoELgsXJ7xby7xnWgs0BdqWVZhYLDUWxBi+FUF59jc1gsUwwkjEy54peYqdNx6H6VAU4+OLSOgs4S2Gaxd9HOFjjBoHB1F0p7LLgGoMN0iYWq5FLxgaxWGGasFCPYINwj8Vqxq4f1cAyFmrUqFGjkL8WVxmFPWjOCgAAAABJRU5ErkJggg==>

[image9]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAYCAYAAADDLGwtAAAAa0lEQVR4XmNgGHrgIhB/B+L/SPg9igo0AFOEF7AwQBSdR5dAB2UMEIXe6BLo4BMDEdaCAEnuO40ugQ4qGCAKfdAl0AF13cfMAFF0AV0CHUxggCiMQpeAgWsMELe9A+K3QPwBiP+gqBgFhAAASvkf/u64jGAAAAAASUVORK5CYII=>

[image10]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAsAAAAZCAYAAADnstS2AAAAhUlEQVR4XmNgGPrgPxA/AGIWNHGcAKQBhIkCExggijnQJXABkOKN6IK4AElOyWCAKFZGl8AFQIpvoQtiA+IMJDjlOhDfZYAoxhvmD4B4JRAzM0AUL0ORRQIvGVDdidMpH4D4O5pYIQNEsRSy4GeoIDYAEr8E48hABUBuxAb2MOA2aBQQBwC0ciJVn07c0AAAAABJRU5ErkJggg==>

[image11]: <data:image/png;base64,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>

[image12]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA4AAAAYCAYAAADKx8xXAAAAmElEQVR4XmNgGDlgMxD/JwHDAYgThiwAFUNRBAQayGJCDBAbkQETA0TBBTRxEHgEY2wFYkYkCRAoYIBo9EcTZwPiPhgnH0kCBt4zYDoTBASAWBxdEBlg8x9BwMwA0XQGXYIQKGeAaPRGlyAEPjOQ4UwQIMt/oOAmy3+zGSAaE9DEsYIgIP7GAIm7t1AM8ucvBjKcPAoGBAAAiastbKanIo0AAAAASUVORK5CYII=>

[image13]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAsAAAAYCAYAAAAs7gcTAAAAgElEQVR4XmNgGAX0BrOAOBldEAiM0QV+ATEzEP8HYick8SyoGBwsZIAoBAGQhANCiuEDVAwOaqF0N7oElL8ATQwMQBLPkfgwZ6khicEBSCIQiV8IFcMA4gyYEu+QxF4hS4AASEIPytaA8h9C+Q+gNBxkMEAUgHAFEHMh8UcBZQAA5YcfBjiyd3MAAAAASUVORK5CYII=>

[image14]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACQAAAAYCAYAAACSuF9OAAAB0ElEQVR4Xu2VzysFURTHj98iGxYkQiwsSFEiJCULRSilLCh/glj5A6xlaylLIT8XsrKTjWJJCgklieTXOe6d9+77OvNmmsfufepbM59z7p2Z+96dIUrzfzShCEkfiiAmOV+cfc5gYilGM2cLJVPAKUYJ5HIeUfoxyhmxx3dkbgzJ4byjtBRxnsiMy4CayzDnCKXGIqcLJfDBaUHpkE3mhpawAEhPKUqkjvRV8Sik5HUP6Qnqm+K8oNSQiY5RWk44OygV5sjMU4IFIOimf1gj09iLBfL3GtJ7iBKQnn6UHp1kGmQ7+y255vx4o+B+6dlFKVRT4mBvlVyyFJeMcTL9rVhwOONcoBRk4Lxz3mFdmeNqrAtDOcVX+RZqLtukzNmgyArFVSlOo5ZMn7yHruyxH5uk1BcUOas4QXMujWR6vN3lnU/EOhI55TygnKHfF7rkrIATsM+ljUy9Hbw4eZlqvHL2UAoyKN8ey9P5XVh8N0qK79BpLJDPz2IRP4RSyOTckGm4h5rLOWcDJfPJWUdpySMz7yoWyP9GQyNbOOVJLGOca5RRkNWoRxkBeTD3tRKZSjJ/xlTo4RygTIUBzjLKkMj/9RnlXxD2I4vIJyVNZL4BKSxtxok0FP4AAAAASUVORK5CYII=>

[image15]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFwAAAAYCAYAAAB3JpoiAAADQUlEQVR4Xu2YWahNURjHP7MURaYM3VPmPCje5OF4UYjwpJRMZSjpluTJkJIhZS4vbuY8UB4Q0vUo5U14kMg8liJDpu9vrXXvOv+99rb3Pvtc5+b86uuc9Vt7f9/ea++99iDSoEGDjmcsi07CDBadgV8sEhip0Y9lDUhbp6fGB5a14K3GXZY5eKUxiGWAB2IODGIy9RVJnjrzNW6zLBq3UdWwWOM1ywRWS/U105CnDpYfwrJIemt0ZZkRbORQlgngasg6EHnIU2e5xmeW9cQwyb5TWP4ayxqQt07s/izQ2Khx1LZ7aTRrbNbo4RZSNohZZrTnwEKNTRonPReXc7+YGwtzXOMbS6K7xiGN9baNHZrW3l0YRdXBerNYAiR+JmYBDNRa67db16TRat146+baNthinX9E/5YTO+XzQ+MUOZ8LYi5tUJZovaIosg5OoCssHThrkfgsebifAfeeXIv1Pkk5cbWw20bOgQPBuXGA2FVL0XXuazxm6SiJSdxEHu5wwPFG4BJkV7IulHNHwC0l50DfmYBrJQfWSMxlnIK0dc5Zj0fGbtTnc1miY9LGCDGdg8nD7Qo4ToS5mV1Szp0Bt4QcwIFB3zjycGWvjTl2pfV5Bjxtneve/2US3Wefi5LQP1xM5wDycYPDifYFXFLO0EHcSg48l2jeFQHnyDvgaeugfZPafb22zz2JTr1tlMSsPJB83ODwhhwIuJJ1oZy7A+4EOXBHonmfeg7/fZIGfKbGRJaWrHUA3jt4HZ8vGldZOqaIWXkCebhjAceFMPexS8rZQu60mA1kpkpl3j22/c6233h9AH2zyYEuEt5uR9Y64KHGEZYeWH8eS4AdxSX1xP5+1Tio8dI6HF18kMEHHLx6O4fvJ+CjmPXg0D9K0ud0lCR+MPCI6QarrNHHazNwc1ha8Mj3iKVHljr4DLGXJRFar67ABvZnmRHk8N8RmFsscjBJY5X9j5c4vNQxeBl8wbLeWCfm7K+G2MvYUu1ZhweA82KeqHBTvVTR2w7qZPku9M/4LvF3/SQwB2OKwpyL+FTZ/QfcwPgGnhU3xfjBTNe4wbKeCe1EEYxhUQPw5BI62HUNnig6YnBqwSIWDRr8X/wGLvgVyjsS3BsAAAAASUVORK5CYII=>

[image16]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAVCAYAAAB/sn/zAAAAlklEQVR4XmNgGDSAEYhV0QXRwTsg/g/FBMFlBiIVghRdRBfEBkAK/dEF0UEQA8JakOJVQByNkEYAkJUghX+AWBMqBuIvg6tAEkT3yF90MUGogDiyIFSsDlmgFyqIDBywiIHdhS74HkksFSYIEpgK4yCJdUDZ/0AEG1RQCKYCCkBi4UC8A4jlYIKBcGlUEALErOiCgxUAAJ8CJP/eKsEEAAAAAElFTkSuQmCC>

[image17]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADcAAAAYCAYAAABeIWWlAAACG0lEQVR4Xu2WT4iNYRTGj1LkP/kbGzJJlkMhysTCgtVsx1gIi2FjpywmTdmISDMWmhoxspG9DYWFxpCpGTulRMnUhJT/z9N7Xt9zz3c3ZnP7bt9Tv+45z3nvd7/zfu8995rVqlVJrQUboll1jYA/zplQawtttdTc3FhoB9211Fxbio19jWaVdRGc95jNnZNaZXUWfPe4w4phMu/fiorquKVG5ov3yr3Ki028b+J9C14rtUjiBeAx+C1eUx201MjJ4NPrD16rtNTKjVwB14JX0qiVj99m9/SYtlKXLTWjYrMrg1cSu4/N3RLvthagD+AmeOn5CTAGtoNxcAdMgsW+Zhp0+tos3ugTMAP2iL8XvAPPwLB7ebARfnYW8+vgBvgofoMWWmNz3Z5nT2v8Ud8U/HvglBWTNtd6PN4FXkttCnRJnq9zDDwMPjcox6rlwWO8RPIG7beioT73+NiZr8iLrHiicae427sl1w/mk8+/latCjWq2iTnfBpZZ+ft2CQxJHt87K80BWywdP21QL86n8lZyrQ2C55LvtFRf7a+qnLORq1qAfoE1Hq8DP6Q2Kz21dASpjVb8i6H0xh6Box5zM3LtCDgEJjynfoL1Hus17oMLHudGOP65GZSufQBOgwHx/lscx18s7Ty/xFkHLE2zrLiLn60YPhRv/IWlQcMjl9Vrae0nsE/8w5YGVr94byTmEOL1dohXq1atFugv5L6HHyau9AUAAAAASUVORK5CYII=>

[image18]: <data:image/png;base64,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>

[image19]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAWCAYAAAD9091gAAAAhElEQVR4XmNgGBCQAMT/gXgfEPuhSjEwhAJxEJT9hgGiEAVMAWJbdEFkoMKARRc6ACk4jy6IDDYyQBS5oEvYQCX0oTSKVQpoAjBT4ADE6UDiW0PFJEAcHSgHGcggi01C5kBBGbJYKTIHCh4D8XJkAZACDihbGMpHAUxA/AIq8RZNbvADADZuIP2ZmlALAAAAAElFTkSuQmCC>

[image20]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAYCAYAAADDLGwtAAAAm0lEQVR4XmNgGNRAAohl0AWRwUIg/g/FRWhyGECTAaKQBV0CHaxkgCgkCECKvqILwkAPEDdB2SCFNUhyYFAJxL+gbFUGhEfY4SqAIBUqyIEkdgkqhgJAAs+xiH1HFvCACqYjC0LFGpAFlkEFkYEKVAzZKQxToILIYAmS2FKYIDeSIAgEQ/kwMRRDnKECIJwNFfsH5QvBFI0CnAAAenEoOjLVGH8AAAAASUVORK5CYII=>

[image21]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAwAAAAXCAYAAAA/ZK6/AAAAlUlEQVR4XmNgGAWDCegC8Twg5obyeYG4AYgnADETVAwO2IF4KxBHA/F/IG4G4gVQuXqoGArYC6VhGhqR5EA2YWgohdLXGDAls7GIwQFIoh2L2GU0MTCQYIBIgpwAA3xQMQUofypCCsJBtxpZrBqIlZDkGP4C8VdkASAoYIBo0AfiS2hyDBZAzIouyACJHwN0wVFACAAA3qgdBAlcrcAAAAAASUVORK5CYII=>

[image22]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAXCAYAAAAyet74AAAAn0lEQVR4XmNgGHQgDYgL0AWRAQcQ/wdicSC2AeKfqNIIAFJkhcZnR+KDwRYg/o0mBlLoiiwgDBUMRBaEihUhC2yDCiIDFaiYO7IgSOAvEDNB+YxAPA0qDgcsUIF7QHwACYPEUBQmQQXkkQWhYteRBZZCBZHBIixiDNlYBEF8kE0oAGQlssI+IP6GxEcBX4E4BIiroGy8wBmIRdEFRzYAABkLJxqYpSHRAAAAAElFTkSuQmCC>

[image23]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAA8CAYAAADbhOb7AAAE1UlEQVR4Xu3dW6hmYxgA4I8ZBjlOOSSHyURIDik55JxjIU0TUVNKmhzupZiQkgupKblw40oTUtzIILniRjk1CqG4MMghZ+PwvbPWsr/9zr+3Mfb+/7/289Tb/73vt/Z/mLl5+9Za3yoFAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJg+u9c4IRcX2V+50NhYY3mTr2nGAABT4egyviblm9I1T8/liUV0ZI2Dc7G6uMbvpWsgc0P3Z8oBACbmqNI1K+Nq2EJ8XruitdhyMzb4pRnnY9bW+CnVAAAmIhqVr8r4G7ZxebLG87lYvVvjtCYf9Z1G1QAAxmpd/zpXw3ZRjctqXFHjyj4i363GihpPzRxaTqzxROlW7EbZUOORGreW+Ruhe2p8UuOxVI/PfKjGi6X7Dq39amyq8UyNU9NcfNbeqXZGX2/lPLyfCwAA4/Z9/5obtmjGooGZK26rsa0/9scaW2rcVOOwfj77oXRN08oy8x6jRP32fhzXkLXHtY3XyzVObuZ+bsZvNOMw6rPeK7Prh6d8cFeNs3IRAGBcvijdqlXIDVs0Lwf04zhuqLWu7V+jHg3PIB8XF/VHDGL+lSYf3Fjj2yaP68uiGQyxenZdMxfaz/mwGWf5+4So/VHj1T7i94867vrSNaIAAGO3f+nujBzkhm3weo3jauxVY2uaC4/WeKDJTymzG59Y7cqNUOSxgpdF/YZc7OX3CFGLU6TDeIjH/zliZq4VTWrU1je1yOPu1Sy2HsmnZgEAxiJWsqJJ+a3Gr/04VsFi3BqanWjmRjU0Mb9vk7/d1wZDE9XK+SDql+dib9TfRO2lJr+7r+Vjc35sX2ubxshPavLBpaW7pg4AYOKiYckrbLES9VY/vr/s2PiEXIs8mpwHy8x1YZub+ZtrvNaPj2nqYUONz1Pt3v41To2e3k6U7r1j5S+c2dQPKd21Z4P8HUNbi992fpO37qxxdi4CAExCNDC3pNoLNc7rx3F9WRyzx8z09gYvN0NDPmw6G3d0DrXj+/Edpduod5SYH65VW1bju368T5m9kW2cOn26ydubDqJ5azfJjffcs8lDrCTG6c44NZx/Q+udXAAAlqZLSrdBazQO8zUP4xbbdLRia4/WgTVWp1rcqBBbf2TXNONzaxzU5NmhZe5VrVU1LszFXjRfQ4PZihsSYruPLH5fNIXzmab/DwBggtqm4M1mzMKI1bldabyiQR22PQEAlrhPa1yQiyyoz3JhJ0STtyoXAYCladSDx1l4/+XfOJ7wAAAwSzQTw92TLI646zW29NgZ8fgsAIDt4tmbw/YW0bTN9xikD2p8vBMRW1EAALAAYk+y9jRdjDc2+WKJzxG7FgDAEhMNQOxv1ubrmhwAgAlaWXZcsYm8fb5ndl/pnp35b3HV8AcAAPw/uWFrd/IHAGAKxI7/8fD1eERSPHgdAIApdXUuLEEPl27FcXmeAABgekSzlk8TAwAwZaJhW5uLAABMD/udAQBMufVFwwYAMPU0bAAAU2xLjY9qbM0TAABM3uoam2osK1bZAACmztc1vmzyaNg2NzkAABN0TtnxsVzbilU2AICpcEQZ3ZitKF392TwBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMCE/A2bBUdZh1/kxQAAAABJRU5ErkJggg==>

[image24]: <data:image/png;base64,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>

[image25]: <data:image/png;base64,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>

[image26]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAAXCAYAAADQpsWBAAAAcElEQVR4XmNgGFngDRD/AeL/UPwPiKejqMADYJpIAiANF9EF8YEgBoimAHQJfOASA5lOI0vTBXRBfIAs/4DiBa/T3jFgKgDxf6OJoQB0D6+E8lWQxDAASIEslA3yA4ifg5DGDfqB+BQQt6BLjAJqAgCHrCCMyGtx2QAAAABJRU5ErkJggg==>

[image27]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAJ8AAAAYCAYAAADkri+AAAAFKUlEQVR4Xu2aV4glRRSGj2IWc0TFXTFnQcXsLooJEyoG9GUxPog5i2FFMCtmEcOYRUQRMb2Iq6IYQFBREcQHM2ZFUTGej6rjnHu6+u6dvTNOj1sf/EzXf6rrVtetrnRHpFKpVCqVSmVorlHtGc3KhHGs6uRodpmvVe9Gc0h2Vf2uWkD1jOrW3vB8zWOqX6M5JIup/latotpR9VtvuLtQaTReLC695a0W0vM71t6LxMAQUN72Ib2oS3cW3poFozkEf6pucOmVpHa+yIrRGIInJM0yHtp7t+D977lQmh1tv4JXGR9WkNS2BwQf79Tg9WVT1Z2qJXN6KdVs1bUy/MjEwv9T1fWqvVTTsn+Y6gLVfTkNB6rOllQXYPg+RdK9c5sqeOi/gkfZXex8PNfDqm2cd7TqbtWazpsXTlJ9oHpEtYWk7xB2UZ2uui2nYQPViaobVTtl72DVA6rNLFMLT0mzbdfJ3h7Bb4WGeFJ1hKQbL1bdlWOl0WQsxHtJb5ivZ+e0z0Pj0FHx6IgnZP+S7C2U0yWIX+nSvDRMw7EOXeCP/Je6bSeps/Bsq2ZvrRwfK9+pNnHpV1UP5Wt2ox9Lb3vMUD2eveNUL2Z/3ezREdsgTvva4MQG7+bsD8yz+a91votcjBFwTIU5NpbmvYxi1vlgRJp57O2xRjPwzgyecZqk+Jwga6B5hee/t0X3SBqpeAZG6tuld1RpgxHGpirq95mLmXde8AaFe5cInm/HadJsb8CLPumfg2fwohD/UJrtHcvpyxn5L0ce8cbjCx7Q29+LZgGrDF9SaRi/SZrlT88eDeXBuyx4xkfSLGfz7B0afJYB8Qv6L2EdCodIs86MHnhbBv/17L8U/Ii193OqvUMM2jZgeCMFr5QXjpT278j3C74vvG9USzu/AZleDt4P2ffwlnOWFv0SNKI9BIqjEGu5WM4a2Vs5+HiXB88oNdSbwTtGRkf3yex8RullP6fgcRZqMNrG3aVnYUnrXt/m67n48tmL4DFlRq+UF0qDBqM5HsdbcL6MLpPWz7FWCMZfBPBokBJ9C5P0FiNjlqR75jjvuux5Vs8eDeXBuyJ4BjH/JZl3afAAf9DOx3qYzxyLBoV6vFLweOGjZyO+jYxt+NHFRn6ff7mQNvD4LqJXygusrWOMen/r0kzJtrYF8u/j0v/C1BQLY7FpHh2BHZEn5o/MkPQLg4cH/MWlOZOL5UzPXjyPwvMbCg/T0lsuzaYp7nwNyhm0800k1CPuCvF2z9elXwq2lmZ7eWKM2cN7djwSwSt9v6W8wJTuY20jqoc4n9/gbWnezAGieV/4QCbmj8yUlMeOb+BpSR3DeFCa5dhU7TcmgDcSPIPdoZXD2891WweLdZoMDpLmc2/lvLNUG7mYwZR7eDQd3L+vS28rvaORTX9x/YVX2uDFOnp8jOv9XTpyv+qNaBoMj/6XAWD9YBVYNsSgX8VgpqRpz9ZeyE+DP0na6X2i+lK1tqTfHfE4EuAvbz9vJJ0fj7xxWjIelfQZHDf0O5skD7vYyeQWKT/HV5LqFzdJcIeks9F+sPG6Skbb+zUXo+N+LqkdaU/Wj1fna2vb7yVtSqiHeVyXoLPxGcwwHM20wdHPC9Eclrl1vq5CveOb33XYXTKKwQ4+0HGWkXTSYezsrodiKne+0kjeVZiO2XDMkrRjf78n2l3YHL0jqd5HSTrZ6DcjDQQbBqY2dpesJ57vDXeWcyVNK9Sbc6fx/teiicKmUK+pwI8yNetdqVQqlUqlUhlH/gGoWH+0A+ZaHQAAAABJRU5ErkJggg==>

[image28]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACYAAAAYCAYAAACWTY9zAAABw0lEQVR4Xu2VPShGURjHH4SQj2w2MshglFkUsxJlUTJIRoUFWZGwKdlslLBIFhlMSsnCYJDBYmLw9TzOOTz+99yP7r1M76+eXvf3f5xz7nvuew9Rgf+njKseZQIauIpR5skrCksrCg8fKPLijcLveo/MxF0YKOTbfkeZlU0yk0chC4ub+IxrCWUWkmzDPsX3lVB8T2L6KdlgFWT6ljEApKcbpdBGZmuq7HU11xzXCvmfoTuuU5QhyKRxN3HNdY6ynOuAa4jMAAtcWzabtQ4RN4oyhEUy/ZUYKGbIM8+x/XQLm1eZfHOBfyDjon5tiPQfolQMkmeeSft5RcFw3OMEcU0oQ3Bb6RvH0UERuQTy09U8WY+Ia0TpQfraucbs3y2/42+kxzfPFxL0etw0OEF8J0pFEZmeCeXk+lZdawYoZGG+QL8S5CxcV5n4EXWtce+lHfCP1vuYopDskoKBfjk+6IC55zoBJ7hF3WBAP9vVhwGZ+S9QCnIQr4ErJTOQVB1kw9YjG1wvKBXPZM5XRMbqQZkW38LS4J7H3Njl2kaZgiOuVZRZyXqnctz5tjYzcpzJc5OWP1mUo4arFmUCmsncWIFc+ASlRm0lgdd/uwAAAABJRU5ErkJggg==>

[image29]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAXCAYAAAAC9s/ZAAAAo0lEQVR4XmNgGAUgwAjEH4D4PxJ+i6ICAv4yIORBbAwwnwEi6YAmjgxA8jhBAgNEQTWaOAxsBGJjdEFkoMwAMWAbugQQcAHxM3RBbABkwEd0QSD4hS6AC8ACCRkkA3ENmhhOgM0AdD5egG7ANSAWReITBLcYIAYwA/FOINZBlSYM5jFADPAD4ntockSBBAZMb5AEFBkgmtPRJUgBp9EFRsFgBwCn7iceXggXuAAAAABJRU5ErkJggg==>

[image30]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABIAAAAYCAYAAAD3Va0xAAAA3UlEQVR4XmNgGAWkgnlA/BmI/0PxAhRZCPjLgJAHYWdUaVSArBAb2AfEKuiC6IARiLcD8XoGiEFBqNJggMsCFJAPxCZQNi5X/UEXwAbeIrE/MEAM4kMSUwPiTiQ+ToDsAlA4gPg3kcSWATEPEh8rAIXPZjQxdO9h8yoGQA4fZDGQ5m4o/xeSHE7wDl0ACmCu0gbiFjQ5rACXs3czQOTuATEnmhwGYAHiveiCUMDEgBlWWAEzEL8B4pPoEkjgGxB/RxdEBquA+CMDJP2A0g0oL2ED+kCcjS44CkYBEAAABi803bhnVOIAAAAASUVORK5CYII=>

[image31]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAZCAYAAAAIcL+IAAAAkElEQVR4XmNgGAUDAn4C8ScgPgTlPwXiE0D8H4hPwxRFAbEBEFtDJf7BJIBAGSoGBn+g9CKoICNMAgg0oWJgUAul7yELQkEaFjGwwDE0MZBbsSr0wCK2B1kgAiqIDkBiNsgCl6GCyCAJixjY55PRxB4yYFGIDYAU7UQXxAZACs3QBdEBLs9hgBIgvoEuOEAAAG2eJv3BYhASAAAAAElFTkSuQmCC>

[image32]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFoAAAAYCAYAAAB6OOplAAACS0lEQVR4Xu2XOWhVQRSGjxZaiEtlIaYxFqIpFBcQBAtxabSyUBBCFIQ0FiFg4Y5FRBAEGyUqilbaKGLhAoJbI9gY0SAEFETEJhCXQsX8f+ZcOe+8uY8neXcR5oOfufOfO8x5c+fNuVckkUgkEjXhFvQbug71uFiiQ7yGFkLzoT+qRAGkhS0JHhej3kx0npkSdvVuHyAroQvQHO3PhY5DZyUMrDMD0FHTXw5dhA4br2yys3mGNWdBT6CdGjwJXdHYMfXqyn5oMzQCfYPeQH0a+wz90OuyOAd9gRZLWLdxG3ykbb+E4AkT487u5EJfa6GrEh7wZegSNAwtnRqVT5YbF5XXi0zsjHplMSSND7bpjeOItmM+IGHHWK8LOq8eWy7KB+ituadMerVlPk9tAHxUPw/+k9e0qdU6Jo/sXF5gvAfqNUHzufNiya6NeOyz2lYF598S8fhj82A92tGmtuuYPG5K85qwTnhvCprbIt5D592GnjmP97VTfE7/o1aEYS1hdY/9IHobvFkQnOuT875K+Lc3sEvaT5YeC1AGi+dL0y8bHls+930Rr0i4qC+cx/mXOU9eacCyN+IRejckfM/zursxXDrM4bHzuJNiuRcFz3A730Honen/5ZeEVxPLe2lOdpXzZrt+FXD+JRHvvvOKht8iPyXMfdfFWsIB95x3RxoL5kapfqFjMKf13qwrTHZdxNtq+jxCsoU+Zfwq2SP1fPhRfHHcBH2HJrTtVX+ehPsOSdjddSBWHGvLoFT3ETJd+Jp1wJuJRCLxHzIJ+9ifbkyt30gAAAAASUVORK5CYII=>

[image33]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADkAAAAYCAYAAABA6FUWAAABY0lEQVR4Xu2TQSsFURiGTxZSyEL5B3YWkpRSFkp+gIW1hWJFWd2SK7GwUkopIv6ALSlJWbBkYaUs/AA7JLzfmW/y3W/mzJy7OXdunaee5nzvOVPvzDTGRCKRSCQSKWMYHsBunnthHe7CDs6qilf3TngLZ+Ev3IQnvLfOWVXx7n7N10UON9INk7yVooccFOsesXZRh2cOT01S8BgewUO4QjcV4N19ja8vMmQWcrJ++Am34IBJzizBL3koEM12t8Gdyt44T5mE32JOeYDbOgyIT3cLBTM52RWv6QtmbmJq5v/HL4Le7k4TLie3lVLW3TLHoYayCV6/w3uxJxnSQUB8ulseOZTMq4zW42KuCj7dLfSf7ans1WQfUjLC2Q9fpxq3g+HT3QkdulBzl5hTKO/TYYvR3Z3QwTExX8InMRPTxvONBUZ3z8X1M++bJD+HH3AU3jScaD2u7hlW4bMO24R27h6J/AGTCm40sNCCyQAAAABJRU5ErkJggg==>

[image34]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFsAAAAYCAYAAACV+oFbAAACeUlEQVR4Xu2XT4iNURjG3xiEFJPF2JCFMKJZSGrM3ko0wsbGgmxlIRKSSKNmsmCQixlCibKhlIWiZGdjpSxkQ0Q2ZsTzOOcz577nveObc293PnV+9fTd8zvfvefcc7/z54pkMplMpoLMQ34g75HDyMz66kwr+eCvHOhfyIWgLtNiPmuRsTmlRQJ8mru1zMSc0SKBEXEDbtKDDCPzfXkBchwZRGZ4V2VGka1BeQdyG9kYuLIMaJHAInGD/UlXzEaeIdvF3XASuebrjnlXZcb8lf3sR74gC5G53u3y9WU5p8UU+SjuIX0prv1NYeVTf90vrvJEUMcnvJWDzc/jFLNyA7mO1JCryBXksntbQ3jEKnZ69nM8qCvcE+X+RTODzfZ3+9c87rH9WxPVIkf99a3EA7tXuSXivhzdRWRI3Czg07Vs4ra2sQ7pQJaK6xMHP4TukHIh641wSdKuyGRY6zTLb5T7AyueK8dDuf4AfkHtbhqunVySuP0V3nGZbMQWIw8MV2Qy2JaeiXScpRGs2Gw4PQ3vIo+U40bwSjmLOcjZKaYM7GexdhfwCdU/QBlSlxG2tdJw/NHr4CZidYyuboH3Ltzla8iLoDwdsE+nDfdduTI0M9jFaY6s8i7itcQVewxH6HjM4rTahnxDVtfd0V4Wi+sTTx8hdEeUK0PqYHPPuxOUOdPWBuW/cBc9r9w7iQe723BdhmsnOyVuf7l3s5QvQ+pgk/vi2mX436U0fMNj5e5JvIavkfjLTjc1Se9TM4OdDDu7wXB9QZn/Lun2Ba4KsE9ftawqesPsRX56V4Tlh0hncF9VYP8OaFlVDkqDw/h/QuoSkslkMlXmNxbRoM57JUk7AAAAAElFTkSuQmCC>

[image35]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAAuCAYAAACVmkVrAAAGh0lEQVR4Xu3da8hlUxzH8b874xa5M2ZKiCgpQsgLQkLGC4QaeeX2Aikh5RJyp4SUKW/kBcqlJJchEkXulNtICTFhcr+uX3svz//8z9r7PI/n7H2eZ57vp/7N3v+1z9l7rTnTWq219x4zAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABOzVcM2AAAA5oh/6lgZ8gAA9GaPmGiwLCYWsA1TbB2T88SpMdFg3ZhYAJraRoM1AADG4olpRPR7TNQeTrEmxachP4mOK9ahFH26NMVlMVnbJiY6FNsgxl5Thw55KiYcDdT+jMna5jExj11jVT1/DvnSb1y521IckeLIwSIAAGZmkxT7W9W57Jpiszp2qXOxI3o9xdkhJxp03Fdv/5biGFd2UIpt3X4fFqU4z6rr386qemrgoNmQUr269ndMJFumeDzFN7GgQ2qXXP9SuyyeOnTIdymOjcmaPrteTCbLrf+27so6Kd6qt19JcYMrU7vGttnBba8tbQAAmCDNrDR1KHHWRIOxSAMP//n3bHiA0vT9XfohxWsxadUA5YWY7FDTzJpcZP0O2ER/F03tMkrT3+MdMeE0fWa+8fW4K+yL9jWo8/t+25cBADBj6kx856KZl+xFt72TVUt7kT77R9gvdWZ9LwvpnH6mb0n9pwaYV7t812JbeJMasDW1yyh/xYRVg5f1Y9Jpq/988a0N1uONsC9qm2vdvpZPs3gsAAAzVhpwZTu77QesWkLzNrDqeH/jtfZjx/6hlWd1uqLludhJ5n1d86a+oGPxOry+B2yj2mWUe1JsEXLx+6JR5eOiummm76MU14WyjVPcb9V9lvuGssNSvJziThte1sxUB9Xd78d6qdzPSF9h1W9e93ROp20BAGh0iVUdzzspnkvxS4qHBo6YEjso+cKmOi8N0vJ2XAY8p863+Wwa8fZ/R7d70qrz6Ub5lfW2rqFvF1p7vfsesM22XfRQwi0h11Y/GVU+Dqts8Dza1r2ZefsqV7Ykxb31th6gOcqVaUBXou9Q+N/40wNHVG3TR10BAAvQj1Z1MlrS0pLY5Sn2HjhiSqkzyp1XzGlGwzu6zvclX5fqpZeWls6thyy6phmf0rkzDdi03NYXXcvt9v/bZSMbfsK29B3eqPJx0DlOd/t7uu3S+XNOf/7q8kvddna4DX+H9vUwjae2iccBADAW6mD88uXubjsqdUbKadCRaYDyvtvPDrDy57ugwYjOpSdas3juvK9Batvy6AnTjCYrbPjcntpudUwWxPOVYpTcLl7cz4MeDSKb2sW3q8TviEaVS6xLKdroHKWb+jX4LJ1fuTwL/HG9r4hL+aJ79B5z+yfZ8MM4WelcAADMmjqYm2KyQakzUm6fsF/qOE+x8ue9G6cR/qbuJuqIda7jYkHteKuWcrMVbnvc9JBGW701YPs+JjuS26WJ2iXTDfOldtk+xSMh1/adMqp8HHSO3WKyVjq/cmem2NHlltf5SP8+znf7evrYv7IjU9uUPg8AwKzMdAnn65iw6vP5Ju5XU7zryjzdM+QfbOiSrqmtXpot8Q9AtB07W1pebvt+Ddi0LN2H6bRLlt9hF51mg/d8Sek4b1T5OOgc8felAZmoTEvy2SKbWgZVmX+w5gK3nS2xqfytNvzS3Ext00ddAQALiF78qWUddTAfpHh+sLhIL8w9OOROTPG5VbNsqwaLBmipKb9YtyvqoDUQywOTN234Bnl51PobsEnp+5da9WRivlY9TPGsP2CMYru8ZM3tkp1r5euOy6HiZyu9lVYN8vU9q627+mX6PWspV4PkT1x+sVXXcHOKs+rtLLfJySn2C2Wefr96rc1PscBR2+gJVQAAJq70FJ1mKOKsS6SOsLRUOgnXW/VUbPal2+5C0yBgrlG7ZBdbuV1KdTnDhl+VMSn6P279Er2nazwk5PK9cVpObauD7nVcFpOB2kaDQwAAJk6dUttLUpvoHVdzSR54aBC51OW78mBMzFEH1n9qaXupy4ueIG56rUppILfQNLUNAAC90xvyZ7rs80xMzAGHWvUQQ18Djb7OM1trrGqXu2OBtddB7/Cbyfvc1jZXxgQAAJOmWammZafoKxv+3xEWKs3ANL0qY67TgGyUPDu30Kht/HvfAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPTrXwOPjFQ06Q72AAAAAElFTkSuQmCC>

[image36]: <data:image/png;base64,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>

[image37]: <data:image/png;base64,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>

[image38]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEEAAAAYCAYAAACldpB6AAABkklEQVR4Xu2Wv0rEQBDGv0pQK/EBVLCw00LsrxJUxEq01MaHsBDfQLESfAIbsbUXBQsLQRBEUAQL/6OHCv6bYXZzcUwu2dzqBW5/8EH2m2GY7G52AwQCrc6sNlqNCdKXNi0rpEdIAuuFdKe8zSi7HPSRblDr74P0QLo3z+xdRdnCofHrYgtqeiD+jg6UgEsk98zo9+Hn+dg4EU7a06ZBFywL9frSsbS8iBlI0qgOEO34XdAHPurlXbhx0n4slsgx0pvagsSmdKBB1klt2nRgGukLNwiJHZjxLqmjFk4mbaUrEH9VBzxxoQ0H0hauE+Kf6UAWdhLsCftqxkek7lieb/gz3NBmTmzPfIvxbVY14yfI9nfCngeZJ2cGQ6ThAlqCvITrZHPP59osygmSt5UrY6TJAuJJeCP1Iz/858c9z+lAUey2agYDpG1t5uAUnnvmYly0GVxrIydeF24RUmxBB/6BZchJ7koXpGf9W+zMGuQU5ZvAnqyfPzL+HteV7CU9Q3q+hfT/ThqJ5QQCgUAgEGiMbwE9eyvw2Q2GAAAAAElFTkSuQmCC>

[image39]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEEAAAAYCAYAAACldpB6AAAB0ElEQVR4Xu2XyytEURzHfyUk5bm0kZCSPLLAP6AoJAtZeCxkyUpZycJSkiiyYu+xUbL0H1hYkBQLIY8Npby+p98Zc+Y393HmmmHK+dSne+f3vX7zmzP3ngaRw/HfGZEFPyrgFFyDVUa9wzjPNnJgH1yHwyKLzV0CP2G9kSWxRXzRGeyGNXAVXsN2nWUbjcRzfcBpWAvHdC1fH8v0tYv6tS+xRsUyADPE+bEM/ph94rkmZaBRmfmh3+Gm8TqBNwpZIeK8Xxb/kAXimZplYHBP/MXG8P2MT8RhgQwEvg1+QNSeQ8R/q57/IHbgkj4vgi9G9k0DcbNTGXgQdeAg1MabJ4sWyNvcjwNYqs/nife1JNQzopp57QO/xaUshDBBPPORDKJiu6KZZBBuyGIAV8Qzd8ogKulehCbYGsFZ+ADLKZy0zqx+XKhmNzLwwPZNu2BPBNUivMJqCsd2EZZhoSx6YdOwDY7KYhqpg3uyGMAFhc+sUPudFefEDdVd4YWq38pimrmThRAqiWdeEXWTE5gri0GohurHklyIFkp9wFSZI8tbVrBNPPeADIg3TvP/HWsOKf5oPOvjeMIVmcHmtvajl+IzP+rjbsIVDofD4XA4ovAFbQVujLs4ozsAAAAASUVORK5CYII=>

[image40]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFgAAAAYCAYAAAB+zTpYAAACW0lEQVR4Xu2YTagPURjGXx/5WN2NElbcLHS7JZHPnY24iA0LCxsLO0liZaGIlCyQ7EhJlLIQImVjhaSrSJby/VGsfD1PZ253/k9n5pyZ/5nuXZxfPc30vG/vvPf83zNzZ8wymUymNfOgs9AMDXTEUugYdBqaWfKPls4nGwugfdAFaFHJX1M697IK+gvtgv5JLDVvzV3jFrQOWgu9hE5CV6Fn46mThsvmen4NbYIWQ+egd9DqIlYLE04Vx2ByS/jrszYX2Mcnc/HtGphg2BOHb0AD4LC5+HMNKExaomZCZpu7xisNlBi27n7ctvy2cE/Bodhh4SL9ErszYnKacl+NSL6Z64fDUUdlz4PQRuixuaTN0IaejGqmQHPVrOC6ufq8v4d4qkYCuL2bMrab6nbcGJULvBXaby6BTfCcT8gYYieSNMntAj5ID6oZ4I+5nn333cawEKesCQ+hL2p64C5hfd7LJpIn0Eo1a0g6FCw0omYiDpirf0kDfbC8pbjdH1gcyRZ4hSUqVMERc/X3asDDXTUq2NJSo4WmWz3TzPX8XgMegmt33iKS+oBvO6x/TQPCbWiqmgk5Y+4FIZaYCebL2W41lV8WLuRjPrRNzQpCzXL7HlczIQuhE2oGeGOuZ06zD/of1PTBInfUjCC0aGXmmMt9oQFwCLqiZmJ+qBEJe+bDWRd5GfRRvEpYZL2aEXBhbqpZAz8gfTV3Pf5LyON3aKic1BGP1GjAPRsfpp/FcU9PRg3842KnMNMALiq3zUXos8QyCeAC7yyOsySWSQC/mt2w3o/cmUwmk+mW/9eEkNAYyJLBAAAAAElFTkSuQmCC>

[image41]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFgAAAAYCAYAAAB+zTpYAAACNUlEQVR4Xu2YvWsVQRTFjygqGLAUtTAoQcTCRkG0VFCCH6RRwRDyDwTESgQrDWlsLERBJf+AgqV2aUSxs7MyYOd3vozg9z3c3YfvwNudmd33TDE/OOxyz92Z+2Z3Z+YtkMlkMslsN902bVQj05zDpt+mcdMf8drirekbvH1qxfSxOJaxiU722uAluuv7avpkWv4nNt3JroCJN4tjvwa4hO0/16BxC+4dVWMNwLp+aNAYg3tX1VCYtE+DfeAivK8TahgH4N4bNf4zO+F1zahRUPtQnkdNQou8Ru++bsC9x2o0YIvpmgYjuQuva0gN4zjc+6AG2WMaNb2AJ502nezK6M060zYNBlB1t0tvvRoN6dVfKFU1v4N7u9QgZ02X4Qlc4Hh+qSujN1WdVsFrnmnQeAD3DqrRApwfj2gwAtb1XYPGFNyrXZiZ9FCDNcyZPmuwhnPwvn6avpgWi/OU/mNhrSlvHK8pH0DWvAAfbMbmTBs6mRUw+ZQG+0DV/BsDn/IUcbs1izjK+Xe3GqEcQjs/OoTUaUU5kyjuXZ8ijsY130HDBiJgP/MaHBCc90c0GEDjAV5FWgM74JvsUCbh/fCf4qDhIsTdUizD8JrvSzwKNhD72pDYO/secfltktrvE/i1e9WIgQ0c02AAVxD2h4CrN3cLPHIF5rcIalBsNV3XYA2vTEvwmrlz4Fv+qysjkP1Iv7uZCjiovEP34F+GMi3DAb5QHDeLl2kBfjV7ZNqkRiaTyWT6xl+Z0p2zk1x8zgAAAABJRU5ErkJggg==>

[image42]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAHsAAAAWCAYAAADgreP7AAACaklEQVR4Xu2ZO2hVQRCGfxQRLWIh2goKaVOolWksgha+SBECEZWoCCm1sLDUSgsfKYOPENJEISmstFFBrSyCIAqiKCQ+EOMTRUSd39lN9oz33Ec88e497gc/Z+7MnmLO7O6csxdIJBKJRCLRipwRvRf9dPoiemt8Y7Ojy8dzaM4+10+iN+7qfXtmR5cEn5hlDdR/zQZKBnO8a53CWWhskw20MnnJkryJUBb6oPltsQGhAxp7YgM16BJttM4Y6EV+sstQ/mI/RH5+J6CxCRuowVZEWuwHyE92HBrbZQMlotpk9rHFNlCDbYi02HnJbob62bfKDHO8bZ3CeWhsgw3UwXZEXux3ohnRV/f7vmhlMK5ZjFTRsOiS6AK0OEOipb/vqo8eaK7fobnzK4Q2fVeCcY0SZbF9v+63gf+Eav26XrjyrQ6L9lbwz2eXKIxH+PtkW5m8FtYIOyrouOhIBT/VNIpIdqE52aDa9La6YO5PrbMAotzGmexj6zTw4V0WjYqOQvvjh8wI7ZM8ebsI3S3IWtFVaF/1fHPXj2j+G/4+aP67jb8Ioiv2MWiyh2zAwL5GOHaRs3nIsN7ZnAzh7nDHXa+LVkOPI0m36J6zB0T7nd0sXmPhdrVoij0IXVl8++Rq/Cz6kRnxJweQPTINH9JL0bToFvQBrgpiN0UHnT2JuZ61XLTC2f8a5sy3bl75BcLJ6CdkUURT7PkwJep09hJki017XfA7xI7zcMKVmZYudlgo/lN2GtrzCFe139LJqcDOK/a5wE5EBrdnT7voGbKfEWwFN6BHryHsy9wiX4l2il5grqcnEolEomF+AVRSrIR/bFxsAAAAAElFTkSuQmCC>

[image43]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAALEAAAAYCAYAAAC1OhzjAAABDElEQVR4Xu3ZPWoCURTF8QuprFxAOsEyjZXJFiSNK0hjb2tr6QICIRgMWUZ2YamklmhjY2c+zuMNOLm8oElM8pT/Dw4j947d4THMmAEAAPyqU6Wr3Ci10vyi9BvI0oPypkyVllJXrpWZcl7sgGyFgr4qVb+QnsX92C+AXKxt+ykb9m0/BHKwtFjQil8420oO/Iszi+Wc+EUCJUaWXiyWM/UcDByEUOB9nrC3Ft9wpHKvjJQ7ZVjcG96AAD+y7xIDf+rEYoGf/SKBoiNbu5zETeXKDz/RVwZfyGX8G/B9TxZLHE7llDCf+yGQm1Di8LHDF7mhLNwMyNajbR4tVsW18+EOAAAAAAAAAMAxeQfZQznNWMk9HQAAAABJRU5ErkJggg==>

[image44]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAMMAAAAWCAYAAAB9jCg2AAADPElEQVR4Xu2aS6hOURTHF1FEHiPKKwNmjGQgJImUx4BQJpSBKClv3RQjj2SIiOuVDBhIFAMkkncSIo8BeT/yfrP+rb1Z3/r2Pl+37nd992v96t/de/3Xuefc7t7n7BeR4ziO4ziO00QGsrayJqrYYlV2nLqnPesXaxurC2sk6zergfVe5UXusT6T5EAfWC9JcmNs99/scvS1RfoaL3CclgINb7gNksRX2qAC/lkbZPqSeOg0RSDnpw0GbrFO2qDjVJNGkkaZAnF8NVLMJPFHWyOwhMTvao3AEBJ/vTUCE1irbdBxqkkckqTIxcFtKvY7kfibrBE4QuJ3VrF2qjyZ8h3NcapC7AwbrVGBok4EOpD416wRSF1/XJV7sdqouuNUnQ30r2FGbSnJSIO8UzaomEqSk5tIw/uh6mNCzHH+KwuovEPcKckoZRpJzigT15wjyZluDWYold8PeqaTWgmDWXsywotgF2snawdrO8mKndNKiG/oord0pfkCKPodx0i8biqGDjlf1ZuDeaxFNug4KabYQABvtVxDBkUNHfQj8Y9aI5C6fp+pNwf4gnW0QcexTGIttMFAXBbNAe+0DSrg6/mApZLfmuhPsjzcFDk1xmXWIRsMYCMsN4meRdKYc8ueN0l2s3MrQdjcw/XrrGFoS/KMd1XsqSrDw32wY475zRPWOOU/JtkZ1/RhvWIdZp0PsRmsqyT7HldY+ym/AubUKXGootf5wUFKH8GIPKf0V2M5SRwNqogLJHk9rGGIE3h9r1hGo0ZnQX1piGHXOz53fAZ97SCSIyORR6yxrAOsuaxvykv9fU4dg8aABvWW5J//JvxsVDma1yRv4tiJUP5Ocn7oI0lnKAL3e0fye/B2xn1xbWq1KbKGtTeUR7AeKA/oRovhx2ZVH09ypCOC3J6qjmeIE3Y82zDleWdwag40yjgBPsGao7wBrE+qjlx9dOQLq7eq2wae+uIArD5hGOU4NUWqwcbxPL4YK0IZRH+Zqa8ydYCFgzOqrj188bpT5UOGjtOiYKiD4dt1krnBJZJjHgCrURjmRTDsuaHqL1gPVR0bfVgYuM+areLYV9Hnp9ayLlL5XMpxHMdxnLrnDyi07qvMTbklAAAAAElFTkSuQmCC>

[image45]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIEAAAAWCAYAAADnw/+rAAADQ0lEQVR4Xu2ay8sPURjHH7fkfg3FqzclFCVJbgslJDsLNogFFjZYkAVZsJENhcjldfkLLBQWFhYukWspt4iSW+73y+v59pxjnnnMmFHzu8wxn/o25zzP+c3Meea8Z55z5iWqqKioqKjIZChrNWsva4SyT1Xl0OnHWsHax5qk7INVOUiOstpZd1jzWCNZu1lPWFOcL3Q2kvTzOWsBq9XZvrAGOV+woHM/WX2sg9lA4r9uHYHxmaSfGPwW/0eAGAXJd8oe4fDPt8aAeEr5YrDTGkPgNUnnulmHIStAZeYqSf9GWYcBbfpbY9kZR9Kx29aRQKiDoCtJ3zAbZlHvGPSgOlzzB8lFkvKA/4WHJDGYaR0NBCsTjx4EnVW5MHCBmo+0AtlMsoJJ0hFWG+sQ6wBrP2sNfpRBM8YA93NXlXu7I1YohdOMAag3RccA+wpp59tC4ptsHQlsJWmL1QiO0+LuYuhEcnJkxVmkdSoE8g6Cr9aQwlzWPWtU5LkWWEbRvX1kDYu7iyNPADBql1pjg8AO3rZ/EHY9s8gTA7yj26wxhQusJdaoyLoWQBus2ny51R3f+gZFghGLk2NWSAL2Z8Z2mWSKwnsKqwrsJs6JtZB39EXWA2V7zPqm6mfccRbV6F2Xk4MkMRhuHQok0JYW1kvWcdZ5ZbcPuQNJjE6wDlPU77+hXxf6fH1VuVBwESyP7ECYQLJ1qkHHO5L8Zp2zIXjvfrcgesMa7cq9WNNZe1xddyit3Ag+kdzDAGMfQvGB68HS+oWqY4DPdmXbF13HK2WGqmfRk/48X804TXIx6IM7Lo+1iKNvDNOuf8hjne8U6z1rpW9E8Q5hw0X/dV1S5UaBPvgY+A20TbEWEfBhgHgwI6wimRHx3cWDGdFn+aBuD7TWYF8diYoHHeviypgdHimfBtMuMl6wnbVD+carchmwD9PXz7EWGftiUw+CYyQflDy+Y+tZY1ivlG8gRUnSSYoCdI211pUxa5QN/TCRfJ419hvuiBnW5xr4Got2C1291CB/QF7gwVR4U9V3sW6RZLITlR2/wTvxCsknWSSDmCpRLhv4/wK8zu6TLOU8+OSM2cDHB3kW2iG57k6SX2AfoaKioqJJ+AVZfNemkr/1DwAAAABJRU5ErkJggg==>