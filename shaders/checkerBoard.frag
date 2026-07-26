#version 460 core

// Input Interface (Matches vertex location layout indices)
layout(location = 0) in vec2 vTextureCoord;

// Output Attachment Destination
layout(location = 0) out vec4 FragColor;

// Uniform Block Block for configuration properties (Binding 0)
// Preserved exactly to match your current Float32List(12) Dart packing logic
layout(std140, binding = 0) uniform FragmentUniforms {
    vec4 uPatternColor1; // Bytes 0-15  (Indices 0-3)
    vec4 uPatternColor2; // Bytes 16-31 (Indices 4-7)
    vec4 uConfig;        // Bytes 32-47 (Indices 8-11)
// uConfig.x = uUseTexture
// uConfig.y = uTextureMix
// uConfig.z = uPatternScale
// uConfig.w = (unassigned padding)
} fragUniforms;

// Texture Sampler Resource Descriptor Slot (Binding 1)
layout(binding = 1) uniform sampler2D uSampler;

void main() {
    // 🟢 RULE 1: Perform the scale math upfront outside any branch or loop.
    // This forces ImpellerC to retain the 'uConfig.z' uniform variable path.
    vec2 tiledCoord = vTextureCoord * fragUniforms.uConfig.z;
    vec2 fractionalCoord = fract(tiledCoord);

    // Calculate grid step evaluations
    float checkX = step(0.5, fractionalCoord.x);
    float checkY = step(0.5, fractionalCoord.y);

    // Pick procedural base colors
    vec4 proceduralColor = (checkX != checkY) ? fragUniforms.uPatternColor1 : fragUniforms.uPatternColor2;

    // 🟢 RULE 2: Pre-sample the texture unconditionally at the top level.
    // Modern mobile GPUs evaluate textures faster when they aren't hidden inside 'if' branches.
    vec4 texColor = texture(uSampler, vTextureCoord);

    // 🟢 RULE 3: Eliminate execution branching completely!
    // Instead of using an 'if-else' block, use a mathematical mix() flag step.
    // This removes the shader branch and guarantees all scaling parameters execute.
    float textureSelectFlag = step(0.5, fragUniforms.uConfig.x);

    // Blend the procedural background with the texture sample based on textureMix
    vec3 mixedRGB = mix(proceduralColor.rgb, texColor.rgb, fragUniforms.uConfig.y);
    float mixedAlpha = mix(proceduralColor.a, texColor.a, fragUniforms.uConfig.y);

    // Pick between the final texture blend or the pure checkerboard colors
    vec3 finalRGB = mix(proceduralColor.rgb, mixedRGB, textureSelectFlag);
    float finalAlpha = mix(proceduralColor.a, mixedAlpha, textureSelectFlag);

    // Render with native premultiplied alpha formatting
    FragColor = vec4(finalRGB * finalAlpha, finalAlpha);
}
