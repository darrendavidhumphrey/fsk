import 'dart:collection';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:vector_math/vector_math_64.dart';
import '../util.dart';
import 'gl_state_manager.dart';
import '../logging.dart';

/// Standard OpenGL ES uniform types
enum UniformType {
  float,
  floatVec2,
  floatVec3,
  floatVec4,
  int,
  intVec2,
  intVec3,
  intVec4,
  bool,
  boolVec2,
  boolVec3,
  boolVec4,
  floatMat2,
  floatMat3,
  floatMat4,
  sampler2D,
  samplerCube,
}

class UniformDefinition {
  final String name;
  UniformLocation? position;
  final UniformType type;
  UniformDefinition(this.name, this.type);

  @override
  String toString() {
    return "UniformDefinition($name, $type)";
  }
}

class UniformValue {
  final UniformDefinition definition;
  dynamic value;

  UniformValue(this.definition, this.value);
}

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
  final Map<String, UniformDefinition> _uniforms =
      <String, UniformDefinition>{};
  Program? program;

  final GlStateManager gls;
  final List<String> attributeNames;
  final List<UniformDefinition> uniformDefinitions;
  final int _sourceHashCode;

  Map<String, int> get attributes => UnmodifiableMapView(_attributes);
  Map<String, UniformDefinition> get uniforms => UnmodifiableMapView(_uniforms);

  // Common uniforms
  late UniformDefinition _uModelView;
  late UniformDefinition _uProj;
  late UniformDefinition _uTextureSampler;

  GlslShader(
    this.gls,
    String fragSrc,
    String vertSrc,
    this.attributeNames,
    this.uniformDefinitions,
  ) : _sourceHashCode = Object.hash(fragSrc, vertSrc) {
    // Manually add matrices to all shaders
    _uModelView = UniformDefinition(uModelView, UniformType.floatMat4);
    _uProj = UniformDefinition(uProj, UniformType.floatMat4);
    _uTextureSampler = UniformDefinition(
      textureSamplerAttrib,
      UniformType.sampler2D,
    );
    uniformDefinitions.add(_uModelView);
    uniformDefinitions.add(_uProj);
    uniformDefinitions.add(_uTextureSampler);

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
          'Shader program linking failed: ${gl.getProgramInfoLog(p) ?? ''}',
        );
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
      } else {
        gl.enableVertexAttribArray(attributeLocation);
      }
      _attributes[attrib] = attributeLocation;
    }
    for (var uniform in uniformDefinitions) {
      var uniformLocation = gl.getUniformLocation(p, uniform.name);
      gl.checkError(uniform.name);
      uniform.position = UniformLocation(uniformLocation.id);

      _uniforms[uniform.name] = uniform;
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
        listEquals(other.uniformDefinitions, uniformDefinitions);
  }

  @override
  int get hashCode => Object.hash(
    gls,
    _sourceHashCode,
    Object.hashAll(attributeNames),
    Object.hashAll(uniformDefinitions),
  );

  void setTextureSampler(int unit) {
    if (_uTextureSampler.position != null) {
      gls.setUniform1i(_uTextureSampler.position!, unit);
    }
  }

  dynamic uniformValueFromString(String name, String value) {
    if (name == GlslShader.textureSamplerAttrib) {
      return int.tryParse(value);
    } else {
      logWarning("setUniformValue not implemented for uniform $name");
      return null;
    }
  }

  void setUniform(UniformDefinition uniform, dynamic value) {
    var position = uniform.position!;

    switch (uniform.type) {
      case UniformType.float:
        gls.setUniform1f(position, value as double);
        break;
      case UniformType.floatVec2:
        final v = value as Vector2;
        gls.setUniform2fv(position, v.storage);
        break;
      case UniformType.floatVec3:
        final v = value as Vector3;
        gls.setUniform3fv(position, v.storage);
        break;
      case UniformType.floatVec4:
        if (value is Color) {
          final v = colorToVector(value);
          gls.setUniform4fv(position, v.storage);
        } else {
          final v = value as Vector4;
          gls.setUniform4fv(position, v.storage);
        }
        break;

      case UniformType.int:
      case UniformType.sampler2D:
      case UniformType.samplerCube:
        gls.setUniform1i(position, value as int);
        break;
      case UniformType.intVec2:
        final v = value as List<int>;
        gls.setUniform2iv(position, v);
        break;
      case UniformType.intVec3:
        final v = value as List<int>;
        gls.setUniform3iv(position, v);
        break;
      case UniformType.intVec4:
        final v = value as List<int>;
        gls.setUniform4iv(position, v);
        break;

      case UniformType.bool:
        gls.setUniform1i(position, (value as bool) ? 1 : 0);
        break;
      case UniformType.boolVec2:
        final v = value as List<bool>;
        final listInt = [v[0] ? 1 : 0, v[1] ? 1 : 0];
        gls.setUniform2iv(position, listInt);
        break;
      case UniformType.boolVec3:
        final v = value as List<bool>;
        final listInt = [v[0] ? 1 : 0, v[1] ? 1 : 0, v[2] ? 1 : 0];
        gls.setUniform3iv(position, listInt);
        break;
      case UniformType.boolVec4:
        final v = value as List<bool>;
        final listInt = [
          v[0] ? 1 : 0,
          v[1] ? 1 : 0,
          v[2] ? 1 : 0,
          v[3] ? 1 : 0,
        ];
        gls.setUniform4iv(position, listInt);
        break;

      case UniformType.floatMat2:
        // Expects a Float32List or List<double> of length 4
        gls.setUniformMatrix2fv(position, value as Matrix2);
        break;
      case UniformType.floatMat3:
        // Expects a Float32List or List<double> of length 9
        gls.setUniformMatrix3fv(position, value as Matrix3);
        break;
      case UniformType.floatMat4:
        // Expects a Float32List or List<double> of length 16
        gls.setUniformMatrix4fv(position, value as Matrix4);
        break;
    }
  }

  /// A utility to set the standard model-view and projection matrices on a shader.
  void setMatrixUniforms(Matrix4 pMatrix, Matrix4 mvMatrix) {
    gls.setUniformMatrix4fv(_uProj.position!, pMatrix);
    gls.setUniformMatrix4fv(_uModelView.position!, mvMatrix);
  }
}
