import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import '../fsk_singleton.dart';
import '../logging.dart';
import 'materials.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'fragment_values.dart';

abstract class BaseUniforms extends ChangeNotifier with LoggableClass {
  final gpu.Shader? vertexShader;
  final gpu.Shader? fragmentShader;

  /// The name of the uniform block in the vertex shader.
  /// Subclasses should override this to match their specific shader.
  String get vertexBlockName => 'VertexUniforms';

  /// The name of the uniform block in the fragment shader.
  /// Subclasses should override this to match their specific shader.
  String get fragmentBlockName => 'FragmentUniforms';

  // Shared Vertex Uniform State
  final vm.Matrix4 mvMatrixLocal = vm.Matrix4.identity();
  final vm.Matrix4 pMatrixLocal = vm.Matrix4.identity();

  set mvMatrix(vm.Matrix4 value) {
    value.copyInto(mvMatrixLocal);
  }

  set pMatrix(vm.Matrix4 value) {
    value.copyInto(pMatrixLocal);
  }

  gpu.Texture? textureIn;
  gpu.SamplerOptions? samplerOptions;
  String get samplerUniformName => 'uSampler';

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

  /// Releases resources held by this uniform block.
  @override
  void dispose() {
    super.dispose();
    additionalTextures.clear();
    textureIn = null;
  }

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
        0,
        vertexData.lengthInBytes,
      ),
    );

    _safeBindUniform(renderPass, vertexShader!, vertexBlockName, vertexBufferView);

    // =========================================================================
    // 2. DYNAMIC SUBCLASS FRAGMENT WRITER
    // =========================================================================
    serializeFragmentData();
    final gpu.BufferView fragmentBufferView = transients.emplace(
      fragmentData.buffer.buffer.asByteData(
        0,
        fragmentData.buffer.lengthInBytes,
      ),
    );
    
    _safeBindUniform(renderPass, fragmentShader!, fragmentBlockName, fragmentBufferView);

    // =========================================================================
    // 3. UNIFIED SAMPLER BINDING (Binding 2)
    // =========================================================================
    _safeBindSampler(renderPass, fragmentShader!, samplerUniformName);

    bindAdditionalTextures(renderPass);
  }

  void _safeBindUniform(gpu.RenderPass pass, gpu.Shader shader, String name, gpu.BufferView view) {
    try {
      final slot = shader.getUniformSlot(name);
      pass.bindUniform(slot, view);
    } catch (_) {
      logError("FATAL: Could not find requested uniform slot '$name' in shader ${shader.hashCode}.");
      throw StateError("Shader is missing required uniform slot: $name");
    }
  }

  void _safeBindSampler(gpu.RenderPass pass, gpu.Shader shader, String name) {
    final gpu.Texture textureToBind = textureIn ?? FSK().textureManager.transparentTexture!;

    try {
      final slot = shader.getUniformSlot(name);
      pass.bindTexture(slot, textureToBind, sampler: samplerOptions);
    } catch (_) {
      // CRITICAL: If we reach here, the shader HAS no valid sampler slot found by name.
      // This will lead to a "Texture State Leak" where the PREVIOUS draw call's texture 
      // remains bound to Slot 2, causing solid color artifacts (black quads).
      logError("FATAL: Could not find requested sampler slot '$name' in shader ${shader.hashCode}. This will cause state leaks.");
      throw StateError("Shader is missing required sampler uniform slot: $name");
    }
  }

  void bindAdditionalTextures(gpu.RenderPass renderPass) {}
}
