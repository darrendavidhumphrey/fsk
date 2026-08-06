import 'dart:typed_data';
import 'dart:ui';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'fsk_renderer_base.dart';

class FskQuadsRenderer extends FskRendererBase {
  bool _vertsDownloaded = false;

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
    _modulateColor = color;
  }

  /////////////////////////////////////////////////////////////////////////////
  // Constructor
  /////////////////////////////////////////////////////////////////////////////
  FskQuadsRenderer();

  void setVertices(Float32List vertices) {
    _vbo.uploadData(vertices);
    _vertsDownloaded = vertices.isNotEmpty;
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
    if (!_vertsDownloaded) {
      return;
    }

    rebuildPipeline();

    FSK().activatePipeline(
      pipelineKey!,
      renderPass,
      layout,
    );

    _vbo.bind(renderPass);

    uniforms!.onUpdate(viewportSize);

    if (uniforms is SimpleTextureUniforms) {
      uniforms!.setValueSilent('uModulateColor', _modulateColor);
    }
    
    if (textureInfo != null) {
      uniforms!.texture = textureInfo!.texture;
      uniforms!.samplerOptions = textureInfo!.samplerOptions;
    }
    
    uniforms!.mvMatrix = mvMatrix;
    uniforms!.pMatrix = pMatrix;

    uniforms!.bind(renderPass, transients);

    _vbo.drawTriangles(renderPass);
  }
}
