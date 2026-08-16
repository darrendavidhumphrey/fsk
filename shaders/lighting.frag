#version 460 core

layout(location = 0) in vec2 vTextureCoord;
layout(location = 1) in vec3 vNormal;
layout(location = 2) in vec3 vEyeCoords;

layout(location = 0) out vec4 FragColor;

// Uniform Block for configuration properties (Binding 1, Set 0)
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

    // Headlight soft lighting model
    // High ambient + Half-Lambert diffuse
    float diffuseFactor = max(dot(s, n), 0.0) * 0.5 + 0.5;
    vec3 ambient = vec3(0.15);
    vec3 lightIntensity = fragUniforms.uLd.rgb * fragUniforms.uKd.rgb * diffuseFactor + ambient;

    vec4 texColor = texture(uSampler, vTextureCoord);

    // Very subtle specular
    vec3 v = normalize(-vEyeCoords);
    vec3 r = reflect(-s, n);
    float spec = pow(max(dot(v, r), 0.0), 16.0);
    vec3 specular = vec3(0.05) * spec;

    FragColor = vec4(texColor.rgb * lightIntensity + specular, texColor.a);
}
