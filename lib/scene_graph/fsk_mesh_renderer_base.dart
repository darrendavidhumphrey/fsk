import 'dart:ui';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'fsk_renderer_base.dart';

abstract class FskMeshRendererBase extends FskRendererBase {
  PipelineKey? pipelineKey;

  bool _dataUploaded = false;
  bool isValid = false;

  gpu.VertexLayout layout = v3t2n3Layout;

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

  @override
  void rebuildPipeline() {
    if (!pipeLineNeedsRebuild && pipelineKey != null) return;

    final material = shaderMaterial ?? FskShaderMaterial.lighting;

    pipelineKey = PipelineKey(
      vertShaderName: material.vertShaderName,
      fragShaderName: material.fragShaderName,
      layoutName: "${material.vertShaderName}_${material.fragShaderName}_Pipeline",
      depthTestEnabled: depthState.depthTestEnabled,
      depthWriteEnabled: depthState.depthWriteEnabled,
      depthCompareOperation: depthState.depthCompareOperation,
      texturingEnabled: true,
      srcColorFactor: gpu.BlendFactor.sourceAlpha,
      dstColorFactor: gpu.BlendFactor.oneMinusSourceAlpha,
      srcAlphaFactor: gpu.BlendFactor.one,
      dstAlphaFactor: gpu.BlendFactor.oneMinusSourceAlpha,
      colorBlendOp: gpu.BlendOperation.add,
      alphaBlendOp: gpu.BlendOperation.add,
      windingOrder: gpu.WindingOrder.counterClockwise,
      cullMode: gpu.CullMode.none, // DEBUG: Disable culling
    );

    final oldUniforms = uniforms;
    uniforms = material.uniformsFactory(
      pipelineKey!.vertShader,
      pipelineKey!.fragShader,
    );
    
    if (oldUniforms != null) {
      uniforms!.copyFrom(oldUniforms);
    }
    
    layout = material.layout;
    pipeLineNeedsRebuild = false;
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

    FSK().activatePipeline(pipelineKey!, renderPass, layout);

    vbo.bind(renderPass);

    uniforms!.onUpdate(viewportSize);

    for (var subMesh in _subMeshes) {
      if (subMesh.textureInfo != null) {
        uniforms!.texture = subMesh.textureInfo!.texture;
        uniforms!.samplerOptions = subMesh.textureInfo!.samplerOptions;
      } else if (textureInfo != null) {
        uniforms!.texture = textureInfo!.texture;
        uniforms!.samplerOptions = textureInfo!.samplerOptions;
      }

      uniforms!.mvMatrix = mvMatrix.clone();
      uniforms!.pMatrix = pMatrix.clone();

      if (subMesh.material != null) {
        uniforms!.applyMaterial(subMesh.material!);
      }

      uniforms!.bind(renderPass, transients);

      drawFskSubMesh(renderPass, subMesh);
    }
  }

  void drawFskSubMesh(gpu.RenderPass renderPass, FskSubMesh subMesh);
}
