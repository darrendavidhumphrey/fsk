#version 460 core

precision highp float;

layout(location = 0) in vec2 v_uv;
layout(location = 0) out vec4 FragColor;

// Unified 40-float (160-byte) block size for single-pass stability.
layout(std140, set = 0, binding = 1) uniform BitmapTextFragmentUniforms {
    vec4 uTextColor; // 0-3
    vec4 uPadding[9]; // 4-39
} fragUniforms;

// Unified Binding: All fragment shaders in this pass use Binding 2 for their primary sampler.
layout(set = 0, binding = 2) uniform sampler2D uSampler;

void main(void) {
    vec4 texColor = texture(uSampler, v_uv);
    FragColor = texColor * fragUniforms.uTextColor;
}
