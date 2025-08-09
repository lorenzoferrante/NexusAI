#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

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
    // Normalize coords and compute sweep direction
    float2 uv  = position / max(size, float2(1.0, 1.0));
    float2 dir = float2(cos(angle), sin(angle));

    // Project onto sweep direction and animate with time (wrap 0..1)
    float proj = fract(dot(uv, dir) - time);

    // Soft band centered at 0.5
    float d    = abs(proj - 0.5);
    float band = smoothstep(width, 0.0, d); // 1 at center, 0 outside

    // Make the band clearly visible even on white text by dimming the base
    float baseGain = max(0.6, 1.0 - strength); // stronger dim outside band
    float gain     = mix(baseGain, 1.0 + strength, band);

    // Apply gain to premultiplied RGB and clamp to alpha
    float3 rgb = clamp(float3(inColor.rgb) * gain, 0.0, min(1.0, (float)inColor.a));
    return half4(half3(rgb), inColor.a);
}


[[ stitchable ]] half4 shimmer(SwiftUI::Layer layer, float2 position, float time, float2 viewSize) {
    // Sample original color
    half4 color = layer.sample(position);
    if (color.a <= 0.001h) { return color; }

    // Normalize using the view size passed from SwiftUI
    float2 size = viewSize;
    float2 uv   = position / max(size, float2(1.0, 1.0));

    // Diagonal sweep from top-left to bottom-right
    float2 dir  = normalize(float2(1.0, 1.0));
    float proj  = fract(dot(uv, dir) - time * 0.5);

    // Soft band
    float d     = abs(proj - 0.5);
    float band  = smoothstep(0.18, 0.0, d);

    // Work in unpremultiplied space to avoid vanishing on thin glyph edges
    float  a       = (float)color.a;
    float3 src     = a > 0.0 ? float3(color.rgb) / a : float3(color.rgb);
    
    // Keep base brightness unchanged so text never dims; only brighten the band
    float baseGain = 1.0;    // outside the band
    float hiGain   = 1.35;   // inside the band
    float gain     = mix(baseGain, hiGain, band);

    float3 dst     = clamp(src * gain, 0.0, 1.0);
    float3 premul  = dst * a;        // re-premultiply

    return half4(half3(premul), color.a);
}
