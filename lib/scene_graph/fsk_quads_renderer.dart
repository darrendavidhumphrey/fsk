import 'dart:typed_data';
import 'dart:ui';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_gpu/gpu.dart' as gpu;

import '../fsk_singleton.dart';
import '../gpu/gpu_pipeline_key.dart';
import '../gpu/fsk_vertex_buffer.dart';
import '../gpu/fsk_shader_material.dart';
import '../vbo_filler.dart';


import 'fsk_renderer_base.dart';

class FskQuadsRenderer extends FskRendererBase {
  bool _verticesDownloaded = false;

  bool _premultiplyAlpha = false;
  bool get premultiplyAlpha => _premultiplyAlpha;
  set premultiplyAlpha(bool value) {
    if (_premultiplyAlpha != value) {
      _premultiplyAlpha = value;
      pipeLineNeedsRebuild = true;
      notifyListeners();
    }
  }

  bool _debug = false;
  void setDebug(bool value) {
    _debug = value;
  }

  @override
  gpu.VertexLayout get layout => shaderMaterial?.layout ?? textVertexLayout;

  @override
  bool get verticesDownloaded => _verticesDownloaded;

  @override
  FskShaderMaterial get defaultMaterial => FskShaderMaterial.simpleTexture;

  @override
  gpu.BlendFactor get srcColorFactor =>
      _premultiplyAlpha ? gpu.BlendFactor.one : gpu.BlendFactor.sourceAlpha;

  @override
  gpu.BlendFactor get dstColorFactor => gpu.BlendFactor.oneMinusSourceAlpha;

  /// The vertex buffer object that holds the geometry for rendering.
  final FskVertexBuffer _vbo = FskVertexBuffer();

  /////////////////////////////////////////////////////////////////////////////
  // Public API
  /////////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////////
  // Constructor
  /////////////////////////////////////////////////////////////////////////////
  FskQuadsRenderer();

  @override
  void dispose() {
    _vbo.dispose();
    super.dispose();
  }

  void setVertices(Float32List vertices) {
    _vbo.uploadData(vertices);
    _verticesDownloaded = vertices.isNotEmpty;
  }

  void setFromUnrolledQuads(int numQuads, Float32List vertexTexCoordArray) {
    final vertices = VboFiller.verticesFromUnrolledQuads(numQuads, vertexTexCoordArray);
    setVertices(vertices);
  }

  void setFromQuads(List<vm.Quad> quads, List<Rect> textureQuads) {
    final vertices = VboFiller.verticesFromTexturedQuads(quads, textureQuads);
    setVertices(vertices);
  }

  @override
  void draw(
    gpu.RenderPass renderPass,
    gpu.HostBuffer transients,
    vm.Matrix4 pMatrix,
    vm.Matrix4 mvMatrix,
    Size viewportSize,
  ) {
    if (isDisposed) return;
    
    // It's not an error for the renderer to be empty
    if (!_verticesDownloaded) {
      logVerbose("FskQuadsRenderer.draw: vertices not downloaded");
      logVerbose("FskQuadsRenderer.draw:  vertex count is ${_vbo.vertexCount}");
      return;
    }

    rebuildPipeline();

    final pk = pipelineKey;
    final u = uniforms;

    if (pk == null || u == null) {
      if (pk == null) logError("FskQuadsRenderer.draw: pipelineKey is NULL");
      if (u == null) logError("FskQuadsRenderer.draw: uniforms is NULL");
      return;
    }

    FSK().activatePipeline(
      pk,
      renderPass,
      layout,
    );

    _vbo.bind(renderPass);

    // 1. Assign matrices FIRST so onUpdate can use them for View-Space transforms
    u.mvMatrix = mvMatrix;
    u.pMatrix = pMatrix;

    // 2. Perform per-frame updates
    u.onUpdate(viewportSize);

    // 3. Absolute Texture Guard: Never draw if the GPU handle is missing.
    // This makes "black quads" mathematically impossible; we render nothing until ready.
    if (textureInfo?.texture == null) {
      if (_debug) {
        logVerbose("FskQuadsRenderer.draw: texture handle is NULL, skipping draw call.");
      }
      return;
    }

    u.texture = textureInfo!.texture;
    u.samplerOptions = textureInfo!.samplerOptions;

    u.bind(renderPass, transients);

    _vbo.drawTriangles(renderPass);
  }
}
