import 'dart:ui';

import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' hide Colors;
import '../fsk.dart';

/// A class that manages the geometry and rendering for a single textured quad
class FskQuad extends FskRenderableObject {
  // The quad to render
  final Quad _quad;

  // The texture coordinates for the quad
  final Rect _textureRect;

  // Name of the texture
  String _textureId;

  // Pointer to the texture in the texture manager
  FskTextureInfo? _textureInfo;

  bool _premultiplyAlpha = true;
  bool get premultiplyAlpha => _premultiplyAlpha;

  set premultiplyAlpha(bool value) {
    _premultiplyAlpha = value;
    _pipeLineNeedsRebuild = true;
  }

  bool _needsRebuild = true;
  bool _pipeLineNeedsRebuild = true;
  void rebuildPipelineIfNeeded() {
   if (!_pipeLineNeedsRebuild) return;

    pipelineKey = PipelineKey(
      vertShaderName: "SimpleTextureVertex",
      fragShaderName: "SimpleTextureFragment",
      depthTestEnabled: false,
      depthWriteEnabled: false,
      depthCompareOperation: gpu.CompareFunction.always,
      texturingEnabled: true,
      blendEnabled: true,
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
    _pipeLineNeedsRebuild = false;
  }

  FskQuad(super.parentScene, this._quad, this._textureRect, this._textureId) {
    setTexture(_textureId);
    // TODO: Somehow choose the shader and pass in the uniform strings from the xml
  }

  /// A flag indicating if the text geometry needs to be recalculated.
  bool get needsRebuild => _needsRebuild;

  /// The vertex buffer object that holds the geometry for rendering.
  final VertexBuffer _vbo = VertexBuffer();

  /// Sets a new text string and flags the text for a rebuild.
  void setTexture(String textureId) {
    _textureId = textureId;
    _textureInfo = FSK().textureManager.getTextureInfo(_textureId);
    _pipeLineNeedsRebuild = true;
  }

  Color _modulateColor = const Color(0xFFFFFFFF);
  Color get modulateColor => _modulateColor;
  set modulateColor(Color value) {
    _modulateColor = value;
    _needsRebuild = true;
  }

  /// Rebuilds the vertex buffer object if the text or font has changed.
  @override
  void rebuildIfNeeded() {
    // Guard against unnecessary, expensive rebuilds.
    if (!_needsRebuild) return;

    VboFiller.makeTexturedQuad(_quad, _textureRect, _vbo);
    _needsRebuild = false;
  }

  @override
  void draw(gpu.RenderPass renderPass, Matrix4 pMatrix, Matrix4 mvMatrix) {

    rebuildPipelineIfNeeded();
    rebuildIfNeeded();

    parentScene.pipelineCache.activate(pipelineKey!, renderPass, v3t2Layout );

    _vbo.uploadData();
    _vbo.bind(renderPass);

    if (uniforms case SimpleTextureUniforms texUniforms) {
      texUniforms.texture = _textureInfo?.texture;
      texUniforms.setModulateColor(_modulateColor);
      texUniforms.mvMatrix = mvMatrix.clone();
      texUniforms.pMatrix = pMatrix.clone();
      texUniforms.bind(renderPass);
    } else {
      assert(false, "Unexpected uniforms type in FskQuad -- Not implemented");
    }
    _vbo.drawTriangles(renderPass);
  }
}
