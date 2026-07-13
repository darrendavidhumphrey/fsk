import 'dart:ui';
import 'package:flutter_angle/shared/classes.dart';

import '../angle/gl_state_manager.dart';
import '../angle/glsl_shader.dart';
import '../util.dart';

String _gridVertexShader = '''
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

String _gridFragmentShader = '''
#version 300 es
#ifdef GL_ES
precision highp float; // You can adjust this based on your needs
#endif

in vec2 v_uv; // Assuming you have UV coordinates passed from the vertex shader
out vec4 fragColor;

uniform vec2 u_resolution; // Resolution of the viewport in pixels
uniform float u_scale;     // Factor to scale the grid (e.g., world units per pixel)

uniform float u_majorLineSpacingMM;  // spacing of major mines in mm
uniform float u_minorLineSpacingMM;  // spacing of minor mines in mm


uniform float u_majorLineThickness;
uniform float u_minorLineThickness;
uniform float u_mmLineThickness;

uniform vec4 u_majorLineColor;   // Major grid color
uniform vec4 u_minorLineColor;   // minor grid color
uniform vec4 u_mmLineColor;      // Color of mm Lines spaced every millimeter  

float getCenteredLineAlpha(float pos, float spacing, float thickness, float fwidthVal) {
    // Adjust the position so the line's center is at 0.0 in a [-spacing/2, spacing/2] range
    float centeredPos = mod(pos + spacing * 0.5, spacing) - spacing * 0.5;

    // The line should be drawn when `centeredPos` is within [-thickness/2, thickness/2]
    // The smoothstep will fade it out at the edges
    float halfThickness = thickness * 0.5;
    
    // The width of the anti-aliasing transition region
    // This makes the transition one "pixel" wide at the current zoom level
    float antiAliasWidth = fwidthVal; 

    // Use smoothstep to create the anti-aliased line
    // The line will be fully opaque when abs(centeredPos) <= halfThickness - antiAliasWidth
    // and fully transparent when abs(centeredPos) >= halfThickness + antiAliasWidth
    float lineAlpha = smoothstep(halfThickness + antiAliasWidth, halfThickness - antiAliasWidth, abs(centeredPos));
    
    return lineAlpha;
}
    
void main() {
    // Convert UV coordinates to screen-space coordinates (or world coordinates)
    vec2 fragCoord = v_uv * u_resolution * u_scale;

    // Use fwidth() for anti-aliasing. {Link: The fwidth() function is equivalent to abs(dFdx(p)) + abs(dFdy(p)), according to Made by Evan https://madebyevan.com/shaders/grid/}
    float dx = fwidth(fragCoord.x);
    float dy = fwidth(fragCoord.y);

    // Anti-alias major lines
    float majorLineX = getCenteredLineAlpha(fragCoord.x, u_majorLineSpacingMM, u_majorLineThickness, dx);
    float majorLineY = getCenteredLineAlpha(fragCoord.y, u_majorLineSpacingMM, u_majorLineThickness, dy);
    float majorGrid = max(majorLineX, majorLineY);
    
    // Anti-alias minor lines
    float minorLineX = getCenteredLineAlpha(fragCoord.x, u_minorLineSpacingMM, u_minorLineThickness, dx);
    float minorLineY = getCenteredLineAlpha(fragCoord.y, u_minorLineSpacingMM, u_minorLineThickness, dy);
    float minorGrid = max(minorLineX, minorLineY);
    
    float mmLineX = getCenteredLineAlpha(fragCoord.x, 1.0, u_mmLineThickness, dx);
    float mmLineY = getCenteredLineAlpha(fragCoord.y, 1.0, u_mmLineThickness, dy);
    float mmGrid = max(mmLineX, mmLineY);
     
    vec4 backgroundColor = vec4(0.0, 0.0, 0.0,0.0);  

    // Blend the grid lines with the background
    vec4 color = mix(backgroundColor, u_mmLineColor, mmGrid);

    color = mix(color, u_minorLineColor, minorGrid);

    color = mix(color, u_majorLineColor, majorGrid);
    if (color.a < 0.1) { // Discard fragments with alpha below a threshold
        discard;
    }
    
    fragColor = vec4(color); // Output the final color
}
''';

class GridShader extends GlslShader {
  static String uResolution = "u_resolution";
  static String uScale = "u_scale";
  static String uMajorLineSpacingMM = "u_majorLineSpacingMM";
  static String uMinorLineSpacingMM = "u_minorLineSpacingMM";
  static String uMajorLineThickness = "u_majorLineThickness";
  static String uMinorLineThickness = "u_minorLineThickness";
  static String ummLineThickness = "u_mmLineThickness";
  static String uMajorLineColor = "u_majorLineColor";
  static String uMinorLineColor = "u_minorLineColor";
  static String ummLineColor = "u_mmLineColor";

  late UniformLocation _resolutionLocation;
  late UniformLocation _scaleLocation;
  late UniformLocation _majorLineSpacingMMLocation;
  late UniformLocation _minorLineSpacingMMLocation;
  late UniformLocation _majorLineThicknessLocation;
  late UniformLocation _minorLineThicknessLocation;
  late UniformLocation _mmLineThicknessLocation;
  late UniformLocation _majorLineColorLocation;
  late UniformLocation _minorLineColorLocation;
  late UniformLocation _mmLineColorLocation;

  GridShader(GlStateManager gls)
    : super(
        gls,
        _gridFragmentShader,
        _gridVertexShader,
        [GlslShader.v3Attrib, GlslShader.t2Attrib],
        [
          GlslShader.uModelView,
          GlslShader.uProj,
          uResolution,
          uScale,
          uMajorLineSpacingMM,
          uMinorLineSpacingMM,
          uMajorLineThickness,
          uMinorLineThickness,
          ummLineThickness,
          uMajorLineColor,
          uMinorLineColor,
          ummLineColor,
        ],
      ) {
    _resolutionLocation = uniforms[uResolution]!;
    _scaleLocation = uniforms[uScale]!;
    _majorLineSpacingMMLocation = uniforms[uMajorLineSpacingMM]!;
    _minorLineSpacingMMLocation = uniforms[uMinorLineSpacingMM]!;
    _majorLineThicknessLocation = uniforms[uMajorLineThickness]!;
    _minorLineThicknessLocation = uniforms[uMinorLineThickness]!;
    _mmLineThicknessLocation = uniforms[ummLineThickness]!;
    _majorLineColorLocation = uniforms[uMajorLineColor]!;
    _minorLineColorLocation = uniforms[uMinorLineColor]!;
    _mmLineColorLocation = uniforms[ummLineColor]!;
  }

  void setResolutionMM(num width, num height) {
    gls.setUniform2fv(_resolutionLocation, [
      width.toDouble() * 10,
      height.toDouble() * 10,
    ]);
  }

  void setScale(num scale) {
    gls.setUniform1f(_scaleLocation, scale.toDouble());
  }

  void setMajorLineSpacingMM(num spacing) {
    gls.setUniform1f(_majorLineSpacingMMLocation, spacing.toDouble());
  }

  void setMinorLineSpacingMM(num spacing) {
    gls.setUniform1f(_minorLineSpacingMMLocation, spacing.toDouble());
  }

  void setMajorLineThickness(num thickness) {
    gls.setUniform1f(_majorLineThicknessLocation, thickness.toDouble());
  }

  void setMinorLineThickness(num thickness) {
    gls.setUniform1f(_minorLineThicknessLocation, thickness.toDouble());
  }

  void setMmLineThickness(num thickness) {
    gls.setUniform1f(_mmLineThicknessLocation, thickness.toDouble());
  }

  void setMajorLineColor(Color color) {
    gls.setUniform4fv(_majorLineColorLocation, [
      color.r,
      color.g,
      color.b,
      color.a,
    ]);
  }

  void setMinorLineColor(Color color) {
    gls.setUniform4fv(_minorLineColorLocation, [
      color.r,
      color.g,
      color.b,
      color.a,
    ]);
  }

  void setMmLineColor(Color color) {
    gls.setUniform4fv(_mmLineColorLocation, [
      color.r,
      color.g,
      color.b,
      color.a,
    ]);
  }


  @override
  void setUniformValue(String name, String value) {
    if (name == uResolution) {
      final v = parseVector2(value);
      setResolutionMM(v.x, v.y);
    } else if (name == uScale) {
      final val = double.tryParse(value);
      if (val != null) setScale(val);
    } else if (name == uMajorLineSpacingMM) {
      final val = double.tryParse(value);
      if (val != null) setMajorLineSpacingMM(val);
    } else if (name == uMinorLineSpacingMM) {
      final val = double.tryParse(value);
      if (val != null) setMinorLineSpacingMM(val);
    } else if (name == uMajorLineThickness) {
      final val = double.tryParse(value);
      if (val != null) setMajorLineThickness(val);
    } else if (name == uMinorLineThickness) {
      final val = double.tryParse(value);
      if (val != null) setMinorLineThickness(val);
    } else if (name == ummLineThickness) {
      final val = double.tryParse(value);
      if (val != null) setMmLineThickness(val);
    } else if (name == uMajorLineColor) {
      setMajorLineColor(parseHexColor(value));
    } else if (name == uMinorLineColor) {
      setMinorLineColor(parseHexColor(value));
    } else if (name == ummLineColor) {
      setMmLineColor(parseHexColor(value));
    }
    else {
      super.setUniformValue(name, value);
    }
  }
}
