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

// SwiftUI color-effect shader (works great for text).
// width:   0..1 of the view diagonal that the band occupies
// strength: how strong the contrast of the band is (0.0..0.6 is sane)
[[ stitchable ]]
half4 shimmerColor(float2 position,
                   half4  inColor,   // pixel’s current color (premultiplied)
                   float2 size,
                   float  time,      // seconds
                   float  angle,     // radians
                   float  width,     // e.g. 0.25
                   float  strength)  // e.g. 0.22
{
    // Normalized coords and sweep direction
    float2 uv  = position / size;
    float2 dir = float2(cos(angle), sin(angle));

    // Project onto sweep direction and animate with time (wrap 0..1)
    float x = fract(dot(uv, dir) - time);

    // Distance from band center (0.5) → soft band via smoothstep
    float d    = abs(x - 0.5);
    float band = smoothstep(width, 0.0, d);  // 1 at center, 0 outside

    // Always-visible shimmer:
    //   Outside band → slightly dim base (baseGain < 1)
    //   Inside band  → brighten up to (1 + strength), then clamp by premult alpha
    float baseGain = 1.0 - strength * 0.55;     // e.g. 0.88
    float gain     = mix(baseGain, 1.0 + strength, band);

    // Apply gain to premultiplied RGB; preserve alpha.
    half3 outRGB = clamp(inColor.rgb * half(gain), 0.0h, inColor.a); // keep <= alpha
    return half4(outRGB, inColor.a);
}


[[ stitchable ]] half4 shimmer(SwiftUI::Layer layer, float2 position, float time) {
    // Sample the original color
    half4 color = layer.sample(position);
    
    // If the pixel is transparent, return as-is
    if (color.a < 0.01) {
        return color;
    }
    
    // Create diagonal shimmer line using raw position coordinates
    // This creates a diagonal pattern across the text
    float shimmerLine = (position.x + position.y) * 0.002; // Scale down the position values
    
    // Animate the shimmer position - moves the shimmer band across
    float shimmerPos = fmod(time * 0.3, 3.0) - 1.0; // Cycle from -1 to 2
    
    // Calculate distance from the moving shimmer line
    float dist = abs(shimmerLine - shimmerPos);
    
    // Create shimmer intensity with smooth falloff
    float shimmerWidth = 0.4;
    float shimmer = 1.0 - smoothstep(0.0, shimmerWidth, dist);
    shimmer = shimmer * shimmer; // Square for more focused highlight
    
    // Boost the shimmer intensity
    shimmer *= 1.5;
    
    // Create bright shimmer color
    half3 shimmerColor = half3(1.5, 1.5, 1.8); // Slightly blue-white
    
    // Add shimmer effect to original color
    half3 result = color.rgb + (shimmerColor * shimmer * color.a);
    
    // Clamp to avoid over-brightness
    result = min(result, half3(1.0));
    
    return half4(result, color.a);
}
