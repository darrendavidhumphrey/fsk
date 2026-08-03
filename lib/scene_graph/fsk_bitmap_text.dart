import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart' show Colors;
import 'package:fsk/fsk.dart';
import '../frames/frame_data.dart';
import 'fsk_quads_renderer.dart';
import 'fsk_text_quad_builder.dart';


class FrameTextData extends FrameObjectData {
  final String font;
  final String text;
  final Rect screenRect;
  final TextHorizontalJustification hJustify;
  final TextVerticalJustification vJustify;
  final int? maxLen;
  final bool scaleToFit;
  final String? textColor;

  FrameTextData({
    required super.id,
    required super.visible,
    required this.font,
    required this.text,
    required this.screenRect,
    required this.hJustify,
    required this.vJustify,
    super.shader,
    required super.shaderParams,
    this.maxLen,
    this.scaleToFit = false,
    this.textColor,
  });
}

/// A class that manages the geometry and rendering for a single line of text
/// using a [BitmapFont].
///
/// It generates a set of quads for the text, scaled to fit within a target
/// [ReferenceBox], and renders them using a [FskQuadsRenderer].
class FskBitmapText extends Fsk2DRenderableObject with FskTransformableMixin {
  /// The string to render
  late String _text;

  /// The font to render the text with
  late BitmapFont _font;

  /// The [BitmapFont] to use for rendering.
  BitmapFont get font => _font;

  /// The target width of the text.
  late final double _width;

  /// Text justification mode
  late TextVerticalJustification _verticalJustification;
  late TextHorizontalJustification _horizontalJustification;

  /// Object that renders the quads
  final FskQuadsRenderer _renderer = FskQuadsRenderer();

  /// Optional maxLen field can truncate the text
  int? _maxLen;

  /// The color applied to modulate the text texture quads.
  late Color _textColor;

  /// Whether the text should scale up to fit the reference box.
  bool scaleToFit = false;

  static void registerWithFactories() {
    FrameObjectDataFactory.register('text', (node, anchors, parseObject) {
      final String? shaderName = node.getAttribute('shader');
      final Map<String, String> shaderParamsMap = FrameSceneParser.parseShaderParams(node.getAttribute('shaderParams'));
      final String rawHJustify = node.getAttribute('hJustify') ?? 'left';
      final String rawVJustify = node.getAttribute('vJustify') ?? 'top';

      final hJustification = TextHorizontalJustification.fromString(rawHJustify, defaultValue: TextHorizontalJustification.left);
      final vJustification = TextVerticalJustification.fromString(rawVJustify, defaultValue: TextVerticalJustification.top);

      return FrameTextData(
        id: node.getAttribute('id')!,
        visible: FrameSceneParser.isVisible(node),
        font: node.getAttribute('font')!,
        text: node.getAttribute('text')!,
        screenRect: FrameSceneParser.parseRect(node.getAttribute('screenRect')!),
        hJustify: hJustification,
        vJustify: vJustification,
        maxLen: int.tryParse(node.getAttribute('maxLen') ?? ''),
        scaleToFit: node.getAttribute('scaleToFit') == 'true',
        textColor: node.getAttribute('textColor'),
        shader: shaderName,
        shaderParams: shaderParamsMap,
      );
    });

    FskSceneObjectFactory.register(FrameTextData, (scene, data, createNode) {
      final textData = data as FrameTextData;

      final refBox = FrameObjectData.screenRectToRefBox(textData.screenRect);
      return FskBitmapText.fromData(textData.id, scene, refBox,textData);
    });
  }

  /////////////////////////////////////////////////////////////////////////////
  // Public API
  /////////////////////////////////////////////////////////////////////////////

  /// Sets a new font and flags the text for a rebuild.
  void setFont(BitmapFont font) {
    if (_font != font) {
      _font = font;

      _renderer.setTexture(font.textureInfo);
      needsRebuild = true;
    }
  }

  /// The text string to be rendered.
  String get text => _text;

  /// Sets a new text string and flags the text for a rebuild.
  set text(String newText) {
    if (_maxLen != null) {
      newText = text.substring(0, min(_maxLen!, newText.length));
    }

    if (_text != newText) {
      _text = newText;
      needsRebuild = true;
    }
  }

  // Optional max length field
  int? get maxLen => _maxLen;

  /// Sets a new max length and flags the text for a rebuild.
  set maxLen(int? value) {
    _maxLen = value;

    // Truncate the text if required
    if (_maxLen != null) {
      _text = _text.substring(0, min(_maxLen!, text.length));
    }
    needsRebuild = true;
  }

  /// Sets a new text color
  set textColor(Color value) {
    _textColor = value;
    _renderer.setModulateColor(_textColor);
  }

  TextVerticalJustification get verticalJustification => _verticalJustification;

  /// Sets a new text vertical justification and flags the text for a rebuild.
  set verticalJustification(TextVerticalJustification value) {
    _verticalJustification = value;
    needsRebuild = true;
  }

  TextHorizontalJustification get horizontalJustification =>
      _horizontalJustification;

  /// Sets a new text horizontal justification and flags the text for a rebuild.
  set horizontalJustification(TextHorizontalJustification value) {
    _horizontalJustification = value;
    needsRebuild = true;
  }

  /////////////////////////////////////////////////////////////////////////////
  // Constructor
  /////////////////////////////////////////////////////////////////////////////
  FskBitmapText(
    super.id,
    super.parentScene,
    this._font,
    this._text,
    super.refBox, {
    this._textColor = Colors.white,
    this._verticalJustification = TextVerticalJustification.bottom,
    this._horizontalJustification = TextHorizontalJustification.left,
    this._maxLen,
    this.scaleToFit = false,
    FskShaderMaterial? shaderMaterial,
  }) : _width = refBox.xVector.length {
    setRenderer(_renderer);
    _renderer.setTexture(font.textureInfo);

    if (shaderMaterial != null) {
      this.shaderMaterial = shaderMaterial;
    }

    // Trigger the setter
    textColor = _textColor;
  }

  FskBitmapText.fromData(super.id,super.parentScene, super.refBox,FrameTextData textData, {FskShaderMaterial? shaderMaterial}) {
    setRenderer(_renderer);
    _width = refBox.xVector.length;

    if (shaderMaterial != null) {
      this.shaderMaterial = shaderMaterial;
    }

    var fontToUse = BitmapFontManager().getFont(textData.font);
    if (fontToUse == null) {
      fontToUse = BitmapFontManager().defaultFont;
      logWarning("Font not found for $id, using default font");
    }
    _font = fontToUse!;
    _renderer.setTexture(font.textureInfo);

    _text = textData.text;
    textColor = parseHexColor(textData.textColor, defaultColor: Colors.white);
    horizontalJustification = textData.hJustify;
    verticalJustification = textData.vJustify;
    maxLen = textData.maxLen;
    scaleToFit = textData.scaleToFit;
    visible = textData.visible;
  }

  @override
  void rebuildPipelineIfNeeded() {
    _renderer.rebuildPipeline();
  }

  /// Rebuilds the vertex buffer object
  @override
  void doRebuild() {
    // If anything is wrong, just bail out and create an empty set
    if ((!font.isInitialized) || (text.isEmpty)) {
      _renderer.setFromUnrolledQuads(0, Float32List(0));
      return;
    }

    /// Rebuilds the list of geometry and texture quads for the current text string.
    FskBitmapTextQuadBuilder quadBuilder = FskBitmapTextQuadBuilder(
      text: text,
      font: font,
      screenRect: refBox,
      horizontalJustification: horizontalJustification,
      verticalJustification: verticalJustification,
      width: _width,
      scaleToFit: scaleToFit,
    );

    final result = quadBuilder.build();
    _renderer.setFromUnrolledQuads(result.numQuads, result.vertexData);
  }
}
