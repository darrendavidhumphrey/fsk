import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';
import 'package:fsk/fsk.dart';


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
  /// This must match the size defined in all GLSL fragment shaders (32 floats / 128 bytes).
  static const int kFragmentDataFloatCount = 32;

  /// The fixed size of the vertex uniform block (Binding 0).
  /// This contains two 4x4 matrices (32 floats / 128 bytes).
  static const int kVertexDataFloatCount = 32;

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

  /// Utility method to pack a color safely into a float array.
  /// Handles Color and Vector4 types. Ensures normalized 0.0-1.0 range.
  int packColor(Float32List targetList, int offset, dynamic colorVal) {
    if (colorVal is Color) {
      targetList[offset++] = colorVal.r;
      targetList[offset++] = colorVal.g;
      targetList[offset++] = colorVal.b;
      targetList[offset++] = colorVal.a;
    } else if (colorVal is Vector4) {
      targetList[offset++] = colorVal.x;
      targetList[offset++] = colorVal.y;
      targetList[offset++] = colorVal.z;
      targetList[offset++] = colorVal.w;
    } else {
      // Fallback to white
      targetList[offset++] = 1.0;
      targetList[offset++] = 1.0;
      targetList[offset++] = 1.0;
      targetList[offset++] = 1.0;
    }
    return offset;
  }

  /// Packs a Vector3 into a 4-float slot (vec4 in shader) with w=1.0.
  /// Handles Color, Vector3, and Vector4.
  int packVector3(Float32List targetList, int offset, dynamic value) {
    if (value is Color) {
      targetList[offset++] = value.r;
      targetList[offset++] = value.g;
      targetList[offset++] = value.b;
    } else if (value is Vector3) {
      targetList[offset++] = value.x;
      targetList[offset++] = value.y;
      targetList[offset++] = value.z;
    } else if (value is Vector4) {
      targetList[offset++] = value.x;
      targetList[offset++] = value.y;
      targetList[offset++] = value.z;
    } else {
      // Fallback to neutral grey
      targetList[offset++] = 0.5;
      targetList[offset++] = 0.5;
      targetList[offset++] = 0.5;
    }
    targetList[offset++] = 1.0; // w component
    return offset;
  }

  /// Packs a boolean as a 1.0 (true) or 0.0 (false) float.
  int packBool(Float32List targetList, int offset, dynamic value) {
    targetList[offset++] = (value is bool && value) ? 1.0 : 0.0;
    return offset;
  }

  /// Packs a numeric value as a double float.
  int packDouble(Float32List targetList, int offset, dynamic value) {
    targetList[offset++] = (value as num? ?? 0.0).toDouble();
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
    final Float32List fragmentData = serializeFragmentData();
    final gpu.BufferView fragmentBufferView = transients.emplace(
      fragmentData.buffer.asByteData(
        fragmentData.offsetInBytes,
        fragmentData.lengthInBytes,
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
      renderPass.bindTexture(textureSlot, textureToBind, sampler: samplerOptions);
    }

    bindAdditionalTextures(renderPass);
  }

  void bindAdditionalTextures(gpu.RenderPass renderPass) {}
}
