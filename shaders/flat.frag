#version 460 core

layout(location = 0) in vec2 vTextureCoord;
layout(location = 1) in vec4 vColor;

layout(location = 0) out vec4 FragColor;

// Uniform Block for configuration properties (Binding 1, Set 0)
// Padded to 32 floats (128 bytes) for single-pass stability.
layout(std140, set = 0, binding = 1) uniform FlatFragmentUniforms {
    vec4 uModulateColor; // 0-3
    vec4 uPadding[7];     // 4-31
} fragUniforms;

layout(set = 0, binding = 2) uniform sampler2D uSampler;

void main() {
    FragColor = vColor * fragUniforms.uModulateColor;
}
