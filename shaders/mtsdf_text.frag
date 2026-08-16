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

    // MTSDF decoding: median of three distance channels
    float sigDist = median(texColor.r, texColor.g, texColor.b);

    // Adjusted threshold based on heat map evidence (green letters = 0.5 peak)
    // We'll use 0.25 as the new edge to ensure the body is visible.
    float threshold = 0.25;
    float w = 0.05;
    float opacity = smoothstep(threshold - w, threshold + w, sigDist);

    vec4 color = fragUniforms.uTextColor;

    // Glow pass: adjusted for lower threshold
    if (fragUniforms.uGlowSize > 0.0) {
        float glowOpacity = smoothstep(threshold - fragUniforms.uGlowSize - w, threshold, sigDist);
        color = mix(fragUniforms.uGlowColor, color, opacity);
        opacity = max(opacity, glowOpacity * fragUniforms.uGlowColor.a);
    }

    FragColor = vec4(color.rgb, color.a * opacity);
}
