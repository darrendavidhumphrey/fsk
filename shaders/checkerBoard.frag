#version 460 core

// Input Interface (Matches vertex location layout indices)
layout(location = 0) in vec2 vTextureCoord;

// Output Attachment Destination
layout(location = 0) out vec4 FragColor;

// Uniform Block Block for configuration properties (Binding 0)
// Pack configuration parameters into a single vec4 to guarantee memory alignment
layout(std140, binding = 0) uniform FragmentUniforms {
    vec4 uPatternColor1; // Offset 0  (Bytes 0-15)
    vec4 uPatternColor2; // Offset 16 (Bytes 16-31)
    vec4 uConfig;        // Offset 32 (Bytes 32-47)
// uConfig.x = uUseTexture
// uConfig.y = uTextureMix
// uConfig.z = uPatternScale
// uConfig.w = (unassigned padding)
} fragUniforms;

// Texture Sampler Resource Descriptor Slot (Binding 1)
layout(binding = 1) uniform sampler2D uSampler;

void main() {
    // Read the pattern scale cleanly from the config vector's Z component
    vec2 tiledCoord = vTextureCoord * fragUniforms.uConfig.z;
    vec2 fractionalCoord = fract(tiledCoord);

    // Check if the fractional part is less than 0.5 for each component
    float checkX = step(0.5, fractionalCoord.x);
    float checkY = step(0.5, fractionalCoord.y);

    vec4 color;
    if (checkX != checkY) {
        color = fragUniforms.uPatternColor1;
    } else {
        color = fragUniforms.uPatternColor2;
    }

    // Read the texture toggle flag from the config vector's X component
    if (fragUniforms.uConfig.x > 0.5) {
        vec4 texColor = texture(uSampler, vTextureCoord);
        // Read the texture mix percentage from the config vector's Y component
        vec3 blendedRGB = mix(color.rgb, texColor.rgb, fragUniforms.uConfig.y);
        float alpha = texColor.a;
        FragColor = vec4(blendedRGB * alpha, alpha);
    } else {
        FragColor = vec4(color.rgb * color.a, color.a);
    }
}
