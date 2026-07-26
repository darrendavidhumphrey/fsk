#version 460 core

// Input Interface (Matches vertex location layout indices perfectly)
layout(location = 0) in vec2 vTextureCoord;
layout(location = 1) in vec4 vColor;

// Output Attachment Destination
layout(location = 0) out vec4 FragColor;

layout(std140, set = 0, binding = 1) uniform FragmentUniforms {
    vec4 uModulateColor;
} fragUniforms;

void main() {
    // Combine vertex color with modulation uniform
    vec4 combinedColor = vColor * fragUniforms.uModulateColor;

    // Render with native premultiplied alpha formatting
    FragColor = vec4(combinedColor.rgb * combinedColor.a, combinedColor.a);
}
