import 'dart:ui';

import 'package:flutter_angle/flutter_angle.dart';
import '../glsl_shader.dart';
import 'shaders.dart';

String _vertexShader = '''
#version 300 es
precision mediump float;
layout (location = 0) in vec3 aVertexPosition;
layout (location = 1) in vec2 aTextureCoord;

uniform mat4 uMVMatrix;
uniform mat4 uPMatrix;

out vec2 v_uv;
void main(void) {
    gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
    v_uv = aTextureCoord;
}
''';

String _fragmentShader = '''
#version 300 es
precision highp float;
out vec4 FragColor;

in vec2 v_uv; 

uniform sampler2D uSampler;
uniform vec4 uTextColor;

void main(void) {
    vec4 texColor = texture(uSampler, v_uv);
    FragColor = texColor * uTextColor; // Modulates the quad texture color
}
''';

class BitmapTextShader extends GlslShader {

  static String uTextColor = "uTextColor";

  BitmapTextShader(RenderingContext gl)
      : super(
    RenderingContextWrapper(gl),
    _fragmentShader,
    _vertexShader,
    [ShaderList.v3Attrib,
      ShaderList.t2Attrib,
    ],
    [
      ShaderList.uModelView, ShaderList.uProj,ShaderList.textureSamplerAttrib,uTextColor
    ],
  );
  void setTextColor(Color color) {
    gl.uniform4fv(uniforms[uTextColor]!, [color.r, color.g, color.b, color.a]);
  }
  void setTextureSampler(int unit) {
    gl.uniform1i(uniforms[ShaderList.textureSamplerAttrib]!, unit);
  }
}
