#version 460 core

layout(location = 0) in vec2 v_uv;

// Uniform Block (Binding 1, Set 0)
layout(std140, set = 0, binding = 1) uniform FragmentUniforms {
    vec4 uTextColor;
} fragUniforms;

// Separated Sampler binding (Binding 2, Set 0)
layout(set = 0, binding = 2) uniform sampler2D uSampler;

layout(location = 0) out vec4 FragColor;

void main(void) {
    vec4 texColor = texture(uSampler, v_uv);
    FragColor = texColor * fragUniforms.uTextColor;
}