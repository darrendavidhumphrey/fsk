#version 460 core

// Input Interface (Matches vertex location layout index strings)
layout(location = 0) in vec2 v_uv;

// Output Attachment Destination
layout(location = 0) out vec4 fragColor;

// Uniform Block Block for configuration properties (Binding 1, Set 0)
// Unified 40-float (160-byte) block size for single-pass stability.
layout(std140, set = 0, binding = 1) uniform GridFragmentUniforms {
    vec4 u_majorLineColor; // 0-3
    vec4 u_minorLineColor; // 4-7
    vec4 u_mmLineColor;    // 8-11
    vec2 u_resolution;     // 12-13
    float u_scale;         // 14
    float u_majorLineSpacingMM; // 15
    float u_minorLineSpacingMM; // 16
    float u_majorLineThickness; // 17
    float u_minorLineThickness; // 18
    float u_mmLineThickness;    // 19
    float u_fineLineSpacingMM;  // 20
    float u_worldOriginX;       // 21
    float u_worldOriginY;       // 22
    float u_unusedPadding;      // 23
    vec4 uPadding[4];           // 24-39
} fragUniforms;

// Unified Binding: All fragment shaders in this pass use Binding 2 for their primary sampler.
layout(set = 0, binding = 2) uniform sampler2D uSampler;

float getCenteredLineAlpha(float pos, float spacing, float thickness, float fwidthVal) {
    if (thickness <= 0.0 || spacing <= 0.0) return 0.0;
    float centeredPos = mod(pos + spacing * 0.5, spacing) - spacing * 0.5;
    float halfThickness = thickness * 0.5;
    float lineAlpha = smoothstep(halfThickness + fwidthVal, halfThickness - fwidthVal, abs(centeredPos));
    return lineAlpha;
}

void main() {
    vec2 worldCoord = (v_uv * fragUniforms.u_resolution * fragUniforms.u_scale) + vec2(fragUniforms.u_worldOriginX, fragUniforms.u_worldOriginY);
    float dx = fwidth(worldCoord.x);
    float dy = fwidth(worldCoord.y);

    float majorGrid = max(getCenteredLineAlpha(worldCoord.x, fragUniforms.u_majorLineSpacingMM, fragUniforms.u_majorLineThickness, dx),
                          getCenteredLineAlpha(worldCoord.y, fragUniforms.u_majorLineSpacingMM, fragUniforms.u_majorLineThickness, dy));

    float minorGrid = max(getCenteredLineAlpha(worldCoord.x, fragUniforms.u_minorLineSpacingMM, fragUniforms.u_minorLineThickness, dx),
                          getCenteredLineAlpha(worldCoord.y, fragUniforms.u_minorLineSpacingMM, fragUniforms.u_minorLineThickness, dy));

    float mmGrid = max(getCenteredLineAlpha(worldCoord.x, fragUniforms.u_fineLineSpacingMM, fragUniforms.u_mmLineThickness, dx),
                       getCenteredLineAlpha(worldCoord.y, fragUniforms.u_fineLineSpacingMM, fragUniforms.u_mmLineThickness, dy));

    vec4 color = mix(vec4(0.0), fragUniforms.u_mmLineColor, mmGrid);
    color = mix(color, fragUniforms.u_minorLineColor, minorGrid);
    color = mix(color, fragUniforms.u_majorLineColor, majorGrid);

    if (color.a < 0.1) discard;
    fragColor = color;
}
