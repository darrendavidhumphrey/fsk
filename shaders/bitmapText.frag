#version 450 core

layout(location = 0) in vec2 v_uv;

// Uniforms wrapped in a uniform block
layout(binding = 1) uniform TextColorBlock {
    vec4 uTextColor;
};

// Separated Sampler binding
layout(binding = 2) uniform sampler2D uSampler;

layout(location = 0) out vec4 FragColor;

void main(void) {
    vec4 texColor = texture(uSampler, v_uv);
    FragColor = texColor * uTextColor;
}