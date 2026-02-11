#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - Constants & Helpers

constant float PI = 3.14159265359;

// Polynomial Smooth Minimum (for organic merging)
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Random noise function
float random(float2 st) {
    return fract(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
}

// MARK: - Liquid Glass Surface Shader
// Applies chromatic aberration, Fresnel rim lighting, and a subtle "breathing" surface distortion.

[[ stitchable ]] half4 liquid_glass_surface(
    float2 position,
    SwiftUI::Layer layer,
    float4 bounds,
    float time,
    float2 motionTilt, // x: roll, y: pitch (optional, defaults to 0)
    float2 touchPoint, // normalized UV (0..1) of touch
    float touchStrength // 0..1 intensity of ripple
) {
    // 1. Normalized UV coordinates (0..1)
    float2 uv = position / bounds.zw;
    
    // 2. Surface Undulation (Breathing + Ripple)
    // Create a radial wave from the center
    float2 center = float2(0.5, 0.5);
    float dist = distance(uv, center);
    
    // Calculate surface normal based on sphere-like shape + noise
    // Simple sphere normal approximation
    float2 p = uv * 2.0 - 1.0; // -1..1
    float z = sqrt(max(0.0, 1.0 - dot(p, p)));
    float3 normal = normalize(float3(p, z));
    
    // Add time-based surface noise (liquid wobble)
    float wobble = sin(dist * 10.0 - time * 1.5) * 0.02;
    normal.xy += wobble;
    
    // Add Touch Ripple
    // Radial wave from touch point
    float touchDist = distance(uv, touchPoint);
    // Propagate wave outwards
    float ripple = sin(touchDist * 30.0 - time * 15.0) * exp(-touchDist * 4.0) * touchStrength;
    normal.xy += (uv - touchPoint) * ripple * 2.0;
    
    // Add device tilt (parallax)
    normal.xy += motionTilt * 0.5;
    normal = normalize(normal);

    // 3. Chromatic Aberration (Dispersion)
    // Refract R, G, B channels slightly differently based on surface normal
    float dispersionStrength = 0.03 * (1.0 + sin(time) * 0.2); // Pulsing dispersion
    
    // Red Channel (IOR ~ 1.49)
    float2 r_offset = normal.xy * dispersionStrength * 1.0;
    half r = layer.sample(position + r_offset * bounds.zw).r;
    
    // Green Channel (IOR ~ 1.50)
    float2 g_offset = normal.xy * dispersionStrength * 1.05; // Slightly more bent
    half g = layer.sample(position + g_offset * bounds.zw).g;
    
    // Blue Channel (IOR ~ 1.51)
    float2 b_offset = normal.xy * dispersionStrength * 1.10; // Most bent
    half b = layer.sample(position + b_offset * bounds.zw).b;
    
    // 4. Fresnel (Rim Light)
    // Light coming from top-left (standard UI light source)
    float3 viewDir = float3(0.0, 0.0, 1.0); // Viewer is straight on
    float fresnel = pow(1.0 - saturate(dot(normal, viewDir)), 3.0);
    
    // Specular Highlight (Sun/Light source)
    float3 lightDir = normalize(float3(-0.5, 0.5, 1.0)); // Top-left light
    float3 halfVector = normalize(lightDir + viewDir);
    float NdotH = saturate(dot(normal, halfVector));
    float specular = pow(NdotH, 60.0); // Sharp highlight
    
    // 5. Combine
    half3 baseColor = half3(r, g, b);
    
    // Add glass tinting and lighting
    // Rim light is white, Specular is white
    half3 finalColor = baseColor;
    finalColor += half3(fresnel * 0.4); // Add rim glow
    finalColor += half3(specular * 0.8); // Add sharp highlight
    
    return half4(finalColor, 1.0);
}

// MARK: - Liquid Distortion Shader
// Distorts the background to create a "lens" effect, useful for the connectors or the bubble itself if using .distortionEffect

[[ stitchable ]] float2 liquid_distortion(
    float2 position,
    float time
) {
    // Simple wave distortion
    float waveX = sin(position.y * 0.05 + time * 2.0) * 5.0;
    float waveY = cos(position.x * 0.05 + time * 3.0) * 5.0;
    
    return position + float2(waveX, waveY);
}
