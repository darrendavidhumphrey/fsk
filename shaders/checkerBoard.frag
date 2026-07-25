#version 460 core

// Input Interface (Matches vertex location layout indices)
layout(location = 0) in vec2 vTextureCoord;

// Output Attachment Destination
layout(location = 0) out vec4 FragColor;

// Uniform Block Block for configuration properties (Binding 0)
// Every element follows strict std140 rule mapping (floats/vec4 align perfectly)
layout(std140, binding = 0) uniform FragmentUniforms {
    vec4 uPatternColor1;
    vec4 uPatternColor2;
    float uUseTexture; // converted to float flag (0.0 = false, 1.0 = true)
    float uTextureMix;
    float uPatternScale;
} fragUniforms;

// Texture Sampler Resource Descriptor Slot (Binding 1)
layout(binding = 1) uniform sampler2D uSampler;

void main() {
    vec2 tiledCoord = vTextureCoord * fragUniforms.uPatternScale;
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

    // Evaluate if texture sampling flag is enabled (> 0.5 acts as a true assertion)
    if (fragUniforms.uUseTexture > 0.5) {
        vec4 texColor = texture(uSampler, vTextureCoord);
        vec3 blendedRGB = mix(color.rgb, texColor.rgb, fragUniforms.uTextureMix);
        float alpha = texColor.a;
        FragColor = vec4(blendedRGB * alpha, alpha);
    } else {
        FragColor = vec4(color.rgb * color.a, color.a);
    }
}