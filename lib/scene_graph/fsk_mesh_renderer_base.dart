import 'dart:ui';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/scene_graph/fsk_renderer_base.dart';
import 'package:fsk/scene_graph/fsk_submesh.dart';
import 'package:fsk/gpu/fsk_vertex_buffer.dart';
import 'package:fsk/gpu/fsk_shader_material.dart';
import 'package:fsk/gpu/gpu_pipeline_key.dart';
import 'package:fsk/fsk_singleton.dart';

abstract class FskMeshRendererBase extends FskRendererBase {
  bool _dataUploaded = false;
  bool isValid = false;

  @override
  bool get verticesDownloaded => _dataUploaded;

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

    final pk = pipelineKey;
    final u = uniforms;

    if (pk == null || u == null) {
      if (pk == null) logError("FskMeshRendererBase.draw: pipelineKey is NULL");
      if (u == null) logError("FskMeshRendererBase.draw: uniforms is NULL");
      return;
    }

    FSK().activatePipeline(pk, renderPass, layout);

    vbo.bind(renderPass);

    // 1. Assign matrices FIRST so onUpdate can use them for View-Space transforms
    u.mvMatrix = mvMatrix;
    u.pMatrix = pMatrix;

    // 2. Perform per-frame updates (like light-to-view transformation)
    u.onUpdate(viewportSize);

    for (var subMesh in _subMeshes) {
      // 3. Robust Texture Binding: Always bind a texture to Slot 2 to prevent state leaks.
      if (subMesh.textureInfo != null) {
        u.texture = subMesh.textureInfo!.texture;
        u.samplerOptions = subMesh.textureInfo!.samplerOptions;
      } else if (textureInfo != null) {
        u.texture = textureInfo!.texture;
        u.samplerOptions = textureInfo!.samplerOptions;
      } else {
        u.texture = FSK().textureManager.solidTexture; // Default for meshes
        u.samplerOptions = null;
      }

      if (subMesh.material != null) {
        u.applyMaterial(subMesh.material!);
      }

      u.bind(renderPass, transients);

      drawFskSubMesh(renderPass, subMesh);
    }
  }

  void drawFskSubMesh(gpu.RenderPass renderPass, FskSubMesh subMesh);
}
