#version 460 core

// Input Interface (Matches vertex location layout indices perfectly)
layout(location = 0) in vec2 vTextureCoord;

// Output Attachment Destination
layout(location = 0) out vec4 FragColor;

// Uniform Block for configuration properties (Binding 1, Set 0)
layout(std140, set = 0, binding = 1) uniform FragmentUniforms {
    vec4 uModulateColor;
} fragUniforms;

// Texture Sampler Resource Descriptor Slot (Binding 2, Set 0)
layout(set = 0, binding = 2) uniform sampler2D uSampler;

void main() {
    vec4 texColor = texture(uSampler, vTextureCoord);

    // Combine texture color with modulation uniform
    vec4 combinedColor = texColor * fragUniforms.uModulateColor;

    // Render with native premultiplied alpha formatting
    FragColor = vec4(combinedColor.rgb * combinedColor.a, combinedColor.a);
}