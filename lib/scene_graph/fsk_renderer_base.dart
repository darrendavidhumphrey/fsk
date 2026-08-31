import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;

import '../gpu/fsk_shader_material.dart';
import '../gpu/fsk_texture_manager.dart';
import '../gpu/gpu_pipeline_key.dart';
import '../shaders/base_uniforms.dart';
import '../logging.dart';

import 'fsk_depth_state.dart';

abstract class FskRendererBase extends ChangeNotifier with LoggableClass {
  bool _disposed = false;
  bool get isDisposed => _disposed;

  FskRendererBase();

  /// Optional custom material configuration
  FskShaderMaterial? _shaderMaterial;
  FskShaderMaterial? get shaderMaterial => _shaderMaterial;
  set shaderMaterial(FskShaderMaterial? value) {
    if (_shaderMaterial == value) return;
    _shaderMaterial = value;
    pipeLineNeedsRebuild = true;
    notifyListeners();
  }

  /// The active uniform block for this renderer
  BaseUniforms? _uniforms;
  BaseUniforms? get uniforms => _uniforms;
  set uniforms(BaseUniforms? value) {
    if (_uniforms == value) return;
    _uniforms = value;
    pipeLineNeedsRebuild = true;
    notifyListeners(); // Renderer is now a ChangeNotifier
  }

  // Pointer to the texture in the texture manager
  FskTextureInfo? textureInfo;
  gpu.Texture? _lastTextureHandle;

  final FskDepthState depthState = FskDepthState();
  bool pipeLineNeedsRebuild = true;

  PipelineKey? pipelineKey;

  void setTexture(FskTextureInfo? info) {
    if (textureInfo == info && textureInfo?.texture == _lastTextureHandle) return;
    textureInfo = info;
    _lastTextureHandle = textureInfo?.texture;
    pipeLineNeedsRebuild = true;
    notifyListeners();
  }

  // --- Pipeline Customization Hooks ---

  FskShaderMaterial get defaultMaterial;

  gpu.BlendFactor get srcColorFactor => gpu.BlendFactor.sourceAlpha;
  gpu.BlendFactor get dstColorFactor => gpu.BlendFactor.oneMinusSourceAlpha;
  gpu.BlendFactor get srcAlphaFactor => gpu.BlendFactor.one;
  gpu.BlendFactor get dstAlphaFactor => gpu.BlendFactor.oneMinusSourceAlpha;

  gpu.CullMode get cullMode => gpu.CullMode.none;
  gpu.WindingOrder get windingOrder => gpu.WindingOrder.counterClockwise;

  gpu.VertexLayout get layout;

  /// Returns true if the vertex data has been successfully uploaded to the GPU.
  bool get verticesDownloaded;

  void draw(
    gpu.RenderPass renderPass,
    gpu.HostBuffer transients,
    vm.Matrix4 pMatrix,
    vm.Matrix4 mvMatrix,
    Size viewportSize,
  );

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _uniforms?.dispose();
    _uniforms = null;
    pipelineKey = null;
    pipeLineNeedsRebuild = true;
    super.dispose();
  }

  // Shared implementation of pipeline reconstruction
  void rebuildPipeline() {
    if (_disposed) return;

    // Detect if the underlying texture handle has changed (e.g. font finished loading)
    if (textureInfo?.texture != _lastTextureHandle) {
      pipeLineNeedsRebuild = true;
      // ONLY update the handle if it's non-null. If it's null, we want to keep 
      // pipeLineNeedsRebuild=true until we get a real handle.
      if (textureInfo?.texture != null) {
        logInfo("Renderer for texture '${textureInfo!.id}' handle transitioned from NULL to VALID.");
        _lastTextureHandle = textureInfo?.texture;
      }
    }

    if (!pipeLineNeedsRebuild && pipelineKey != null && _uniforms != null) return;

    final material = shaderMaterial ?? defaultMaterial;

    pipelineKey = PipelineKey(
      vertShaderName: material.vertShaderName,
      fragShaderName: material.fragShaderName,
      layoutName:
          "${material.vertShaderName}_${material.fragShaderName}_Pipeline",
      depthTestEnabled: depthState.depthTestEnabled,
      depthWriteEnabled: depthState.depthWriteEnabled,
      depthCompareOperation: depthState.depthCompareOperation,
      texturingEnabled: true,
      srcColorFactor: srcColorFactor,
      dstColorFactor: dstColorFactor,
      srcAlphaFactor: srcAlphaFactor,
      dstAlphaFactor: dstAlphaFactor,
      colorBlendOp: gpu.BlendOperation.add,
      alphaBlendOp: gpu.BlendOperation.add,
      windingOrder: windingOrder,
      cullMode: cullMode,
    );

    final BaseUniforms newUniforms = material.uniformsFactory(
      pipelineKey!.vertShader,
      pipelineKey!.fragShader,
    );

    // Synchronize current renderer state into the new uniform instance
    if (_uniforms != null) {
      newUniforms.copyFrom(_uniforms!);
    }

    _uniforms = newUniforms;
    pipeLineNeedsRebuild = false;
    notifyListeners();
  }
}
