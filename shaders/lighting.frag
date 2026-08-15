#version 460 core

layout(location = 0) in vec2 vTextureCoord;
layout(location = 1) in vec3 vNormal;
layout(location = 2) in vec3 vEyeCoords;

layout(location = 0) out vec4 FragColor;

// Uniform Block for configuration properties (Binding 1, Set 0)
// Unified 40-float (160-byte) block size for single-pass stability.
layout(std140, set = 0, binding = 1) uniform LightingFragmentUniforms {
    vec4 uKd;        // Offset 0
    vec4 uLd;        // Offset 16
    vec4 uLightPos;  // Offset 32 (View Space)
    vec4 uPadding[7]; // Offset 48-159
} fragUniforms;

layout(set = 0, binding = 2) uniform sampler2D uSampler;

void main() {
    vec3 n = normalize(vNormal);
    vec3 s = normalize(vec3(fragUniforms.uLightPos.xyz - vEyeCoords));

    // Soft neutral lighting (Half-Lambert style)
    float diffuseFactor = max(dot(s, n), 0.0) * 0.7 + 0.3;
    vec3 lightIntensity = fragUniforms.uLd.rgb * fragUniforms.uKd.rgb * diffuseFactor;

    vec4 texColor = texture(uSampler, vTextureCoord);

    // headlight mode often benefits from a very subtle specular to show curvature/depth
    vec3 v = normalize(-vEyeCoords);
    vec3 r = reflect(-s, n);
    float spec = pow(max(dot(v, r), 0.0), 32.0);
    vec3 specular = vec3(0.1) * spec; // Very subtle

    FragColor = vec4(texColor.rgb * lightIntensity + specular, texColor.a);
}
