import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'gl_state_manager.dart';
import 'logging.dart';

/// A class that encapsulates a WebGL shader program.
class GlslShader with LoggableClass {

  // --- Shared Attribute Names ---
  // Use these constants when possible
  static const String v3Attrib = "aVertexPosition";
  static const String c4Attrib = "aVertexColor";
  static const String t2Attrib = "aTextureCoord";
  static const String n3Attrib = "aVertexNormal";

  // --- Shared Uniform Names ---
  // Use these constants when possible
  static const String uModelView = "uMVMatrix";
  static const String uProj = "uPMatrix";
  static const String uNormal = "uNMatrix";
  static const String textureSamplerAttrib = 'uSampler';

  final Map<String, int> _attributes = <String, int>{};
  final Map<String, UniformLocation> _uniforms = <String, UniformLocation>{};
  Program? program;

  final GlStateManager gls;
  final List<String> attributeNames;
  final List<String> uniformNames;
  final int _sourceHashCode;

  Map<String, int> get attributes => UnmodifiableMapView(_attributes);
  Map<String, UniformLocation> get uniforms => UnmodifiableMapView(_uniforms);

  GlslShader(
    this.gls,
    String fragSrc,
    String vertSrc,
    this.attributeNames,
    this.uniformNames,
  ) : _sourceHashCode = Object.hash(fragSrc, vertSrc) {
    _compileAndLink(fragSrc, vertSrc);
  }

  void _compileAndLink(String fragSrc, String vertSrc) {
    dynamic fragShader;
    dynamic vertShader;
    try {
      fragShader = _compileShader(WebGL.FRAGMENT_SHADER, fragSrc);
      vertShader = _compileShader(WebGL.VERTEX_SHADER, vertSrc);

      RenderingContext gl = gls.gl;
      final p = gl.createProgram();
      program = p;
      gl.attachShader(p, vertShader);
      gl.attachShader(p, fragShader);
      gl.linkProgram(p);
      bool success = false;
      var successVal = gl.getProgramParameter(p, WebGL.LINK_STATUS).id;

      if (successVal is bool) {
        success = gl.getProgramParameter(p, WebGL.LINK_STATUS).id;
      } else {
        success = (gl.getProgramParameter(p, WebGL.LINK_STATUS).id == 1);
      }

      if (!success) {
        throw Exception(
            'Shader program linking failed: ${gl.getProgramInfoLog(p) ?? ''}');
      }

      _fetchAttributeAndUniformLocations(p);
    } catch (e) {
      logError('Error creating GlslShader: $e');
      dispose();
      rethrow;
    } finally {
      if (vertShader != null) gls.gl.deleteShader(vertShader);
      if (fragShader != null) gls.gl.deleteShader(fragShader);
    }
  }

  dynamic _compileShader(int type, String source) {
    RenderingContext gl = gls.gl;
    final shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);

    if (gl.getShaderParameter(shader, WebGL.COMPILE_STATUS) != true) {
      final error =
          'Shader compilation failed (${type == WebGL.VERTEX_SHADER ? 'Vertex' : 'Fragment'}): ${gl.getShaderInfoLog(shader) ?? ''}';
      gl.deleteShader(shader);
      throw Exception(error);
    }
    return shader;
  }

  void _fetchAttributeAndUniformLocations(Program p) {
    RenderingContext gl = gls.gl;
    for (String attrib in attributeNames) {
      int attributeLocation = gl.getAttribLocation(p, attrib).id;
      gl.checkError(attrib);


      if (attributeLocation < 0) {
        logError("GL Failed to get attribute $attrib");
      }
      else {
        gl.enableVertexAttribArray(attributeLocation);
      }
        _attributes[attrib] = attributeLocation;
    }
    for (String uniform in uniformNames) {
      var uniformLocation = gl.getUniformLocation(p, uniform);
      gl.checkError(uniform);
      _uniforms[uniform] = UniformLocation(uniformLocation.id);
    }
  }

  void dispose() {
    final p = program;
    if (p != null) {
      gls.gl.deleteProgram(p);
      program = null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GlslShader &&
        other.runtimeType == runtimeType &&
        other.gls == gls &&
        other._sourceHashCode == _sourceHashCode &&
        listEquals(other.attributeNames, attributeNames) &&
        listEquals(other.uniformNames, uniformNames);
  }

  @override
  int get hashCode => Object.hash(
    gls,
    _sourceHashCode,
    Object.hashAll(attributeNames),
    Object.hashAll(uniformNames),
  );

  void setUniform1i(String name, int value) {
    gls.setUniform1i(uniforms[name]!, value);
  }

  void setTextureSampler(int unit) {
    gls.setUniform1i(uniforms[GlslShader.textureSamplerAttrib]!, unit);
  }
}
