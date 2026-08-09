#version 460 core

// Vertex Attributes
layout(location = 0) in vec3 aVertexPosition;
layout(location = 1) in vec2 aTextureCoord;

// Uniform Block (Binding 0, Set 0)
layout(std140, set = 0, binding = 0) uniform SimpleTextureVertexUniforms {
    mat4 uMVMatrix;
    mat4 uPMatrix;
} vertUniforms;

// Output Interface
layout(location = 0) out vec2 vTextureCoord;

void main(void) {
    vec4 position = vertUniforms.uPMatrix * vertUniforms.uMVMatrix * vec4(aVertexPosition, 1.0);

    gl_Position = position;
    vTextureCoord = aTextureCoord;
}
