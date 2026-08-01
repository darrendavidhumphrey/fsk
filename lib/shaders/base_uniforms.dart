import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';

import '../fsk_singleton.dart';
import '../logging.dart';

abstract class BaseUniforms with LoggableClass {
  final gpu.Shader? vertexShader;
  final gpu.Shader? fragmentShader;

  String get vertexBlockName => 'VertexUniforms';
  String get fragmentBlockName => 'FragmentUniforms';

  // Shared Vertex Uniform State
  final Matrix4 mvMatrixLocal = Matrix4.identity();
  final Matrix4 pMatrixLocal = Matrix4.identity();

  set mvMatrix(Matrix4 value) {
    value.copyInto(mvMatrixLocal);
  }

  set pMatrix(Matrix4 value) {
    value.copyInto(pMatrixLocal);
  }

  gpu.Texture? textureIn;
  gpu.SamplerOptions? samplerOptions;
  String get samplerUniformName => 'uSampler';
  bool get hasSampler => false;

  set texture(gpu.Texture? val) => textureIn = val;

  // Unified string-accessible data registry
  final Map<String, dynamic> valuesMap = {};

  BaseUniforms({this.vertexShader, this.fragmentShader});

  // Dynamic index operator for loose key-value lookup: uniforms['myProperty']
  dynamic operator [](String key) => valuesMap[key];
  void operator []=(String key, dynamic value) => valuesMap[key] = value;

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
  void bind(gpu.RenderPass renderPass, gpu.HostBuffer transients) {
    if (vertexShader == null || fragmentShader == null) {
      throw StateError(
        'Cannot set uniforms: Vertex and Fragment shaders must be assigned.',
      );
    }

    // =========================================================================
    // 1. REUSABLE VERTEX BLOCK WRITER
    // =========================================================================
    final Float32List vertexData = Float32List(32);
    vertexData.setAll(0, mvMatrixLocal.storage);
    vertexData.setAll(16, pMatrixLocal.storage);

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
    final gpu.UniformSlot fragmentSlot =
        fragmentShader!.getUniformSlot(fragmentBlockName);
    renderPass.bindUniform(fragmentSlot, fragmentBufferView);

    if (hasSampler) {
      final gpu.UniformSlot textureSlot = fragmentShader!.getUniformSlot(
        samplerUniformName,
      );

      final gpu.Texture textureToBind =
          textureIn ?? FSK().textureManager.dummyTexture!;
      renderPass.bindTexture(textureSlot, textureToBind, sampler: samplerOptions);
    }
  }
}
