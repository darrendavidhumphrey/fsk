#version 460 core

precision highp float;

layout(location = 0) in vec2 vTextureCoord;
layout(location = 0) out vec4 FragColor;

// Uniform Block for configuration properties (Binding 1, Set 0)
// Padded to 40 floats (160 bytes) for single-pass stability.
layout(std140, set = 0, binding = 1) uniform SimpleTextureFragmentUniforms {
    vec4 uModulateColor; // 0-3
    vec4 uPadding[9];     // 4-39
} fragUniforms;

layout(set = 0, binding = 2) uniform sampler2D uSampler;

void main() {
    vec4 texColor = texture(uSampler, vTextureCoord);

    // Strict Discard: if texture is essentially zero (uninitialized or clear), skip rendering.
    if (texColor.a < 0.01) {
        discard;
    }

    // Both are in straight alpha space.
    FragColor = texColor * fragUniforms.uModulateColor;
}
