#version 460 core

precision highp float;

layout(location = 0) in vec2 v_uv;
layout(location = 0) out vec4 FragColor;

// Unified 40-float (160-byte) block size for single-pass stability.
layout(std140, set = 0, binding = 1) uniform MtsdfTextFragmentUniforms {
    vec4 uTextColor;  // Offset 0
    vec4 uGlowColor;  // Offset 16
    float uGlowSize;  // Offset 32
    float uReserved1; // Offset 36
    float uReserved2; // Offset 40
    float uReserved3; // Offset 44
    vec4 uPadding[7]; // Offset 48+
} fragUniforms;

layout(set = 0, binding = 2) uniform sampler2D uSampler;

float median(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

void main(void) {
    vec4 texColor = texture(uSampler, v_uv);

    // Strict Discard: if texture is essentially zero (uninitialized or clear), skip rendering.
    if (texColor.a < 0.01) {
        discard;
    }

    // MTSDF decoding: median of three distance channels
    float sigDist = median(texColor.r, texColor.g, texColor.b);
    sigDist = clamp(sigDist, 0.0, 1.0);

    // Strict Noise Discard: if the distance is essentially zero, discard immediately.
    // This removes the "black quad" background even if the texture alpha is 1.0.
    if (sigDist < 0.005) {
        discard;
    }

    // Reverted to 0.25 as requested for this specific font's encoding.
    float threshold = 0.25;

    // Smoothness Width: cap the smoothing to 0.05 to prevent "black quad" artifacts
    // caused by high derivatives in uninitialized memory areas.
    float w = clamp(fwidth(sigDist), 0.0001, 0.05);

    float opacity = smoothstep(threshold - w, threshold + w, sigDist);

    vec4 color = fragUniforms.uTextColor;

    // Glow pass: rendered behind the text.
    if (fragUniforms.uGlowSize > 0.0) {
        float glowOpacity = smoothstep(threshold - fragUniforms.uGlowSize - w, threshold, sigDist);

        // Final pixel color is a mix between glow and text color based on glyph opacity.
        color = mix(fragUniforms.uGlowColor, fragUniforms.uTextColor, opacity);

        // Combine text opacity and glow opacity (clamped by glow color alpha).
        opacity = max(opacity, glowOpacity * fragUniforms.uGlowColor.a);
    }

    // Output straight alpha. We no longer multiply by texColor.a to avoid dependency
    // on uninitialized or poorly exported alpha channels.
    FragColor = vec4(color.rgb, color.a * opacity);
}
