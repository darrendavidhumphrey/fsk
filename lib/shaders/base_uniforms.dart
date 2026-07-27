import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart';

import '../fsk_singleton.dart';

abstract class BaseUniforms with LoggableClass {
  final gpu.Shader? vertexShader;
  final gpu.Shader? fragmentShader;

  String get vertexBlockName => 'VertexUniforms';
  String get fragmentBlockName => 'FragmentUniforms';

  // Shared Vertex Uniform State
  final Matrix4 _mvMatrix = Matrix4.identity();
  final Matrix4 _pMatrix = Matrix4.identity();

  set mvMatrix(Matrix4 value) {
    // FIX: Calling .copyInto forces a strict raw value transfer,
    // breaking the pointer reference thread completely.
    value.copyInto(_mvMatrix);
  }

  set pMatrix(Matrix4 value) {
    value.copyInto(_pMatrix);
  }

  gpu.Texture? _texture;
  String get samplerUniformName => 'uSampler';
  bool get hasSampler => false;

  // Unified string-accessible data registry
  final Map<String, dynamic> _values = {};

  BaseUniforms({this.vertexShader, this.fragmentShader});

  // Dynamic index operator for loose key-value lookup: uniforms['myProperty']
  dynamic operator [](String key) => _values[key];
  void operator []=(String key, dynamic value) => _values[key] = value;

  set texture(gpu.Texture? val) => _texture = val;

  /// Utility method to pack a Flutter color safely into a float array
  int packColor(Float32List targetList, int offset, Color color) {
    targetList[offset++] = color.r;
    targetList[offset++] = color.g;
    targetList[offset++] = color.b;
    targetList[offset++] = color.a;
    return offset;
  }

  /// Implemented by subclasses to serialize their unique string properties
  /// into a precise std140 binary block representation.
  Float32List serializeFragmentData();

  /// Shared engine routine. Compiles and binds both vertex blocks
  /// and custom subclass fragment structures in a single step.
  void bind(gpu.RenderPass renderPass,gpu.HostBuffer transients) {
    if (vertexShader == null || fragmentShader == null) {
      throw StateError(
        'Cannot set uniforms: Vertex and Fragment shaders must be assigned.',
      );
    }

    // =========================================================================
    // 1. REUSABLE VERTEX BLOCK WRITER (Identical across your shaders)
    // =========================================================================
    final Float32List vertexData = Float32List(32);
    vertexData.setAll(0, _mvMatrix.storage);
    vertexData.setAll(16, _pMatrix.storage);

    final gpu.BufferView vertexBufferView = transients.emplace(
      vertexData.buffer.asByteData(),
    );

    final gpu.UniformSlot vertexSlot = vertexShader!.getUniformSlot(
      vertexBlockName,
    );
    renderPass.bindUniform(vertexSlot, vertexBufferView);

    // =========================================================================
    // 2. DYNAMIC SUBCLASS FRAGMENT WRITER
    // =========================================================================
    final Float32List fragmentData = serializeFragmentData();
    final gpu.BufferView fragmentBufferView = transients.emplace(
      fragmentData.buffer.asByteData(),
    );
    final gpu.UniformSlot fragmentSlot = fragmentShader!.getUniformSlot(fragmentBlockName);
    renderPass.bindUniform(fragmentSlot, fragmentBufferView);

    if (hasSampler) {
      final gpu.UniformSlot textureSlot = fragmentShader!.getUniformSlot(
        samplerUniformName,
      );

      final gpu.Texture textureToBind =
          _texture ?? FSK().textureManager.dummyTexture!;
      renderPass.bindTexture(textureSlot, textureToBind);
    }
  }
}
