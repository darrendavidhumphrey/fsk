import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart';

import 'fragment_values.dart';

abstract class BaseUniforms extends ChangeNotifier with LoggableClass {
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

  /// Whether this shader uses a sampler.
  /// Set to true by default to match our unified shader signatures (Binding 2).
  bool get hasSampler => true;

  set texture(gpu.Texture? val) {
    textureIn = val;
  }

  /// Optional additional textures for advanced shaders
  final List<gpu.Texture> additionalTextures = [];

  // Unified string-accessible data registry
  final Map<String, dynamic> valuesMap = {};

  /// The fixed size of the fragment uniform block (Binding 1).
  /// This must match the size defined in all GLSL fragment shaders (40 floats / 160 bytes).
  static const int kFragmentDataFloatCount = 40;

  /// The fixed size of the vertex uniform block (Binding 0).
  /// This contains two 4x4 matrices (32 floats / 128 bytes).
  static const int kVertexDataFloatCount = 32;

  /// Reusable buffer for packing fragment data.
  late final FragmentValues fragmentData =
      FragmentValues(kFragmentDataFloatCount);

  BaseUniforms({this.vertexShader, this.fragmentShader});

  /// Deep copies non-shader state from another uniform block.
  void copyFrom(BaseUniforms other) {
    valuesMap.addAll(other.valuesMap);
    textureIn = other.textureIn;
    samplerOptions = other.samplerOptions;
    additionalTextures.clear();
    additionalTextures.addAll(other.additionalTextures);

    // Matrix state is part of the "reusable vertex block" and must be preserved
    mvMatrixLocal.setFrom(other.mvMatrixLocal);
    pMatrixLocal.setFrom(other.pMatrixLocal);
  }

  /// Called automatically before binding to allow the uniforms to react to scene changes
  /// (e.g. updating resolution or time).
  void onUpdate(Size viewportSize) {}

  // Dynamic index operator for loose key-value lookup: uniforms['myProperty']
  dynamic operator [](String key) => valuesMap[key];

  void operator []=(String key, dynamic value) {
    if (valuesMap[key] == value) return;
    valuesMap[key] = value;
    notifyListeners();
  }

  /// Updates a value without triggering a scene redraw.
  /// Use this for per-frame calculated values like resolution or time.
  void setValueSilent(String key, dynamic value) {
    valuesMap[key] = value;
  }

  /// Override this in subclasses to apply material properties to specific uniforms.
  void applyMaterial(GlMaterial material) {}

  /// Implemented by subclasses to serialize their unique string properties
  /// into the internal [fragmentData] buffer.
  void serializeFragmentData();

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
    final Float32List vertexData = Float32List(kVertexDataFloatCount);
    vertexData.setAll(0, mvMatrixLocal.storage);
    vertexData.setAll(16, pMatrixLocal.storage);

    final gpu.BufferView vertexBufferView = transients.emplace(
      vertexData.buffer.asByteData(
        vertexData.offsetInBytes,
        vertexData.lengthInBytes,
      ),
    );

    final gpu.UniformSlot vertexSlot = vertexShader!.getUniformSlot(
      vertexBlockName,
    );
    renderPass.bindUniform(vertexSlot, vertexBufferView);

    // =========================================================================
    // 2. DYNAMIC SUBCLASS FRAGMENT WRITER
    // =========================================================================
    serializeFragmentData();
    final gpu.BufferView fragmentBufferView = transients.emplace(
      fragmentData.buffer.buffer.asByteData(
        fragmentData.buffer.offsetInBytes,
        fragmentData.buffer.lengthInBytes,
      ),
    );
    final gpu.UniformSlot fragmentSlot =
        fragmentShader!.getUniformSlot(fragmentBlockName);
    renderPass.bindUniform(fragmentSlot, fragmentBufferView);

    if (hasSampler) {
      final gpu.UniformSlot textureSlot = fragmentShader!.getUniformSlot(
        samplerUniformName,
      );

      final gpu.Texture textureToBind =
          textureIn ?? FSK().textureManager.transparentTexture!;
      renderPass.bindTexture(textureSlot, textureToBind,
          sampler: samplerOptions);
    }

    bindAdditionalTextures(renderPass);
  }

  void bindAdditionalTextures(gpu.RenderPass renderPass) {}
}
