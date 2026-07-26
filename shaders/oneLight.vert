#version 460 core

// Vertex Attributes
layout(location = 0) in vec3 aVertexPosition;
layout(location = 1) in vec2 aTextureCoord;
layout(location = 2) in vec3 aVertexNormal;

// Uniform Block (Binding 0, Set 0)
layout(std140, set = 0, binding = 0) uniform VertexUniforms {
    mat4 uMVMatrix;
    mat4 uPMatrix;
} vertUniforms;

// Output Interface
layout(location = 0) out vec2 vTextureCoord;
layout(location = 1) out vec3 vNormal;
layout(location = 2) out vec3 vEyeCoords;
layout(location = 3) out vec3 vBarycentric;

void main(void) {
    vec4 eyeCoords = vertUniforms.uMVMatrix * vec4(aVertexPosition, 1.0);
    vEyeCoords = eyeCoords.xyz;
    vNormal = normalize(mat3(vertUniforms.uMVMatrix) * aVertexNormal);
    vTextureCoord = aTextureCoord;

    // Generate barycentric coordinates for wireframe/outline effect
    int vertexInTriangle = gl_VertexIndex % 3;
    if (vertexInTriangle == 0) {
        vBarycentric = vec3(1.0, 0.0, 0.0);
    } else if (vertexInTriangle == 1) {
        vBarycentric = vec3(0.0, 1.0, 0.0);
    } else {
        vBarycentric = vec3(0.0, 0.0, 1.0);
    }

    vec4 position = vertUniforms.uPMatrix * eyeCoords;
    position.y = -position.y; // Fix Impeller Y-axis conversion
    gl_Position = position;
}