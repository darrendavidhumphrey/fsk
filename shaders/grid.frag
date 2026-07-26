#version 460 core

// Input Interface (Matches vertex location layout index strings)
layout(location = 0) in vec2 v_uv;

// Output Attachment Destination
layout(location = 0) out vec4 fragColor;

// Uniform Block Block for configuration properties (Binding 0)
// Structured strictly according to size to satisfy cross-platform std140 layout padding
layout(std140, binding = 0) uniform FragmentUniforms {
// 16-byte aligned parameters first
    vec4 u_majorLineColor;
    vec4 u_minorLineColor;
    vec4 u_mmLineColor;

// 8-byte aligned parameters second
    vec2 u_resolution;

// 4-byte scalar parameters grouped tightly at the end
    float u_scale;
    float u_majorLineSpacingMM;
    float u_minorLineSpacingMM;
    float u_majorLineThickness;
    float u_minorLineThickness;
    float u_mmLineThickness;
} fragUniforms;

float getCenteredLineAlpha(float pos, float spacing, float thickness, float fwidthVal) {
    // Adjust the position so the line's center is at 0.0 in a [-spacing/2, spacing/2] range
    float centeredPos = mod(pos + spacing * 0.5, spacing) - spacing * 0.5;

    // The line should be drawn when `centeredPos` is within [-thickness/2, thickness/2]
    float halfThickness = thickness * 0.5;

    // The width of the anti-aliasing transition region
    float antiAliasWidth = fwidthVal;

    // Use smoothstep to create the anti-aliased line
    float lineAlpha = smoothstep(halfThickness + antiAliasWidth, halfThickness - antiAliasWidth, abs(centeredPos));

    return lineAlpha;
}

void main() {
    // Convert UV coordinates to screen-space coordinates using namespace variables
    vec2 fragCoord = v_uv * fragUniforms.u_resolution * fragUniforms.u_scale;

    // Use fwidth() for anti-aliasing
    float dx = fwidth(fragCoord.x);
    float dy = fwidth(fragCoord.y);

    // Anti-alias major lines
    float majorLineX = getCenteredLineAlpha(fragCoord.x, fragUniforms.u_majorLineSpacingMM, fragUniforms.u_majorLineThickness, dx);
    float majorLineY = getCenteredLineAlpha(fragCoord.y, fragUniforms.u_majorLineSpacingMM, fragUniforms.u_majorLineThickness, dy);
    float majorGrid = max(majorLineX, majorLineY);

    // Anti-alias minor lines
    float minorLineX = getCenteredLineAlpha(fragCoord.x, fragUniforms.u_minorLineSpacingMM, fragUniforms.u_minorLineThickness, dx);
    float minorLineY = getCenteredLineAlpha(fragCoord.y, fragUniforms.u_minorLineSpacingMM, fragUniforms.u_minorLineThickness, dy);
    float minorGrid = max(minorLineX, minorLineY);

    float mmLineX = getCenteredLineAlpha(fragCoord.x, 1.0, fragUniforms.u_mmLineThickness, dx);
    float mmLineY = getCenteredLineAlpha(fragCoord.y, 1.0, fragUniforms.u_mmLineThickness, dy);
    float mmGrid = max(mmLineX, mmLineY);

    vec4 backgroundColor = vec4(0.0, 0.0, 0.0, 0.0);

    // Blend the grid lines with the background
    vec4 color = mix(backgroundColor, fragUniforms.u_mmLineColor, mmGrid);
    color = mix(color, fragUniforms.u_minorLineColor, minorGrid);
    color = mix(color, fragUniforms.u_majorLineColor, majorGrid);

    if (color.a < 0.1) {
        discard;
    }

    // Apply standard pre-multiplied alpha formatting so transparency blends with underlying scene nodes
    fragColor = vec4(color.rgb * color.a, color.a);
}
