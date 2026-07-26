import 'package:flutter/foundation.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;

import '../fsk_singleton.dart';

/// Maps to modern Uniform Bindings rather than individual loose WebGL properties.
///
/// In flutter_gpu, uniforms must live inside structured blocks (except Samplers).
enum UniformType {
  uniformBlock, // Used to hold matrices, vectors, arrays, or floats together
  sampler2D, // Textures require explicit standalone layout bindings
}

class UniformDefinition {
  final String name;
  final UniformType type;
  gpu.UniformSlot?
  slot; // Holds the runtime pipeline memory registration binding index

  UniformDefinition(this.name, this.type);

  /// Deep copies a definition so vertex and fragment stages can have isolated slots
  UniformDefinition clone() => UniformDefinition(name, type);

  @override
  String toString() => "UniformDefinition($name, $type)";
}

/// Encapsulates an immutable ahead-of-time compiled flutter_gpu RenderPipeline structure.
class GpuShader {
  // --- Shared Attribute Location Mapping Indices (Determined by AOT Shader Layouts) ---
  static const int positionLocation = 0;
  static const int colorLocation = 1;
  static const int texCoordLocation = 2;
  static const int normalLocation = 3;

  // --- Shared Uniform Block Identifiers ---
  static const String uTransformBlock =
      "TransformBlock"; // Holds your combined mat4 projection variables
  static const String textureSamplerAttrib =
      "uSampler"; // Target identifier for the texture image map

  gpu.RenderPipeline? pipeline;
  final String _vertexKey;
  final String _fragmentKey;

  // Track configurations passed into constructor to resolve during initialization
  final List<UniformDefinition> _pendingUniforms = [];

  // Separate, stage-isolated slot maps
  final Map<String, UniformDefinition> _vertexUniforms =
      <String, UniformDefinition>{};
  final Map<String, UniformDefinition> _fragmentUniforms =
      <String, UniformDefinition>{};

  Map<String, UniformDefinition> get vertexUniforms =>
      Map.unmodifiable(_vertexUniforms);
  Map<String, UniformDefinition> get fragmentUniforms =>
      Map.unmodifiable(_fragmentUniforms);

  GpuShader({
    required this._vertexKey,
    required this._fragmentKey,
    List<UniformDefinition>? extraUniforms,
  }) {
    // Seed default common uniforms for tracking evaluation rules
    _pendingUniforms.add(
      UniformDefinition(uTransformBlock, UniformType.uniformBlock),
    );
    _pendingUniforms.add(
      UniformDefinition(textureSamplerAttrib, UniformType.sampler2D),
    );

    if (extraUniforms != null) {
      _pendingUniforms.addAll(extraUniforms);
    }
  }

  /// Asynchronously loads pre-compiled AOT binary headers and registers the pipeline layout state.
  Future<bool> initializePipeline() async {
    try {

      final vertexShader = FSK().shaderLibrary![_vertexKey];
      final fragmentShader = FSK().shaderLibrary![_fragmentKey];

      if (vertexShader == null || fragmentShader == null) {
        debugPrint('Error: Missing shader keys inside asset dictionary.');
        return false;
      }

      pipeline = gpu.gpuContext.createRenderPipeline(
        vertexShader,
        fragmentShader,
      );

      // Loop definitions through both shader components to build cleanly separated maps
      for (var definition in _pendingUniforms) {
        // Evaluate Vertex Shader bindings
        final gpu.UniformSlot vSlot = vertexShader.getUniformSlot(
          definition.name,
        );

        final vDef = definition.clone()..slot = vSlot;
        _vertexUniforms[definition.name] = vDef;

        // Evaluate Fragment Shader bindings
        final gpu.UniformSlot fSlot = fragmentShader.getUniformSlot(
          definition.name,
        );

        final fDef = definition.clone()..slot = fSlot;
        _fragmentUniforms[definition.name] = fDef;
      }

      return pipeline != null;
    } catch (e) {
      debugPrint('Exception initializing GpuShader Pipeline: $e');
      return false;
    }
  }

  /// Binds an existing pipeline state configuration variables to an active RenderPass.
  void bind(gpu.RenderPass renderPass) {
    if (pipeline == null) return;
    renderPass.bindPipeline(pipeline!);
  }

  /// Emplaces raw structural transforms into the RenderPass using a transient allocator HostBuffer view.
  void setTransformUniformBlock(
    gpu.RenderPass renderPass, {
    required vm.Matrix4 modelView,
    required vm.Matrix4 projection,
  }) {
    // Attempt lookup in vertex map first, check fragment map as structural fallback
    final targetSlot =
        _vertexUniforms[uTransformBlock]?.slot ??
        _fragmentUniforms[uTransformBlock]?.slot;
    if (targetSlot == null) return;

    final Float32List data = Float32List(32);
    modelView.copyIntoArray(data, 0);
    projection.copyIntoArray(data, 16);

    final gpu.HostBuffer transients = gpu.gpuContext.createHostBuffer();
    final gpu.BufferView uniformBufferView = transients.emplace(
      ByteData.sublistView(data),
    );

    renderPass.bindUniform(targetSlot, uniformBufferView);
  }

  /// Attaches an allocated image resource straight onto your target uniform sampler binding index.
  void setTexture(gpu.RenderPass renderPass, gpu.Texture texture) {
    final targetSlot =
        _fragmentUniforms[textureSamplerAttrib]?.slot ??
        _vertexUniforms[textureSamplerAttrib]?.slot;
    if (targetSlot == null) return;

    renderPass.bindTexture(targetSlot, texture);
  }

  /// Helper to upload custom uniform data structures into a specified stage's block slot index.
  ///
  /// Set [isFragmentStage] to true to target your fragment uniform block registry mapping.
  void setCustomBlockData(
    gpu.RenderPass renderPass,
    String uniformName,
    Float32List floatData, {
    bool isFragmentStage = false,
  }) {
    final Map<String, UniformDefinition> activeMap = isFragmentStage
        ? _fragmentUniforms
        : _vertexUniforms;
    final definition = activeMap[uniformName];
    if (definition == null || definition.slot == null) return;

    final gpu.HostBuffer transients = gpu.gpuContext.createHostBuffer();
    final gpu.BufferView view = transients.emplace(
      ByteData.sublistView(floatData),
    );

    renderPass.bindUniform(definition.slot!, view);
  }

  void dispose() {
    pipeline = null;
    _vertexUniforms.clear();
    _fragmentUniforms.clear();
    _pendingUniforms.clear();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GpuShader &&
        other.runtimeType == runtimeType &&
        other._vertexKey == _vertexKey &&
        other._fragmentKey == _fragmentKey;
  }

  @override
  int get hashCode => Object.hash(_vertexKey, _fragmentKey);
}
