#version 460 core

layout(location = 0) in vec2 vTextureCoord;
layout(location = 1) in vec3 vNormal;
layout(location = 2) in vec3 vEyeCoords;

layout(location = 0) out vec4 FragColor;

// Uniform Block for configuration properties (Binding 1, Set 0)
// Padded to 32 floats (128 bytes) for single-pass stability.
layout(std140, set = 0, binding = 1) uniform LightingFragmentUniforms {
    vec4 uKd;        // Offset 0
    vec4 uLd;        // Offset 16
    vec4 uLightPos;  // Offset 32 (View Space)
    vec4 uPadding[5]; // Offset 48-127
} fragUniforms;

layout(set = 0, binding = 2) uniform sampler2D uSampler;

void main() {
    vec3 s = normalize(vec3(fragUniforms.uLightPos.xyz - vEyeCoords));
    vec3 ambient = vec3(0.1);
    vec3 lightIntensity = fragUniforms.uLd.rgb * fragUniforms.uKd.rgb * max(dot(s, vNormal), 0.0) + ambient;

    vec4 texColor = texture(uSampler, vTextureCoord);
    FragColor = vec4(texColor.rgb * lightIntensity, texColor.a);
}
