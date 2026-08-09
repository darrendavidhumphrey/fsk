import 'dart:typed_data';
import 'dart:ui';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'fsk_renderer_base.dart';

class FskQuadsRenderer extends FskRendererBase {
  bool _verticesDownloaded = false;

  bool _premultiplyAlpha = true;

  // Color to modulate the texture with
  Color _modulateColor = const Color(0xFFFFFFFF);

  @override
  gpu.VertexLayout get layout => shaderMaterial?.layout ?? textVertexLayout;

  @override
  FskShaderMaterial get defaultMaterial => FskShaderMaterial.simpleTexture;

  @override
  gpu.BlendFactor get srcColorFactor =>
      _premultiplyAlpha ? gpu.BlendFactor.one : gpu.BlendFactor.sourceAlpha;

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
    if (_modulateColor != color) {
      _modulateColor = color;
      pipeLineNeedsRebuild = true; // Force refresh
    }
  }

  /////////////////////////////////////////////////////////////////////////////
  // Constructor
  /////////////////////////////////////////////////////////////////////////////
  FskQuadsRenderer();

  void setVertices(Float32List vertices) {
    _vbo.uploadData(vertices);
    _verticesDownloaded = vertices.isNotEmpty;
  }

  void setFromUnrolledQuads(int numQuads, Float32List vertexTexCoordArray) {
    final vertices = VboFiller.verticesFromUnrolledQuads(numQuads, vertexTexCoordArray);
    setVertices(vertices);
  }

  void setFromQuads(List<Quad> quads, List<Rect> textureQuads) {
    final vertices = VboFiller.verticesFromTexturedQuads(quads, textureQuads);
    setVertices(vertices);
  }

  @override
  void draw(
    gpu.RenderPass renderPass,
    gpu.HostBuffer transients,
    Matrix4 pMatrix,
    Matrix4 mvMatrix,
    Size viewportSize,
  ) {
    // It's not an error for the renderer to be empty
    if (!_verticesDownloaded) {
      return;
    }

    rebuildPipeline();

    if (pipelineKey == null) {
      logError("FskQuadsRenderer.draw: pipelineKey is NULL");
      return;
    }

    FSK().activatePipeline(
      pipelineKey!,
      renderPass,
      layout,
    );

    _vbo.bind(renderPass);

    if (uniforms == null) {
      logError("FskQuadsRenderer.draw: uniforms is NULL");
      return;
    }

    // 1. Assign matrices FIRST so onUpdate can use them for View-Space transforms
    uniforms!.mvMatrix = mvMatrix;
    uniforms!.pMatrix = pMatrix;

    // 2. Perform per-frame updates
    uniforms!.onUpdate(viewportSize);

    // 3. Synchronize renderer-specific properties
    if (uniforms is SimpleTextureUniforms) {
      (uniforms as SimpleTextureUniforms).setModulateColor(_modulateColor);
    }
    
    // 4. Robust Texture Binding: Always bind a texture to Slot 2 to prevent state leaks.
    if (uniforms!.hasSampler) {
       uniforms!.texture = (textureInfo != null) ? textureInfo!.texture : FSK().textureManager.transparentTexture;
       uniforms!.samplerOptions = (textureInfo != null) ? textureInfo!.samplerOptions : null;
    }

    uniforms!.bind(renderPass, transients);

    _vbo.drawTriangles(renderPass);
  }
}
