#version 460 core

// Input Interface
layout(location = 0) in vec2 vTextureCoord;
layout(location = 1) in vec3 vNormal;
layout(location = 2) in vec3 vEyeCoords;

// Output Attachment Destination
layout(location = 0) out vec4 FragColor;

// Unified 40-float (160-byte) block size for single-pass stability.
layout(std140, set = 0, binding = 1) uniform OneLightFragmentUniforms {
    vec4 uLightPos;          // Index 0-3
    vec4 uAmbientLight;      // Index 4-7
    vec4 uDiffuseLight;      // Index 8-11
    vec4 uSpecularLight;     // Index 12-15
    vec4 uMaterialAmbient;   // Index 16-19
    vec4 uMaterialDiffuse;   // Index 20-23
    vec4 uMaterialSpecular;  // Index 24-27
    vec4 uConfig;            // Index 28-31
    vec4 uPadding[2];        // Index 32-39
} fragUniforms;

// Optional: Dummy sampler to ensure binding layout consistency.
layout(set = 0, binding = 2) uniform sampler2D uSampler;

void main() {
    // 1. Calculate Lighting (Phong Model)
    vec3 lightDir = normalize(fragUniforms.uLightPos.xyz - vEyeCoords);
    vec3 viewDir = normalize(-vEyeCoords);
    vec3 reflectDir = reflect(-lightDir, vNormal);

    // Ambient
    vec3 ambient = fragUniforms.uAmbientLight.rgb * fragUniforms.uMaterialAmbient.rgb;

    // Diffuse
    float diff = max(dot(vNormal, lightDir), 0.0);
    vec3 diffuse = fragUniforms.uDiffuseLight.rgb * fragUniforms.uMaterialDiffuse.rgb * diff;

    // Specular
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), max(fragUniforms.uConfig.x, 1.0));
    vec3 specular = fragUniforms.uSpecularLight.rgb * fragUniforms.uMaterialSpecular.rgb * spec;

    vec3 litColor = ambient + diffuse + specular;

    // Output with premultiplied alpha (assuming opaque mesh for now)
    FragColor = vec4(litColor, 1.0);
}
