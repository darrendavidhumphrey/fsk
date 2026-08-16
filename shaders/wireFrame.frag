#version 460 core

precision highp float;

layout(location = 0) in vec2 vTextureCoord;
layout(location = 1) in vec3 vNormal;
layout(location = 2) in vec3 vEyeCoords;
layout(location = 3) in vec3 vBarycentric;

layout(location = 0) out vec4 FragColor;

layout(std140, set = 0, binding = 1) uniform WireFrameFragmentUniforms {
    vec4 uLightPos;          // 0-3
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
    // 1. Consume all varyings immediately to prevent optimization mismatches
    vec3 bary = vBarycentric;
    vec3 n = normalize(vNormal);
    vec3 eyeCoords = vEyeCoords;
    vec2 uv = vTextureCoord;
    vec4 texColor = texture(uSampler, uv);

    // 2. Perform soft neutral lighting
    vec3 lightDir = normalize(fragUniforms.uLightPos.xyz - eyeCoords);
    float diff = max(dot(n, lightDir), 0.0) * 0.5 + 0.5;

    vec3 ambient = vec3(0.15) * fragUniforms.uMaterialAmbient.rgb;
    vec3 diffuse = fragUniforms.uDiffuseLight.rgb * fragUniforms.uMaterialDiffuse.rgb * diff;
    vec3 litColor = ambient + diffuse;

    // 3. Edge detection logic
    vec3 d = fwidth(bary);
    vec3 a3 = smoothstep(vec3(0.0), d * (fragUniforms.uConfig.w + 0.75), bary);
    float edgeFactor = min(min(a3.x, a3.y), a3.z);

    vec4 finalColor;
    float drawFillFlag = step(0.5, fragUniforms.uConfig.z);
    float outlineEnabledFlag = step(0.5, fragUniforms.uConfig.y);

    if (drawFillFlag > 0.5) {
        // Solid or SolidMesh mode. Combine light with texture alpha to satisfy binding.
        vec4 fill = vec4(litColor * texColor.rgb, texColor.a);
        if (outlineEnabledFlag > 0.5) {
            finalColor = mix(fragUniforms.uOutlineColor, fill, edgeFactor);
        } else {
            finalColor = fill;
        }
    } else {
        // Wireframe-only mode
        if (outlineEnabledFlag > 0.5) {
            float lineAlpha = 1.0 - edgeFactor;
            if (lineAlpha < 0.1) discard;
            // Use tiny fraction of texColor to prevent optimization of uSampler
            finalColor = vec4(fragUniforms.uOutlineColor.rgb + (texColor.rgb * 0.000001), lineAlpha);
        } else {
            discard;
        }
    }

    FragColor = finalColor;
}
