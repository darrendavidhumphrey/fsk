import 'dart:typed_data';
import 'dart:ui';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'fsk_renderer_base.dart';

class FskQuadsRenderer extends FskRendererBase {
  PipelineKey? pipelineKey;

  bool _vertsDownloaded = false;

  bool _premultiplyAlpha = true;

  // Pointer to the texture in the texture manager
  FskTextureInfo? _textureInfo;

  // Color to modulate the texture with
  Color _modulateColor = const Color(0xFFFFFFFF);

  bool isValid = false;

  bool pipeLineNeedsRebuild = true;

  gpu.VertexLayout layout = textVertexLayout;

  /// The vertex buffer object that holds the geometry for rendering.
  final FskVertexBuffer _vbo = FskVertexBuffer();

  /////////////////////////////////////////////////////////////////////////////
  // Public API
  /////////////////////////////////////////////////////////////////////////////
  bool get premultiplyAlpha => _premultiplyAlpha;
  set premultiplyAlpha(bool value) {
    _premultiplyAlpha = value;
    pipeLineNeedsRebuild = true;
  }

  void setModulateColor(Color color) {
    _modulateColor = color;
  }

  @override
  void rebuildPipeline() {
    if (!pipeLineNeedsRebuild && pipelineKey != null) return;

    final material = shaderMaterial ?? FskShaderMaterial.simpleTexture;

    // Create a pipeline key for this shader and associated settings
    pipelineKey = PipelineKey(
      vertShaderName: material.vertShaderName,
      fragShaderName: material.fragShaderName,
      layoutName: "${material.vertShaderName}_${material.fragShaderName}_Pipeline",
      depthTestEnabled: true,
      depthWriteEnabled: false,
      depthCompareOperation: gpu.CompareFunction.less,
      texturingEnabled: true,
      srcColorFactor: _premultiplyAlpha
          ? gpu.BlendFactor.one
          : gpu.BlendFactor.sourceAlpha,
      dstColorFactor: gpu.BlendFactor.oneMinusSourceAlpha,
      srcAlphaFactor: gpu.BlendFactor.one,
      dstAlphaFactor: gpu.BlendFactor.oneMinusSourceAlpha,
      colorBlendOp: gpu.BlendOperation.add,
      alphaBlendOp: gpu.BlendOperation.add,
      windingOrder: gpu.WindingOrder.counterClockwise,
      cullMode: gpu.CullMode.none,
    );

    final oldValues = uniforms?.valuesMap;
    uniforms = material.uniformsFactory(
      pipelineKey!.vertShader,
      pipelineKey!.fragShader,
    );

    if (oldValues != null) {
      uniforms!.valuesMap.addAll(oldValues);
    }
    
    layout = material.layout;
    pipeLineNeedsRebuild = false;
  }

  /// Sets a new text string and flags the text for a rebuild.
  void setTexture(FskTextureInfo? textureInfo) {
    _textureInfo = textureInfo;
  }

  /////////////////////////////////////////////////////////////////////////////
  // Constructor
  /////////////////////////////////////////////////////////////////////////////
  FskQuadsRenderer();

  void _checkIsValid() {
    isValid = _vertsDownloaded;
  }

  void setFromUnrolledQuads(int numQuads, Float32List vertexTexCoordArray) {
    _vertsDownloaded = _vbo.setFromUnrolledQuads(numQuads, vertexTexCoordArray);

    // Upload generated quad data to gpu
    _vbo.uploadData();
  }

  void setFromQuads(List<Quad> quads, List<Rect> textureQuads) {
    // Generate triangle mesh from quads
    _vertsDownloaded = _vbo.setFromQuads(quads, textureQuads);

    // Upload generated quad data to gpu
    _vbo.uploadData();
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

    FSK().activatePipeline(
      pipelineKey!,
      renderPass,
      layout,
    );

    _vbo.bind(renderPass);

    uniforms!.onUpdate(viewportSize);

    if (uniforms is SimpleTextureUniforms) {
      (uniforms as SimpleTextureUniforms).setModulateColor(_modulateColor);
    }
    
    if (_textureInfo != null) {
      uniforms!.texture = _textureInfo!.texture;
      uniforms!.samplerOptions = _textureInfo!.samplerOptions;
    }
    
    uniforms!.mvMatrix = mvMatrix.clone();
    uniforms!.pMatrix = pMatrix.clone();
    uniforms!.bind(renderPass, transients);

    _vbo.drawTriangles(renderPass);
  }
}
