import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:fsk/scene_graph/fsk_depth_state.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../skins/skin_data.dart';
import 'fsk_quads_renderer.dart';
import 'fsk_text_quad_builder.dart';


class SkinTextData extends SkinObjectData {
  final String font;
  final String text;
  final Rect screenRect;
  final TextHorizontalJustification hJustify;
  final TextVerticalJustification vJustify;
  final int? maxLen;
  final bool scaleToFit;
  final String? textColor;

  SkinTextData({
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
class FskBitmapText extends Fsk2DRenderableObject with FskTransformableMixin, FskDepthStateMixin {
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

  @override
  FskQuadsRenderer get renderer => _renderer;

  /// Optional maxLen field can truncate the text
  int? _maxLen;

  /// The color applied to modulate the text texture quads.
  late Color _textColor;

  /// Whether the text should scale up to fit the reference box.
  bool scaleToFit = false;

  void _onFontChanged() {
    logInfo("$id _onFontChanged called initialized=${_font.isInitialized} font=${_font.name}");
    if (_font.isInitialized) {
      _renderer.setTexture(_font.textureInfo);
      setNeedsRebuild();
      parentScene.setNeedsUpdate();
    }
  }

  static void registerWithFactories() {
    SkinObjectDataFactory.register('text', (node, anchors, parseObject) {
      final String? shaderName = node.getAttribute('shader');
      final Map<String, String> shaderParamsMap = SkinSceneParser.parseShaderParams(node.getAttribute('shaderParams'));
      final String rawHJustify = node.getAttribute('hJustify') ?? 'left';
      final String rawVJustify = node.getAttribute('vJustify') ?? 'top';

      final hJustification = TextHorizontalJustification.fromString(rawHJustify, defaultValue: TextHorizontalJustification.left);
      final vJustification = TextVerticalJustification.fromString(rawVJustify, defaultValue: TextVerticalJustification.top);

      return SkinTextData(
        id: node.getAttribute('id')!,
        visible: SkinSceneParser.isVisible(node),
        font: node.getAttribute('font')!,
        text: node.getAttribute('text')!,
        screenRect: SkinSceneParser.parseRect(node.getAttribute('screenRect')!),
        hJustify: hJustification,
        vJustify: vJustification,
        maxLen: int.tryParse(node.getAttribute('maxLen') ?? ''),
        scaleToFit: node.getAttribute('scaleToFit') == 'true',
        textColor: node.getAttribute('textColor'),
        shader: shaderName,
        shaderParams: shaderParamsMap,
      );
    });

    FskSceneObjectFactory.register(SkinTextData, (scene, data, createNode) {
      final textData = data as SkinTextData;

      final refBox = SkinObjectData.screenRectToRefBox(textData.screenRect);
      return FskBitmapText.fromData(textData.id, scene, refBox,textData);
    });
  }

  /////////////////////////////////////////////////////////////////////////////
  // Public API
  /////////////////////////////////////////////////////////////////////////////

  /// Sets a new font and flags the text for a rebuild.
  void setFont(BitmapFont font) {
    if (_font != font) {
      _font.removeListener(_onFontChanged);
      _font = font;
      _font.addListener(_onFontChanged);

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
    super.refBox, {
    required BitmapFont font,
    required this._text,
    this._textColor = Colors.white,
    this._verticalJustification =
        TextVerticalJustification.bottom,
    this._horizontalJustification =
        TextHorizontalJustification.left,
    this._maxLen,
    this.scaleToFit = false,
    FskShaderMaterial? shaderMaterial,
    bool depthTestEnabled = false,
    bool depthWriteEnabled = false,
  })  : _font = font,
        _width = refBox.xVector.length {
    isPickable = false;
    setRenderer(_renderer);
    _renderer.setTexture(font.textureInfo);

    if (shaderMaterial != null) {
      this.shaderMaterial = shaderMaterial;
    }

    // Explicitly calling this.textColor to call the setter method and trigger a rebuild
    // ignore: unnecessary_this
    this.textColor = _textColor;

    _font.addListener(_onFontChanged);

    setDepthState(
      depthTestEnabled: depthTestEnabled,
      depthWriteEnabled: depthWriteEnabled,
      depthCompareOperation: gpu.CompareFunction.lessEqual,
    );
  }

  FskBitmapText.fromData(super.id, super.parentScene, super.refBox,
      SkinTextData textData,
      {FskShaderMaterial? shaderMaterial}) {
    isPickable = false;
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
    _font.addListener(_onFontChanged);
    _renderer.setTexture(font.textureInfo);

    _text = textData.text;
    textColor = parseHexColor(textData.textColor, defaultColor: Colors.white);
    horizontalJustification = textData.hJustify;
    verticalJustification = textData.vJustify;
    maxLen = textData.maxLen;
    scaleToFit = textData.scaleToFit;
    visible = textData.visible;

    setDepthState(
      depthTestEnabled: false,
      depthWriteEnabled: false,
      depthCompareOperation: gpu.CompareFunction.lessEqual,
    );
  }

  @override
  void dispose() {
    _font.removeListener(_onFontChanged);
    super.dispose();
  }

  @override
  void rebuildPipelineIfNeeded() {
    _renderer.rebuildPipeline();
  }

  @override
  vm.Aabb3 getAabb() {
    final vm.Aabb3 bounds = vm.Aabb3.minMax(
      vm.Vector3.copy(refBox.cachedQuad.point0),
      vm.Vector3.copy(refBox.cachedQuad.point0),
    );
    final quad = refBox.cachedQuad;
    bounds.hullPoint(quad.point1);
    bounds.hullPoint(quad.point2);
    bounds.hullPoint(quad.point3);
    return bounds;
  }

  @override
  List<FskHitDetails> doHitTest(vm.Ray ray,
      {FskHitTestMode mode = FskHitTestMode.closest}) {
    final vm.Vector3? hit = refBox.rayIntersect(ray);
    if (hit == null) return [];

    return [
      FskHitDetails(
        hitObject: this,
        hitPoint: hit,
        distance: ray.origin.distanceTo(hit),
        normal: refBox.normal,
        hitData: null,
      )
    ];
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
