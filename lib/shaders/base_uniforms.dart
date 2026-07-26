import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';

abstract class BaseUniforms {
  final gpu.Shader? vertexShader;
  final gpu.Shader? fragmentShader;

  // Shared Vertex Uniform State
  Matrix4 mvMatrix = Matrix4.identity();
  Matrix4 pMatrix = Matrix4.identity();

  // Unified string-accessible data registry
  final Map<String, dynamic> _values = {};

  BaseUniforms({this.vertexShader, this.fragmentShader});

  // Dynamic index operator for loose key-value lookup: uniforms['myProperty']
  dynamic operator [](String key) => _values[key];
  void operator []=(String key, dynamic value) => _values[key] = value;

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
  void bind(gpu.RenderPass renderPass) {
    if (vertexShader == null || fragmentShader == null) {
      throw StateError('Cannot set uniforms: Vertex and Fragment shaders must be assigned.');
    }

    final gpu.HostBuffer transients = gpu.gpuContext.createHostBuffer();

    // =========================================================================
    // 1. REUSABLE VERTEX BLOCK WRITER (Identical across your shaders)
    // =========================================================================
    final Float32List vertexData = Float32List(32);
    vertexData.setAll(0, mvMatrix.storage);
    vertexData.setAll(16, pMatrix.storage);

    final gpu.BufferView vertexBufferView = transients.emplace(vertexData.buffer.asByteData());
    final gpu.UniformSlot vertexSlot = vertexShader!.getUniformSlot('VertexUniforms');
    renderPass.bindUniform(vertexSlot, vertexBufferView);

    // =========================================================================
    // 2. DYNAMIC SUBCLASS FRAGMENT WRITER
    // =========================================================================
    final Float32List fragmentData = serializeFragmentData();
    final gpu.BufferView fragmentBufferView = transients.emplace(fragmentData.buffer.asByteData());
    final gpu.UniformSlot fragmentSlot = fragmentShader!.getUniformSlot('FragmentUniforms');
    renderPass.bindUniform(fragmentSlot, fragmentBufferView);
  }
}
