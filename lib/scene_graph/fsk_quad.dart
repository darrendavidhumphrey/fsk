import 'package:flutter/material.dart'; // Adds the 'Colors' constant utility
import 'package:flutter_angle/flutter_angle.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
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

  bool _needsRebuild = true;

  /// A flag indicating if the text geometry needs to be recalculated.
  bool get needsRebuild => _needsRebuild;

  /// The vertex buffer object that holds the geometry for rendering.
  final VertexBuffer _vbo = VertexBuffer.v3t2();

  UniformValue? _modulateColorUniformValue;


  FskQuad(this._quad, this._textureRect,this._textureId) {
    // Default to the simple texture shader if not set.
    setShader(FSK().shaders.getShader<SimpleTextureShader>());

    _textureInfo = FSK().textureManager.getTextureInfo(_textureId);
  }

  /// Sets a new text string and flags the text for a rebuild.
  void setTexture(String textureId) {
    _textureId = textureId;
    _textureInfo = FSK().textureManager.getTextureInfo(_textureId);
  }

  /// Disposes the vertex buffer associated with this text.
  @override
  void dispose() {
    _vbo.dispose();
  }

  @override
  void init(GlStateManager gls) {
    _vbo.init(gls);
    var uniformDefinition = shader!.uniforms["uModulateColor"];
    // TODO: Update this when the shader changes, make an onShaderChanged callback?
    if (uniformDefinition != null) {
      _modulateColorUniformValue = getUniformValue(uniformDefinition);
      // Default to white
      _modulateColorUniformValue?.value = const Color(0xFFFFFFFF);
    }

    rebuild(gls);
  }

  /// Rebuilds the vertex buffer object if the text or font has changed.
  @override
  void rebuild(GlStateManager gls) {
    // Guard against unnecessary, expensive rebuilds.
    if (!_needsRebuild) return;

    VboFiller.makeTexturedQuad(_quad, _textureRect,_vbo);
    _needsRebuild = false;
  }


  @override
  void drawSetup(GlStateManager gls, Matrix4 pMatrix, Matrix4 mvMatrix) {
    if ((_textureInfo == null) || (shader==null)) return;

    gls.useProgram(shader!.program);
    shader!.setMatrixUniforms(pMatrix, mvMatrix);
//print("Quad draw");
//dumpShaderParams();
    applyShaderParams();
    gls.setBlend(true);
    gls.setTexturingEnabled(true);
    gls.activeTexture(WebGL.TEXTURE0);
    gls.setDepthTest(false);

    gls.blendFuncSeparate(
      WebGL.ONE,
      WebGL.ONE_MINUS_SRC_ALPHA,
      WebGL.ONE,
      WebGL.ONE_MINUS_SRC_ALPHA,
    );
    shader!.setTextureSampler(0);
  }

  @override
  void draw(GlStateManager gls) {
    if ((_textureInfo == null) || (shader==null)) return;

    gls.bindTexture(WebGL.TEXTURE_2D, _textureInfo!.texture);

    _vbo.bind();
    _vbo.drawTriangles();
  }
}
