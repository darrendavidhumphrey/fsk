#version 460 core

layout(location = 0) in vec3 aVertexPosition;
layout(location = 1) in vec2 aTextureCoord;

layout(std140, set = 0, binding = 0) uniform GridVertexUniforms {
    mat4 uMVMatrix;
    mat4 uPMatrix;
} vertUniforms;

layout(location = 0) out vec2 v_uv;

void main(void) {
    gl_Position = vertUniforms.uPMatrix * vertUniforms.uMVMatrix * vec4(aVertexPosition, 1.0);
    v_uv = aTextureCoord;
}
