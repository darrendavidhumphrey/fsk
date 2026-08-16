#version 460 core

layout(location = 0) in vec3 aVertexPosition;
layout(location = 1) in vec2 aTextureCoord;
layout(location = 2) in vec3 aVertexNormal;
layout(location = 3) in vec4 aVertexColor; // Baked barycentrics (r,g,b)

layout(std140, set = 0, binding = 0) uniform WireFrameVertexUniforms {
    mat4 uMVMatrix;
    mat4 uPMatrix;
} vertUniforms;

layout(location = 0) out vec2 vTextureCoord;
layout(location = 1) out vec4 vNormal;
layout(location = 2) out vec4 vEyeCoords;
layout(location = 3) out vec4 vBarycentric;

void main(void) {
    vec4 pos = vec4(aVertexPosition, 1.0);
    vec4 eyeCoords = vertUniforms.uMVMatrix * pos;
    vEyeCoords = eyeCoords;
    vNormal = vec4(normalize(mat3(vertUniforms.uMVMatrix) * aVertexNormal), 0.0);
    vTextureCoord = aTextureCoord;

    // Pass baked barycentric coordinates
    vBarycentric = aVertexColor;

    gl_Position = vertUniforms.uPMatrix * eyeCoords;
}
