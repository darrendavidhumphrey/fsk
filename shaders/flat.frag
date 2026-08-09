#version 460 core

layout(location = 0) in vec2 vTextureCoord;
layout(location = 1) in vec4 vColor;

layout(location = 0) out vec4 FragColor;

// Uniform Block for configuration properties (Binding 1, Set 0)
// Padded to 40 floats (160 bytes) for single-pass stability.
layout(std140, set = 0, binding = 1) uniform FlatFragmentUniforms {
    vec4 uModulateColor; // 0-3
    vec4 uPadding[9];     // 4-39
} fragUniforms;

// Optional: Dummy sampler to ensure binding layout consistency.
layout(set = 0, binding = 2) uniform sampler2D uSampler;

void main() {
    // Combine vertex color with modulation uniform
    FragColor = vColor * fragUniforms.uModulateColor;
}
