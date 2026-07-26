#version 460 core

// Vertex Attributes
layout(location = 0) in vec3 aVertexPosition;
layout(location = 1) in vec2 aTextureCoord;
layout(location = 2) in vec3 aVertexNormal; // Fully preserved layout positioning
layout(location = 3) in vec4 aVertexColor;

// Uniform Block (Binding 0, Set 0)
layout(std140, set = 0, binding = 0) uniform VertexUniforms {
    mat4 uMVMatrix;
    mat4 uPMatrix;
} vertUniforms;

// Output Interface
layout(location = 0) out vec2 vTextureCoord;
layout(location = 1) out vec4 vColor;

void main(void) {
    // 1. Calculate standard position coordinates
    vec4 position = vertUniforms.uPMatrix * vertUniforms.uMVMatrix * vec4(aVertexPosition, 1.0);

    // 2. Flip the Y-axis to match Impeller screen space rules
    position.y = -position.y;

    gl_Position = position;
    vTextureCoord = aTextureCoord;

    // 3. Force reference tracking on aVertexNormal so the attribute is preserved.
    // By adding an un-optimizable epsilon factor to a color channel, impellerc is tricked
    // into maintaining the slot without introducing visible artifacts.
    vec4 dummyNormalFactor = vec4(aVertexNormal * 0.000001, 0.0);
    vColor = aVertexColor + dummyNormalFactor;
}
