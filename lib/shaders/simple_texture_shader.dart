import 'dart:ui';

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
uniform vec4 uModulateColor;

void main(void) {
    vec4 texColor = texture(uSampler, v_uv);
    
    // Modulates the quad texture color
    FragColor = texColor * uModulateColor; 
}
''';

class SimpleTextureShader extends GlslShader {
  static String uModulateColor = "uModulateColor";

  late UniformDefinition _modulateColor;
  UniformDefinition get modulateColor => _modulateColor;

  SimpleTextureShader(GlStateManager gls)
    : super(
        gls,
        _fragmentShader,
        _vertexShader,
        [GlslShader.v3Attrib, GlslShader.t2Attrib],
        [
          UniformDefinition(GlslShader.textureSamplerAttrib,UniformType.sampler2D),
          UniformDefinition(uModulateColor,UniformType.floatVec4),
        ],
      ) {
    _modulateColor = uniforms[uModulateColor]!;
  }

  void setModulateColor(Color color) {
    gls.setUniform4fv(_modulateColor.position!, [
      color.r,
      color.g,
      color.b,
      color.a,
    ]);
  }

  @override
  dynamic uniformValueFromString(String name, String value) {
    if (name == uModulateColor) {
     return parseHexColor(value);
    } else {
      return super.uniformValueFromString(name, value);
    }
  }
}
