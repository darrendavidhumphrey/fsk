#version 460 core

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
    vec4 uConfig;            // 32-35
} fragUniforms;

layout(set = 0, binding = 2) uniform sampler2D uSampler;

void main() {
    vec3 d = fwidth(vBarycentric);
    vec3 a3 = smoothstep(vec3(0.0), d * fragUniforms.uConfig.w, vBarycentric);
    float outlineFactor = min(min(a3.x, a3.y), a3.z);

    vec3 lightDir = normalize(fragUniforms.uLightPos.xyz - vEyeCoords);
    vec3 viewDir = normalize(-vEyeCoords);
    vec3 reflectDir = reflect(-lightDir, vNormal);

    vec3 ambient = fragUniforms.uAmbientLight.rgb * fragUniforms.uMaterialAmbient.rgb;
    float diff = max(dot(vNormal, lightDir), 0.0);
    vec3 diffuse = fragUniforms.uDiffuseLight.rgb * fragUniforms.uMaterialDiffuse.rgb * diff;
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), max(fragUniforms.uConfig.x, 1.0));
    vec3 specular = fragUniforms.uSpecularLight.rgb * fragUniforms.uMaterialSpecular.rgb * spec;

    vec3 litColor = ambient + diffuse + specular;

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

    FragColor = vec4(finalColor.rgb * finalColor.a, finalColor.a);
}
