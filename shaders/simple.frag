#version 460 core

layout(location = 0) out vec4 FragColor;

layout(std140, set = 0, binding = 1) uniform SimpleFragmentUniforms {
    vec4 uColor; // Offset 0
    vec4 uPadding[7]; // 4-31
} fragUniforms;

void main() {
    FragColor = vec4(fragUniforms.uColor.rgb * fragUniforms.uColor.a, fragUniforms.uColor.a);
}
