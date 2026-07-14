import 'dart:ui';
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

  late UniformDefinition _patternColor1;
  late UniformDefinition _patternColor2;
  late UniformDefinition _patternScale;
  late UniformDefinition _useTexture;
  late UniformDefinition _textureMix;

  UniformDefinition get patternColor1Location => _patternColor1;
  UniformDefinition get patternColor2Location => _patternColor2;
  UniformDefinition get patternScaleLocation => _patternScale;
  UniformDefinition get useTextureLocation => _useTexture;
  UniformDefinition get textureMixLocation => _textureMix;

  CheckerBoardShader(GlStateManager gls)
    : super(
        gls,
        _fragmentShader,
        _vertexShader,
        [GlslShader.v3Attrib, GlslShader.t2Attrib],
        [
          UniformDefinition(uPatternColor1, UniformType.floatVec4),
          UniformDefinition(uPatternColor2, UniformType.floatVec4),
          UniformDefinition(uPatternScale, UniformType.float),
          UniformDefinition(uUseTexture, UniformType.bool),
          UniformDefinition(uTextureMix, UniformType.float),
          UniformDefinition(
            GlslShader.textureSamplerAttrib,
            UniformType.sampler2D,
          ),
        ],
      ) {

    _patternColor1 = uniforms[uPatternColor1]!;
    _patternColor2 = uniforms[uPatternColor2]!;
    _patternScale = uniforms[uPatternScale]!;
    _useTexture = uniforms[uUseTexture]!;
    _textureMix = uniforms[uTextureMix]!;
    setUseTexture(false);
    setTextureMix(0.0);
  }
  void setPatternColor1(Color color) {
    gls.setUniform4fv(_patternColor1.position!, [
      color.r,
      color.g,
      color.b,
      color.a,
    ]);
  }

  void setPatternColor2(Color color) {
    gls.setUniform4fv(_patternColor2.position!, [
      color.r,
      color.g,
      color.b,
      color.a,
    ]);
  }

  void setPatternScale(num scale) {
    gls.setUniform1f(_patternScale.position!, scale.toDouble());
  }

  void setUseTexture(bool useTexture) {
    gls.setUniform1i(_useTexture.position!, useTexture ? 1 : 0);
  }

  void setTextureMix(num mix) {
    gls.setUniform1f(_textureMix.position!, mix.toDouble());
  }

  @override
  dynamic uniformValueFromString(String name, String value) {
    if (name == uPatternColor1) {
      return(parseHexColor(value));
    } else if (name == uPatternColor2) {
      return(parseHexColor(value));
    } else if (name == uPatternScale) {
      return  double.tryParse(value);
    } else if (name == uUseTexture) {
      return(value.toLowerCase() == 'true' || value == '1');
    } else if (name == uTextureMix) {
      return double.tryParse(value);
    } else {
      return super.uniformValueFromString(name, value);
    }
  }
}
