#version 460 core

layout(location = 0) in vec2 vTextureCoord;
layout(location = 1) in vec3 vNormal;
layout(location = 2) in vec3 vEyeCoords;
layout(location = 3) in vec3 vTangent;

layout(location = 0) out vec4 FragColor;

// Uniform Block for configuration properties (Binding 1, Set 0)
// Padded to 40 floats (160 bytes) to ensure absolute stability in single-pass rendering.
layout(std140, set = 0, binding = 1) uniform PbrFragmentUniforms {
    vec4 uLightPos;        // 0-3
    vec4 uBaseColorFactor; // 4-7
    vec4 uParams;          // 8-11 (x: roughness, y: metallic, z: debugMode)
    vec4 uPadding[7];      // 12-39
} fragUniforms;

layout(set = 0, binding = 2) uniform sampler2D uBaseColorMap;
layout(set = 0, binding = 3) uniform sampler2D uNormalMap;
layout(set = 0, binding = 4) uniform sampler2D uMetallicRoughnessMap;

const float PI = 3.14159265359;

float DistributionGGX(vec3 N, vec3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    float num = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;
    return num / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;
    float num = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    return num / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);
    return ggx1 * ggx2;
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

void main() {
    vec3 N = normalize(vNormal);
    vec3 T = normalize(vTangent);
    vec3 B = cross(N, T);
    mat3 TBN = mat3(T, B, N);

    vec3 tangentNormal = texture(uNormalMap, vTextureCoord).rgb * 2.0 - 1.0;
    vec3 worldNormal = normalize(TBN * tangentNormal);

    vec3 V = normalize(-vEyeCoords);
    vec3 L = normalize(fragUniforms.uLightPos.xyz - vEyeCoords);
    vec3 H = normalize(V + L);

    vec4 albedo = texture(uBaseColorMap, vTextureCoord) * fragUniforms.uBaseColorFactor;

    vec4 mrSample = texture(uMetallicRoughnessMap, vTextureCoord);
    float roughness = mrSample.g * fragUniforms.uParams.x;
    float metallic = mrSample.b * fragUniforms.uParams.y;

    vec3 F0 = vec3(0.04);
    F0 = mix(F0, albedo.rgb, metallic);

    float NDF = DistributionGGX(worldNormal, H, roughness);
    float G = GeometrySmith(worldNormal, V, L, roughness);
    vec3 F = fresnelSchlick(max(dot(H, V), 0.0), F0);

    vec3 kS = F;
    vec3 kD = vec3(1.0) - kS;
    kD *= 1.0 - metallic;

    vec3 numerator = NDF * G * F;
    float denominator = 4.0 * max(dot(worldNormal, V), 0.0) * max(dot(worldNormal, L), 0.0) + 0.0001;
    vec3 specular = numerator / denominator;

    float NdotL = max(dot(worldNormal, L), 0.0);
    vec3 diffuse = kD * albedo.rgb / PI;

    vec3 lo = (diffuse + specular) * NdotL * 3.0;
    vec3 ambient = vec3(0.15) * albedo.rgb;
    vec3 color = ambient + lo;

    color = color / (color + vec3(1.0));
    color = pow(color, vec3(1.0/2.2));

    FragColor = vec4(color * albedo.a, albedo.a);
}
