#version 450 core

// Match the layout definitions explicitly
layout(location = 0) in vec3 aVertexPosition;
layout(location = 1) in vec2 aTextureCoord;
layout(location = 2) in vec3 aNormal;
layout(location = 3) in vec4 aColor;

// Uniforms must be wrapped in a uniform block
layout(binding = 0) uniform TransformBlock {
    mat4 uMVMatrix;
    mat4 uPMatrix;
};


layout(location = 0) out vec2 v_uv;

void main(void) {
    gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);

    v_uv = aTextureCoord;
}