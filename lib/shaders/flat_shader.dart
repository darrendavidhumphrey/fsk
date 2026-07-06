import '../gl_state_manager.dart';
import '../glsl_shader.dart';

String _vertexShader = '''
          #version 300 es       
          layout (location = 0) in vec3 aVertexPosition;
          layout (location = 1) in vec2 aTextureCoord; 
          layout (location = 2) in vec3 aVertexNormal;      
          layout (location = 3) in vec4 aVertexColor; 

          uniform mat4 uMVMatrix;
          uniform mat4 uPMatrix;

          out vec2 vTextureCoord;  
          out vec4 vColor;

          void main(void) {
              gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
              vTextureCoord = aTextureCoord;
              vColor = aVertexColor; 
          }
''';

String _fragmentShader = '''
#version 300 es
precision highp float;
out vec4 FragColor;

in vec2 vTextureCoord; 
in vec4 vColor; 

uniform sampler2D uSampler;

void main(void) {
    FragColor = vColor; 
}
''';

class FlatShader extends GlslShader {
  FlatShader(GlStateManager gls)
    : super(
        gls,
        _fragmentShader,
        _vertexShader,
        [
          GlslShader.v3Attrib,
          GlslShader.t2Attrib,
          GlslShader.n3Attrib,
          GlslShader.c4Attrib,
        ],
        [GlslShader.uModelView, GlslShader.uProj, GlslShader.textureSamplerAttrib,],
      );
}
