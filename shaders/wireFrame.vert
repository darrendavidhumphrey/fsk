#version 460 core

layout(location = 0) in vec3 aVertexPosition;
layout(location = 1) in vec2 aTextureCoord;
layout(location = 2) in vec3 aVertexNormal;

layout(std140, set = 0, binding = 0) uniform WireFrameVertexUniforms {
    mat4 uMVMatrix;
    mat4 uPMatrix;
} vertUniforms;

layout(location = 0) out vec2 vTextureCoord;
layout(location = 1) out vec3 vNormal;
layout(location = 2) out vec3 vEyeCoords;
layout(location = 3) out vec3 vBarycentric;

void main(void) {
    vec4 eyeCoords = vertUniforms.uMVMatrix * vec4(aVertexPosition, 1.0);
    vEyeCoords = eyeCoords.xyz;
    vNormal = normalize(mat3(vertUniforms.uMVMatrix) * aVertexNormal);
    vTextureCoord = aTextureCoord;

    int vertexInTriangle = gl_VertexIndex % 3;
    if (vertexInTriangle == 0) {
        vBarycentric = vec3(1.0, 0.0, 0.0);
    } else if (vertexInTriangle == 1) {
        vBarycentric = vec3(0.0, 1.0, 0.0);
    } else {
        vBarycentric = vec3(0.0, 0.0, 1.0);
    }

    gl_Position = vertUniforms.uPMatrix * eyeCoords;
}
