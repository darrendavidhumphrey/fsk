#version 460 core

// Input Interface (Matches vertex location layout indices)
layout(location = 0) in vec2 vTextureCoord;
layout(location = 1) in vec3 vNormal;
layout(location = 2) in vec3 vEyeCoords;

// Output Attachment Destination
layout(location = 0) out vec4 FragColor;

// Uniform Block for configuration properties (Binding 1, Set 0)
// Uses vec4 for Kd and Ld to ensure easy std140 alignment in Dart
layout(std140, set = 0, binding = 1) uniform FragmentUniforms {
    vec4 uKd;        // Index 0-3
    vec4 uLd;        // Index 4-7
    vec4 uLightPos;  // Index 8-11
} fragUniforms;

layout(set = 0, binding = 2) uniform sampler2D uSampler;

void main() {
    vec3 s = normalize(vec3(fragUniforms.uLightPos.xyz - vEyeCoords));
    vec3 ambient = vec3(0.1); // Small ambient term
    vec3 lightIntensity = fragUniforms.uLd.rgb * fragUniforms.uKd.rgb * max(dot(s, vNormal), 0.0) + ambient;

    vec4 texColor = texture(uSampler, vTextureCoord);

    // Render with native premultiplied alpha formatting
    vec3 finalColor = texColor.rgb * lightIntensity;
    FragColor = vec4(finalColor * texColor.a, texColor.a);
}
