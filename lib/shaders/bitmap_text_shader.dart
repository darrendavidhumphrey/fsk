import 'dart:ui';
import 'package:flutter_angle/shared/classes.dart';

import '../angle/gl_state_manager.dart';
import '../angle/glsl_shader.dart';
import '../util.dart';

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

  late UniformLocation _textColorLocation;

  BitmapTextShader(GlStateManager gls)
    : super(
        gls,
        _fragmentShader,
        _vertexShader,
        [GlslShader.v3Attrib, GlslShader.t2Attrib],
        [
          GlslShader.uModelView,
          GlslShader.uProj,
          GlslShader.textureSamplerAttrib,
          uTextColor,
        ],
      ) {
    _textColorLocation = uniforms[uTextColor]!;
  }

  void setTextColor(Color color) {
    gls.setUniform4fv(_textColorLocation, [color.r, color.g, color.b, color.a]);
  }

  @override
  void setUniformValue(String name, String value) {
    if (name == uTextColor) {
      setTextColor(parseHexColor(value));
    } else {
      super.setUniformValue(name, value);
    }
  }
}
