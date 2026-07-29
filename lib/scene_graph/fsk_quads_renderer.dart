import 'dart:typed_data';
import 'dart:ui';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;

import '../fsk_scene.dart';
import '../fsk_texture_manager.dart';
import '../gpu/fsk_vertex_buffer.dart';
import '../gpu/gpu_pipeline_key.dart';
import '../shaders/simple_texture_shader.dart';
import '../vbo_filler.dart';

// TODO: Inherit from a base class

class FskQuadsRenderer {
  List<Quad> quads = [];
  List<Rect> textureQuads = [];
  final FskScene parentScene;
  SimpleTextureUniforms? uniforms;
  PipelineKey? pipelineKey;

  bool _premultiplyAlpha = true;

  // Pointer to the texture in the texture manager
  FskTextureInfo? _textureInfo;

  // Color to modulate the texture with
  Color _modulateColor = const Color(0xFFFFFFFF);

  bool isValid = false;

  /// The vertex buffer object that holds the geometry for rendering.
  final FskVertexBuffer _vbo = FskVertexBuffer();

  /////////////////////////////////////////////////////////////////////////////
  // Public API
  /////////////////////////////////////////////////////////////////////////////

  // TODO: This should trigger a pipeline rebuild
  bool get premultiplyAlpha => _premultiplyAlpha;
  set premultiplyAlpha(bool value) {
    _premultiplyAlpha = value;
  }

  void setModulateColor(Color color) {
    _modulateColor = color;
  }

  void rebuildPipeline() {
    print("Rebuild pipeline called");
    // Create a pipeline key for this shader and associated settings
    pipelineKey = PipelineKey(
      vertShaderName: "SimpleTextureVertex",
      fragShaderName: "SimpleTextureFragment",
      layoutName: "QuadVertexLayout",
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

    uniforms = SimpleTextureUniforms(
      vertexShader: pipelineKey!.vertShader,
      fragmentShader: pipelineKey!.fragShader,
    );
  }

  /// Sets a new text string and flags the text for a rebuild.
  void setTexture(FskTextureInfo? textureInfo) {
    _textureInfo = textureInfo;
  }

  FskQuadsRenderer(this.parentScene);


  void _checkIsValid() {
    isValid =
        (_textureInfo != null) &&
        (_textureInfo!.texture != null) &&
        (quads.isNotEmpty) &&
        (textureQuads.isNotEmpty);
  }

  void dispose() {
    _vbo.dispose();
  }

  void setQuads(List<Quad> newQuads, List<Rect> newTextureQuads) {
    quads = newQuads;
    textureQuads = newTextureQuads;

    // TODO: Clean this up. VboFiller should properly allocate the vertex buffer
    int vertexCount = quads.length * 6; // Two triangles per character quad.

    Float32List? vertexTexCoordArray = _vbo.requestBuffer(vertexCount);

    if (vertexTexCoordArray != null) {
      // Fill the VBO with the generated quad data.
      VboFiller.addTexturedQuads(quads, textureQuads, _vbo);
    }

    // Upload generated quad data to gpu
    _vbo.uploadData(parentScene);
  }

  void draw(
    gpu.RenderPass renderPass,
    gpu.HostBuffer transients,
    Matrix4 pMatrix,
    Matrix4 mvMatrix,
  ) {
    _checkIsValid();
    if (!isValid) return;

    parentScene.pipelineCache.activate(
      pipelineKey!,
      renderPass,
      textVertexLayout,
    );

    _vbo.bind(renderPass);

    uniforms!.setModulateColor(_modulateColor);
    uniforms!.texture = _textureInfo!.texture;
    uniforms!.mvMatrix = mvMatrix.clone();
    uniforms!.pMatrix = pMatrix.clone();
    uniforms!.bind(renderPass, transients);

    _vbo.drawTriangles(renderPass);
  }
}
