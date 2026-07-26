#version 460 core

// Input Interface
layout(location = 0) in vec2 vTextureCoord;
layout(location = 1) in vec3 vNormal;
layout(location = 2) in vec3 vEyeCoords;
layout(location = 3) in vec3 vBarycentric;

// Output Attachment Destination
layout(location = 0) out vec4 FragColor;

// Uniform Block for configuration properties (Binding 1, Set 0)
layout(std140, set = 0, binding = 1) uniform FragmentUniforms {
    vec4 uLightPos;          // Index 0-3
    vec4 uAmbientLight;      // Index 4-7
    vec4 uDiffuseLight;      // Index 8-11
    vec4 uSpecularLight;     // Index 12-15
    vec4 uMaterialAmbient;   // Index 16-19
    vec4 uMaterialDiffuse;   // Index 20-23
    vec4 uMaterialSpecular;  // Index 24-27
    vec4 uOutlineColor;      // Index 28-31
    vec4 uConfig;            // Index 32-35
// uConfig.x = uMaterialShininess
// uConfig.y = uOutlineEnabled (0.0 or 1.0)
// uConfig.z = uDrawFill (0.0 or 1.0)
// uConfig.w = uOutlineWidth
} fragUniforms;

void main() {
    // 1. Calculate the outline factor first
    vec3 d = fwidth(vBarycentric);
    vec3 a3 = smoothstep(vec3(0.0), d * fragUniforms.uConfig.w, vBarycentric);
    float outlineFactor = min(min(a3.x, a3.y), a3.z);

    // 2. Calculate Lighting (Phong Model)
    vec3 lightDir = normalize(fragUniforms.uLightPos.xyz - vEyeCoords);
    vec3 viewDir = normalize(-vEyeCoords);
    vec3 reflectDir = reflect(-lightDir, vNormal);

    // Ambient
    vec3 ambient = fragUniforms.uAmbientLight.rgb * fragUniforms.uMaterialAmbient.rgb;

    // Diffuse
    float diff = max(dot(vNormal, lightDir), 0.0);
    vec3 diffuse = fragUniforms.uDiffuseLight.rgb * fragUniforms.uMaterialDiffuse.rgb * diff;

    // Specular
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), fragUniforms.uConfig.x);
    vec3 specular = fragUniforms.uSpecularLight.rgb * fragUniforms.uMaterialSpecular.rgb * spec;

    vec3 litColor = ambient + diffuse + specular;

    // 3. Combine Fill and Outline based on config
    vec4 finalColor;
    float drawFillFlag = step(0.5, fragUniforms.uConfig.z);
    float outlineEnabledFlag = step(0.5, fragUniforms.uConfig.y);

    if (drawFillFlag > 0.5) {
        finalColor = vec4(litColor, 1.0);
        if (outlineEnabledFlag > 0.5) {
            finalColor = mix(fragUniforms.uOutlineColor, finalColor, outlineFactor);
        }
    } else {
        finalColor = vec4(0.0, 0.0, 0.0, 0.0);
        if (outlineEnabledFlag > 0.5) {
            finalColor = mix(fragUniforms.uOutlineColor, finalColor, outlineFactor);
        }
    }

    // Render with native premultiplied alpha formatting
    FragColor = vec4(finalColor.rgb * finalColor.a, finalColor.a);
}