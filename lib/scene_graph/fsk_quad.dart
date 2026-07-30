import 'dart:ui';
import 'package:flutter/material.dart' show Colors;
import 'package:vector_math/vector_math.dart' hide Colors;
import '../frames/frame_data.dart';
import '../fsk.dart';
import 'fsk_quads_renderer.dart';

/// A class that manages the geometry and rendering for a single textured quad
class FskQuad extends FskRenderableObject {
  // The quad to render
  late final ReferenceBox _refBox;

  // The texture coordinates for the quad
  late final Rect _textureRect;

  /// Object that renders the quads
  final FskQuadsRenderer _renderer = FskQuadsRenderer();

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
    super.id,
    super.parentScene,
    this._refBox,
    this._textureRect,
    this._modulateColor,
    String textureId,
  ) {
    setTexture(textureId);
    setRenderer(_renderer);

    // Trigger the setter
    modulateColor = _modulateColor;
  }

  FskQuad.fromData(super.id,super.parentScene, FrameQuadData quadData) {
    setRenderer(_renderer);
    _refBox = FrameObjectData.screenRectToRefBox(quadData.screenRect);
    _textureRect = quadData.textureRect;

    // Parse the hex string or default to solid white
    final colorVector = parseHexColor(quadData.modulateColor,defaultColor: Colors.white);
    modulateColor = colorVector;

    setTexture(quadData.texture);
    premultiplyAlpha = quadData.premultiplyAlpha;
    visible = quadData.visible;
  }

  /// Rebuilds the vertex buffer object
  @override
  void doRebuild() {
    Vector2 blc = Vector2(0, -_refBox.yVector.length);
    Vector2 trc = Vector2(_refBox.xVector.length, 0);
    Quad q = _refBox.calcQuadFrom2DVectors(blc, trc);
    _renderer.setFromQuads([q], [_textureRect]);
  }
}
