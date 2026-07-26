#version 460 core

// Output Attachment Destination
layout(location = 0) out vec4 FragColor;

// Uniform Block Block for configuration properties (Binding 1, Set 0)
// Follows strict std140 rule mapping (exactly 16 bytes / one vec4 block)
layout(std140, set = 0, binding = 1) uniform FragmentUniforms {
    vec4 uColor;
} fragUniforms;

void main() {
    // Outputs the uniform color using standard premultiplied alpha
    // to match Flutter's native blending expectations.
    FragColor = vec4(fragUniforms.uColor.rgb * fragUniforms.uColor.a, fragUniforms.uColor.a);
}