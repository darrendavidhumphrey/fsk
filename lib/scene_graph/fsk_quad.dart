import 'dart:ui';
import 'package:flutter/material.dart' show Colors;
import 'package:vector_math/vector_math.dart' hide Colors;
import '../frames/frame_data.dart';
import '../fsk.dart';
import 'fsk_quads_renderer.dart';

class FrameQuadData extends FrameObjectData {
  final String texture;
  final Rect screenRect;
  final Rect textureRect;
  final bool premultiplyAlpha;
  final String? modulateColor;

  FrameQuadData({
    required super.id,
    required super.visible,
    super.shader,
    required super.shaderParams,
    required this.texture,
    required this.screenRect,
    required this.textureRect,
    this.modulateColor,
    this.premultiplyAlpha = false,
  });
}

/// A class that manages the geometry and rendering for a single textured quad
class FskQuad extends Fsk2DRenderableObject {
  // The texture coordinates for the quad
  late final Rect _textureRect;

  /// Object that renders the quads
  final FskQuadsRenderer _renderer = FskQuadsRenderer();

  bool _premultiplyAlpha = true;
  Color _modulateColor = const Color(0xFFFFFFFF);

  static void registerWithFactories() {
    FrameObjectDataFactory.register('quad', (node, anchors, parseObject) {
      final String? shaderName = node.getAttribute('shader');
      final Map<String, String> shaderParamsMap = FrameSceneParser.parseShaderParams(node.getAttribute('shaderParams'));
      return FrameQuadData(
        id: node.getAttribute('id')!,
        visible: FrameSceneParser.isVisible(node),
        texture: node.getAttribute('texture')!,
        screenRect: FrameSceneParser.parseRect(node.getAttribute('screenRect')!),
        textureRect: FrameSceneParser.parseTextureRect(node.getAttribute('textureRect')),
        premultiplyAlpha: node.getAttribute('premultiplyAlpha') == 'true',
        shader: shaderName,
        modulateColor: node.getAttribute('modulateColor'),
        shaderParams: shaderParamsMap,
      );
    });

    FskSceneObjectFactory.register(FrameQuadData, (scene, data, createNode) {
      final quadData = data as FrameQuadData;
      final refBox = FrameObjectData.screenRectToRefBox(quadData.screenRect);
      return FskQuad.fromData(quadData.id, scene, refBox, quadData);
    });
  }

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
    super.refBox,
    this._textureRect,
    this._modulateColor,
    String textureId,
  ) {
    setTexture(textureId);
    setRenderer(_renderer);

    // Trigger the setter
    modulateColor = _modulateColor;
  }

  FskQuad.fromData(super.id,super.parentScene,super.refBox, FrameQuadData quadData) {
    setRenderer(_renderer);
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
    Vector2 blc = Vector2(0, -refBox.yVector.length);
    Vector2 trc = Vector2(refBox.xVector.length, 0);
    Quad q = refBox.calcQuadFrom2DVectors(blc, trc);
    _renderer.setFromQuads([q], [_textureRect]);
  }
}
