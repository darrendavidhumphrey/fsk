#version 460 core

layout(location = 0) in vec2 vTextureCoord;
layout(location = 1) in vec3 vNormal;
layout(location = 2) in vec3 vEyeCoords;
layout(location = 3) in vec3 vTangent;

layout(location = 0) out vec4 FragColor;

layout(std140, set = 0, binding = 1) uniform FragmentUniforms {
    vec4 uLightPos;
    vec4 uBaseColorFactor;
    vec4 uParams; // x: roughness, y: metallic, z: debugMode
} fragUniforms;

layout(set = 0, binding = 2) uniform sampler2D uBaseColorMap;
layout(set = 0, binding = 3) uniform sampler2D uNormalMap;
layout(set = 0, binding = 4) uniform sampler2D uMetallicRoughnessMap;

void main() {
    // AGGRESSIVE DIAGNOSTIC MODES
    if (fragUniforms.uParams.z > 3.5) {
        // MODE 4: SOLID NEON MAGENTA (Confirm Geometry & Frustum)
        FragColor = vec4(1.0, 0.0, 1.0, 1.0);
        return;
    }
    if (fragUniforms.uParams.z > 2.5) {
        // MODE 3: TEXTURE ONLY (Confirm UVs & Texture Loading)
        FragColor = texture(uBaseColorMap, vTextureCoord) * fragUniforms.uBaseColorFactor;
        return;
    }
    if (fragUniforms.uParams.z > 1.5) {
        // MODE 2: NORMALS (Confirm TBN & Normals)
        FragColor = vec4(normalize(vNormal) * 0.5 + 0.5, 1.0);
        return;
    }
    if (fragUniforms.uParams.z > 0.5) {
        // MODE 1: UV GRADIENT
        FragColor = vec4(vTextureCoord, 0.0, 1.0);
        return;
    }

    // Standard PBR Logic...
    vec3 N = normalize(vNormal);
    vec3 V = normalize(-vEyeCoords);
    vec3 L = normalize(fragUniforms.uLightPos.xyz - vEyeCoords);
    float diff = max(dot(N, L), 0.0);
    vec3 diffuse = texture(uBaseColorMap, vTextureCoord).rgb * diff;
    FragColor = vec4(diffuse, 1.0);
}
