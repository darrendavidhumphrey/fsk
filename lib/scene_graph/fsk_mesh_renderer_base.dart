import 'dart:ui';
import 'package:vector_math/vector_math.dart';
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
  gpu.CullMode get cullMode => gpu.CullMode.backFace;

  final FskVertexBuffer vbo = FskVertexBuffer();
  final List<FskSubMesh> _subMeshes = [];

  List<FskSubMesh> get subMeshes => _subMeshes;

  FskMeshRendererBase();

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
      Matrix4 pMatrix,
      Matrix4 mvMatrix,
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

    uniforms!.mvMatrix = mvMatrix;
    uniforms!.pMatrix = pMatrix;

    uniforms!.onUpdate(viewportSize);

    for (var subMesh in _subMeshes) {
      if (subMesh.textureInfo != null) {
        uniforms!.texture = subMesh.textureInfo!.texture;
        uniforms!.samplerOptions = subMesh.textureInfo!.samplerOptions;
      } else if (textureInfo != null) {
        uniforms!.texture = textureInfo!.texture;
        uniforms!.samplerOptions = textureInfo!.samplerOptions;
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
