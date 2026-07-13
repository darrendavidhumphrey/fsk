import 'dart:ui';
import 'package:flutter_angle/shared/classes.dart';

import '../angle/gl_state_manager.dart';
import '../angle/glsl_shader.dart';
import '../util.dart';

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

uniform sampler2D uSampler;
uniform bool uUseTexture;
uniform float uTextureMix; // 0.0 = pattern only, 1.0 = texture only
uniform vec4 uPatternColor1; // Pattern color 1
uniform vec4 uPatternColor2; // Pattern color 2
uniform float uPatternScale; // Scale of the pattern

void main() {
    vec2 tiledCoord = vTextureCoord * uPatternScale;
    vec2 fractionalCoord = fract(tiledCoord); 

    // Check if the fractional part is less than 0.5 for each component
    float checkX = step(0.5, fractionalCoord.x); 
    float checkY = step(0.5, fractionalCoord.y);

    vec4 color;
    if (checkX != checkY) {
        color = uPatternColor1;
    } else {
        color = uPatternColor2;
    }
    
    if (uUseTexture) {
        vec4 texColor = texture(uSampler, vTextureCoord);
        vec3 blendedRGB = mix(color.rgb, texColor.rgb, uTextureMix);
        float alpha = texColor.a;
        FragColor = vec4(blendedRGB * alpha, alpha);
    } else {
        FragColor = vec4(color.rgb * color.a, color.a);
    }
}
''';

class CheckerBoardShader extends GlslShader {
  static String uPatternColor1 = "uPatternColor1";
  static String uPatternColor2 = "uPatternColor2";
  static String uPatternScale = "uPatternScale";
  static String uUseTexture = "uUseTexture";
  static String uTextureMix = "uTextureMix";

  late UniformLocation _patternColor1Location;
  late UniformLocation _patternColor2Location;
  late UniformLocation _patternScaleLocation;
  late UniformLocation _useTextureLocation;
  late UniformLocation _textureMixLocation;

  CheckerBoardShader(GlStateManager gls)
    : super(
        gls,
        _fragmentShader,
        _vertexShader,
        [GlslShader.v3Attrib, GlslShader.t2Attrib],
        [
          uPatternColor1,
          uPatternColor2,
          uPatternScale,
          uUseTexture,
          uTextureMix,
          GlslShader.uModelView,
          GlslShader.uProj,
          GlslShader.textureSamplerAttrib,
        ],
      ) {
    _patternColor1Location = uniforms[uPatternColor1]!;
    _patternColor2Location = uniforms[uPatternColor2]!;
    _patternScaleLocation = uniforms[uPatternScale]!;
    _useTextureLocation = uniforms[uUseTexture]!;
    _textureMixLocation = uniforms[uTextureMix]!;
    setUseTexture(false);
    setTextureMix(0.0);
  }
  void setPatternColor1(Color color) {
    gls.setUniform4fv(_patternColor1Location, [
      color.r,
      color.g,
      color.b,
      color.a,
    ]);
  }

  void setPatternColor2(Color color) {
    gls.setUniform4fv(_patternColor2Location, [
      color.r,
      color.g,
      color.b,
      color.a,
    ]);
  }

  void setPatternScale(num scale) {
    gls.setUniform1f(_patternScaleLocation, scale.toDouble());
  }

  void setUseTexture(bool useTexture) {
    gls.setUniform1i(_useTextureLocation, useTexture ? 1 : 0);
  }

  void setTextureMix(num mix) {
    gls.setUniform1f(_textureMixLocation, mix.toDouble());
  }

  @override
  void setUniformValue(String name, String value) {
    if (name == uPatternColor1) {
      setPatternColor1(parseHexColor(value));
    } else if (name == uPatternColor2) {
      setPatternColor2(parseHexColor(value));
    } else if (name == uPatternScale) {
      final val = double.tryParse(value);
      if (val != null) setPatternScale(val);
    } else if (name == uUseTexture) {
      setUseTexture(value.toLowerCase() == 'true' || value == '1');
    } else if (name == uTextureMix) {
      final val = double.tryParse(value);
      if (val != null) setTextureMix(val);
    } else {
      super.setUniformValue(name, value);
    }
  }

}
