import 'dart:ui';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'fsk_renderer_base.dart';

abstract class FskMeshRendererBase extends FskRendererBase {
  bool _dataUploaded = false;
  bool isValid = false;

  @override
  gpu.VertexLayout get layout => shaderMaterial?.layout ?? v3t2n3Layout;

  @override
  FskShaderMaterial get defaultMaterial => FskShaderMaterial.lighting;

  @override
  gpu.CullMode get cullMode => gpu.CullMode.none;

  final FskVertexBuffer vbo = FskVertexBuffer();
  final List<FskSubMesh> _subMeshes = [];

  List<FskSubMesh> get subMeshes => _subMeshes;

  FskMeshRendererBase();

  @override
  void dispose() {
    vbo.dispose();
    for (final subMesh in _subMeshes) {
      subMesh.textureInfo = null;
    }
    _subMeshes.clear();
    super.dispose();
  }

  void clearFskSubMeshes() {
    _subMeshes.clear();
    _dataUploaded = false;
  }

  void addFskSubMesh(FskSubMesh subMesh) {
    _subMeshes.add(subMesh);
  }

  void finalizeData() {
    _dataUploaded = true;
  }

  void _checkIsValid() {
    isValid = _dataUploaded && _subMeshes.isNotEmpty;
  }

  @override
  void draw(
      gpu.RenderPass renderPass,
      gpu.HostBuffer transients,
      vm.Matrix4 pMatrix,
      vm.Matrix4 mvMatrix,
      Size viewportSize,
      ) {
    _checkIsValid();
    if (!isValid) return;

    rebuildPipeline();

    if (pipelineKey == null) {
      logError("FskMeshRendererBase.draw: pipelineKey is NULL");
      return;
    }

    FSK().activatePipeline(pipelineKey!, renderPass, layout);

    vbo.bind(renderPass);

    if (uniforms == null) {
      logError("FskMeshRendererBase.draw: uniforms is NULL");
      return;
    }

    // 1. Assign matrices FIRST so onUpdate can use them for View-Space transforms
    uniforms!.mvMatrix = mvMatrix;
    uniforms!.pMatrix = pMatrix;

    // 2. Perform per-frame updates (like light-to-view transformation)
    uniforms!.onUpdate(viewportSize);

    for (var subMesh in _subMeshes) {
      // 3. Robust Texture Binding: Always bind a texture to Slot 2 to prevent state leaks.
      if (subMesh.textureInfo != null) {
        uniforms!.texture = subMesh.textureInfo!.texture;
        uniforms!.samplerOptions = subMesh.textureInfo!.samplerOptions;
      } else if (textureInfo != null) {
        uniforms!.texture = textureInfo!.texture;
        uniforms!.samplerOptions = textureInfo!.samplerOptions;
      } else {
        uniforms!.texture = FSK().textureManager.solidTexture; // Default for meshes
        uniforms!.samplerOptions = null;
      }

      if (subMesh.material != null) {
        uniforms!.applyMaterial(subMesh.material!);
      }

      uniforms!.bind(renderPass, transients);

      drawFskSubMesh(renderPass, subMesh);
    }
  }

  void drawFskSubMesh(gpu.RenderPass renderPass, FskSubMesh subMesh);
}
