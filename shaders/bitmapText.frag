#version 460 core

layout(location = 0) in vec2 v_uv;

layout(std140, set = 0, binding = 1) uniform BitmapTextFragmentUniforms {
    vec4 uTextColor;
    vec4 uPadding[7];
} fragUniforms;

layout(set = 0, binding = 2) uniform sampler2D uTextSampler;

layout(location = 0) out vec4 FragColor;

void main(void) {
    vec4 texColor = texture(uTextSampler, v_uv);
    FragColor = texColor * fragUniforms.uTextColor;
}
