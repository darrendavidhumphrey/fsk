#version 460 core

layout(location = 0) out vec4 FragColor;

// Unified 40-float (160-byte) block size for single-pass stability.
layout(std140, set = 0, binding = 1) uniform SimpleFragmentUniforms {
    vec4 uColor; // 0-3
    vec4 uPadding[9]; // 4-39
} fragUniforms;

// Optional: Dummy sampler to ensure binding layout consistency with other shaders.
layout(set = 0, binding = 2) uniform sampler2D uSampler;

void main() {
    FragColor = vec4(fragUniforms.uColor.rgb * fragUniforms.uColor.a, fragUniforms.uColor.a);
}
