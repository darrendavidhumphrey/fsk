#version 460 core

// Input Interface
layout(location = 0) in vec2 vTextureCoord;

// Output Attachment Destination
layout(location = 0) out vec4 FragColor;

// Uniform Block for configuration properties (Binding 3, Set 0)
layout(std140, set = 0, binding = 3) uniform SimpleTextureUniformBlock {
    vec4 uModulateColor;
} fragUniforms;

// Texture Sampler (Binding 4, Set 0)
layout(set = 0, binding = 4) uniform sampler2D uSampler;

void main() {
    // 1. Sample the raw texture pixel
    vec4 texColor = texture(uSampler, vTextureCoord);

    // 2. Modulate the texture color with the uniform color vector
    vec4 combinedColor = texColor * fragUniforms.uModulateColor;

    // 3. Output using native premultiplied alpha formatting.
    // This scales the RGB color channels by the final alpha channel,
    // which prevents dark/white edge halos when transparent objects overlap.
    FragColor = vec4(combinedColor.rgb * combinedColor.a, combinedColor.a);
}
