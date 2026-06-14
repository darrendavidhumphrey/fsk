import 'dart:ui';
import '../gl_state_manager.dart';
import '../glsl_shader.dart';
import 'shaders.dart';

String _vertexShader = '''
#version 300 es
#ifdef GL_ES
precision mediump float;
#endif

layout (location = 0) in vec3 aVertexPosition;
layout (location = 1) in vec2 aTextureCoord;

uniform mat4 uMVMatrix;
uniform mat4 uPMatrix;

out vec2 vTextureCoord;   // Interpolated texture coordinate

void main(void) {
    gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
    vTextureCoord = aTextureCoord;
}
''';

String _fragmentShader = '''
#version 300 es
#ifdef GL_ES
precision mediump float;
#endif

out vec4 FragColor;
in vec2 vTextureCoord;

uniform vec4 uPatternColor1; // Pattern color 1
uniform vec4 uPatternColor2; // Pattern color 2
uniform float uPatternScale; // Scale of the pattern

void main() {
    vec2 tiledCoord = vTextureCoord * uPatternScale;
    vec2 fractionalCoord = fract(tiledCoord); 

    // Check if the fractional part is less than 0.5 for each component
    float checkX = step(0.5, fractionalCoord.x); 
    float checkY = step(0.5, fractionalCoord.y);

    if (checkX != checkY) {
        FragColor = uPatternColor1;
    } else {
        FragColor = uPatternColor2;
    }
}
''';

class CheckerBoardShader extends GlslShader {
  static String uPatternColor1 = "uPatternColor1";
  static String uPatternColor2 = "uPatternColor2";
  static String uPatternScale = "uPatternScale";
  CheckerBoardShader(GlStateManager gls)
    : super(
        gls,
        _fragmentShader,
        _vertexShader,
        [ShaderList.v3Attrib, ShaderList.t2Attrib],
        [
          uPatternColor1,
          uPatternColor2,
          uPatternScale,
          ShaderList.uModelView,
          ShaderList.uProj,
        ],
      );

  void setPatternColor1(Color color) {
    gls.setUniform4f(
      uniforms[uPatternColor1]!,
      color.r,
      color.g,
      color.b,
      color.a,
    );
  }

  void setPatternColor2(Color color) {
    gls.setUniform4f(
      uniforms[uPatternColor2]!,
      color.r,
      color.g,
      color.b,
      color.a,
    );
  }

  void setPatternScale(num scale) {
    gls.setUniform1f(uniforms[uPatternScale]!, scale.toDouble());
  }
}
