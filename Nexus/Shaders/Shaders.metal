#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

/// Generates a pseudo-random floating point value between 0.0 and 1.0.
/// - Parameter p: The input position (e.g., screen coordinates).
/// This function is marked as stitchable, allowing it to be dynamically linked
/// into other shader graphs at runtime if needed.
[[stitchable]]
float random(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453123);
}

/// Applies a time-animated noise effect to a color.
/// - Parameter position: The screen-space position of the current fragment.
/// - Parameter color: The original color of the fragment.
/// - Parameter size: The size of the view the shader is applied to. (unused)
/// - Parameter time: A float value that changes over time for animation.
/// - Parameter strength: The intensity of the noise effect.
/// - Parameter opacity: The opacity of the noise effect, from 0.0 (transparent) to 1.0 (opaque).
[[ stitchable ]]
half4 noiseShader(float2 position, half4 color, float2 size, float strength, float opacity) {
    float value = fract(sin(dot(position, float2(12.9898, 78.233))) * 43758.5453);
    
    // Create a noisy color by adding the noise value (adjusted by strength) to the original color.
    // Subtracting 0.5 from `value` centers the noise so it can both lighten and darken pixels.
    half3 noisyColor = color.rgb + (value - 0.5h) * strength;
    
    // Blend the original color with the noisy color based on the opacity.
    // An opacity of 0.0 returns the original color.
    // An opacity of 1.0 returns the fully noisy color.
    half3 finalColor = mix(color.rgb, noisyColor, opacity);
    
    return half4(finalColor, color.a);
}
