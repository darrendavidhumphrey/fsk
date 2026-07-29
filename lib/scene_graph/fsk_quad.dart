import 'dart:ui';

import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' hide Colors;
import '../fsk.dart';
import 'fsk_quads_renderer.dart';

/// A class that manages the geometry and rendering for a single textured quad
class FskQuad extends FskRenderableObject {
  // The quad to render
  final Quad _quad;

  // The texture coordinates for the quad
  final Rect _textureRect;

  /// Object that renders the quads
  final FskQuadsRenderer _renderer;

  bool _premultiplyAlpha = true;
  Color _modulateColor = const Color(0xFFFFFFFF);

  /////////////////////////////////////////////////////////////////////////////
  // Public API
  /////////////////////////////////////////////////////////////////////////////
  bool get premultiplyAlpha => _premultiplyAlpha;

  set premultiplyAlpha(bool value) {
    _premultiplyAlpha = value;
    _renderer.premultiplyAlpha = value;
  }

  @override
  void rebuildPipelineIfNeeded() {
    _renderer.rebuildPipeline();
  }

  /// Sets a new texture and flags the text for a rebuild.
  void setTexture(String textureId) {
    _renderer.setTexture(FSK().textureManager.getTextureInfo(textureId));
  }

  Color get modulateColor => _modulateColor;
  set modulateColor(Color value) {
    _modulateColor = value;
    _renderer.setModulateColor(value);
  }

  /////////////////////////////////////////////////////////////////////////////
  // Constructor
  /////////////////////////////////////////////////////////////////////////////
  FskQuad(
    super.parentScene,
    this._quad,
    this._textureRect,
    this._modulateColor,
    String textureId) :
      _renderer = FskQuadsRenderer()
  {
    setTexture(textureId);

    // Trigger the setter
    modulateColor = _modulateColor;
  }


  /// Rebuilds the vertex buffer object
  @override
  void doRebuild() {
    _renderer.setFromQuads([_quad], [_textureRect]);
  }

  @override
  void draw(
    gpu.RenderPass renderPass,
    gpu.HostBuffer transients,
    Matrix4 pMatrix,
    Matrix4 mvMatrix,
  ) {
    // Apply the local screenRect offset to the matrix
    final Matrix4 finalMvMatrix = mvMatrix.clone()
      ..translateByVector3(Vector3(screenRect.left, screenRect.top, 0.0));
    _renderer.draw(renderPass, transients, pMatrix.clone(), finalMvMatrix);
  }
}
