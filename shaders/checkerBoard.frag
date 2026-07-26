#version 460 core

// Input Interface
layout(location = 0) in vec2 vTextureCoord;

// Output Attachment Destination
layout(location = 0) out vec4 FragColor;

// Shifted to Binding 1 (Set 0) to avoid collisions with the Vertex block
layout(std140, set = 0, binding = 1) uniform FragmentUniforms {
    vec4 uPatternColor1;
    vec4 uPatternColor2;
    float uUseTexture;
    float uTextureMix;
    float uPatternScale;
    float uPadding;
} fragUniforms;

// Shifted to Binding 2 (Set 0)
layout(set = 0, binding = 2) uniform sampler2D uSampler;

void main() {
    vec2 tiledCoord = vTextureCoord * fragUniforms.uPatternScale;
    vec2 fractionalCoord = fract(tiledCoord);

    float checkX = step(0.5, fractionalCoord.x);
    float checkY = step(0.5, fractionalCoord.y);

    vec4 proceduralColor = (checkX != checkY) ? fragUniforms.uPatternColor1 : fragUniforms.uPatternColor2;
    vec4 texColor = texture(uSampler, vTextureCoord);

    float textureSelectFlag = step(0.5, fragUniforms.uUseTexture);

    vec3 mixedRGB = mix(proceduralColor.rgb, texColor.rgb, fragUniforms.uTextureMix);
    float mixedAlpha = mix(proceduralColor.a, texColor.a, fragUniforms.uTextureMix);

    vec3 finalRGB = mix(proceduralColor.rgb, mixedRGB, textureSelectFlag);
    float finalAlpha = mix(proceduralColor.a, mixedAlpha, textureSelectFlag);

    FragColor = vec4(finalRGB * finalAlpha, finalAlpha);
}
