#version 460 core

layout(location = 0) in vec2 vTextureCoord;
layout(location = 1) in vec4 vColor;

layout(location = 0) out vec4 FragColor;

// Uniform Block for configuration properties (Binding 1, Set 0)
// Padded to 20 floats (80 bytes) to match GridShader size and avoid descriptor collisions.
layout(std140, set = 0, binding = 1) uniform FlatFragmentUniforms {
    vec4 uModulateColor; // Offset 0
    vec4 uPadding1;      // Offset 16
    vec4 uPadding2;      // Offset 32
    vec4 uPadding3;      // Offset 48
    vec4 uPadding4;      // Offset 64
} fragUniforms;

// Optional: Dummy sampler to ensure binding layout consistency.
layout(set = 0, binding = 2) uniform sampler2D uSampler;

void main() {
    // Combine vertex color with modulation uniform
    FragColor = vColor * fragUniforms.uModulateColor;
}
