#version 460 core

layout(location = 0) in vec2 vTextureCoord;
layout(location = 0) out vec4 FragColor;

// Uniform Block for configuration properties (Binding 1, Set 0)
// Padded to 20 floats (80 bytes) to match GridShader size and avoid descriptor collisions.
layout(std140, set = 0, binding = 1) uniform SimpleTextureFragmentUniforms {
    vec4 uModulateColor; // Offset 0
    vec4 uPadding1;      // Offset 16
    vec4 uPadding2;      // Offset 32
    vec4 uPadding3;      // Offset 48
    vec4 uPadding4;      // Offset 64
} fragUniforms;

layout(set = 0, binding = 2) uniform sampler2D uSampler;

void main() {
    vec4 texColor = texture(uSampler, vTextureCoord);

    // Both are in straight alpha space.
    FragColor = texColor * fragUniforms.uModulateColor;
}
