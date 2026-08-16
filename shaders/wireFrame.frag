#version 460 core

precision highp float;

layout(location = 0) in vec2 vTextureCoord;
layout(location = 1) in vec3 vNormal;
layout(location = 2) in vec3 vEyeCoords;
layout(location = 3) in vec3 vBarycentric;

layout(location = 0) out vec4 FragColor;

layout(std140, set = 0, binding = 1) uniform WireFrameFragmentUniforms {
    vec4 uLightPos;          // 0-3 (View Space)
    vec4 uAmbientLight;      // 4-7
    vec4 uDiffuseLight;      // 8-11
    vec4 uSpecularLight;     // 12-15
    vec4 uMaterialAmbient;   // 16-19
    vec4 uMaterialDiffuse;   // 20-23
    vec4 uMaterialSpecular;  // 24-27
    vec4 uOutlineColor;      // 28-31
    vec4 uConfig;            // 32-35 (x=shine, y=outline, z=drawFill, w=lineWidth)
    vec4 uPadding;           // 36-39
} fragUniforms;

layout(set = 0, binding = 2) uniform sampler2D uSampler;

void main() {
    // Standardize all varyings to vec3
    vec3 bary = vBarycentric;
    vec3 n = normalize(vNormal);
    vec3 eyeCoords = vEyeCoords;
    vec2 uv = vTextureCoord;

    vec3 lightDir = normalize(fragUniforms.uLightPos.xyz - eyeCoords);

    // Half-Lambert diffuse lighting
    float diff = max(dot(n, lightDir), 0.0) * 0.6 + 0.4;

    vec3 ambient = fragUniforms.uAmbientLight.rgb * fragUniforms.uMaterialAmbient.rgb;
    vec3 diffuse = fragUniforms.uDiffuseLight.rgb * fragUniforms.uMaterialDiffuse.rgb * diff;

    // Headlight specular
    vec3 v = normalize(-eyeCoords);
    vec3 r = reflect(-lightDir, n);
    float spec = pow(max(dot(v, r), 0.0), max(fragUniforms.uConfig.x, 1.0));
    vec3 specular = vec3(0.05) * spec;

    vec3 litColor = ambient + diffuse + specular;

    // Edge detection logic
    vec3 d = fwidth(bary);
    vec3 a3 = smoothstep(vec3(0.0), d * (fragUniforms.uConfig.w + 0.5), bary);
    float outlineFactor = min(min(a3.x, a3.y), a3.z);

    vec4 texColor = texture(uSampler, uv);

    vec4 finalColor;
    float drawFillFlag = step(0.5, fragUniforms.uConfig.z);
    float outlineEnabledFlag = step(0.5, fragUniforms.uConfig.y);

    if (drawFillFlag > 0.5) {
        // Solid or SolidMesh mode
        vec4 fill = vec4(litColor * texColor.rgb, texColor.a);
        if (outlineEnabledFlag > 0.5) {
            finalColor = mix(fragUniforms.uOutlineColor, fill, outlineFactor);
        } else {
            finalColor = fill;
        }
    } else {
        // Wireframe-only mode
        if (outlineEnabledFlag > 0.5) {
            float lineAlpha = 1.0 - outlineFactor;
            if (lineAlpha < 0.1) discard;
            finalColor = vec4(fragUniforms.uOutlineColor.rgb, lineAlpha);
        } else {
            discard;
        }
    }

    FragColor = finalColor;
}
