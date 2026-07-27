#version 460 core

layout(location = 0) in vec2 v_uv;

// Uniform Block (Binding 1, Set 0)
layout(std140, set = 0, binding = 1) uniform TextUniformBlock {
    vec4 uTextColor;
} fragUniforms;

// Separated Sampler binding (Binding 2, Set 0)
layout(set = 0, binding = 2) uniform sampler2D uTextSampler;

layout(location = 0) out vec4 FragColor;

void main(void) {
    vec4 texColor = texture(uTextSampler, v_uv);
    FragColor = texColor * fragUniforms.uTextColor;
  //  FragColor = vec4(1,0,0,0.5);
}