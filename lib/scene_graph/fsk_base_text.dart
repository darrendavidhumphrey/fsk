import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import '../bitmap_fonts/texture_font.dart';
import '../bitmap_fonts/font_manager.dart';
import '../geometry/mesh_hit_tester.dart';
import '../gpu/fsk_shader_material.dart';
import 'fsk_scene_object.dart';
import 'fsk_depth_state.dart';
import 'fsk_quads_renderer.dart';
import 'fsk_texture_text_quad_builder.dart';
import 'fsk_text_alignment.dart';
import 'fsk_transformable.dart';
import '../util.dart';
import '../skins/skin_data.dart';

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

abstract class FskBaseText extends Fsk2DRenderableObject
    with FskTransformableMixin, FskDepthStateMixin {
  /// The string to render
  late String _text;

  /// The font to render the text with
  late TextureFont _font;

  /// The [TextureFont] to use for rendering.
  TextureFont get font => _font;

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

  /// Cache the count of quads to be rendered
  int numQuads = 0;

  void _onFontChanged() {
    if (_font.isInitialized) {
      _renderer.setTexture(_font.textureInfo);
      setNeedsRebuild();
      parentScene.setNeedsUpdate();
    }
  }

  /// Sets a new font and flags the text for a rebuild.
  void setFont(TextureFont font) {
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
      newText = newText.substring(0, min(_maxLen!, newText.length));
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

  /// The color applied to modulate the text texture quads.
  Color get textColor => _textColor;

  /// Sets a new text color
  set textColor(Color value) {
    if (_textColor != value) {
      _textColor = value;
      parentScene.setNeedsUpdate();
    }
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

  FskBaseText(
    super.id,
    super.parentScene,
    super.refBox, {
    required TextureFont font,
    required this._text,
    this._textColor = Colors.white,
    this._verticalJustification = TextVerticalJustification.bottom,
    this._horizontalJustification = TextHorizontalJustification.left,
    this._maxLen,
    this.scaleToFit = false,
    FskShaderMaterial? shaderMaterial,
    bool depthTestEnabled = false,
    bool depthWriteEnabled = false,
  }) : _font = font,
       _width = refBox.xVector.length {
    isPickable = false;
    setRenderer(_renderer);
    _renderer.setTexture(font.textureInfo);

    if (shaderMaterial != null) {
      this.shaderMaterial = shaderMaterial;
    }

    _font.addListener(_onFontChanged);

    if (_font.isInitialized) {
      _renderer.setTexture(_font.textureInfo);
      needsRebuild = true;
    }

    setDepthState(
      depthTestEnabled: depthTestEnabled,
      depthWriteEnabled: depthWriteEnabled,
      depthCompareOperation: gpu.CompareFunction.lessEqual,
    );
  }

  FskBaseText.fromData(
    super.id,
    super.parentScene,
    super.refBox,
    SkinTextData textData, {
    FskShaderMaterial? shaderMaterial,
  }) : _width = refBox.xVector.length {
    isPickable = false;
    setRenderer(_renderer);

    if (shaderMaterial != null) {
      this.shaderMaterial = shaderMaterial;
    }

    var fontToUse = FontManager().getFont(textData.font);
    if (fontToUse == null) {
      fontToUse = FontManager().defaultFont;
      logWarning("Font not found for $id, using default font");
    }
    _font = fontToUse!;
    _font.addListener(_onFontChanged);

    if (_font.isInitialized) {
      _renderer.setTexture(_font.textureInfo);
      needsRebuild = true;
    }

    _text = textData.text;
    _textColor = parseHexColor(textData.textColor, defaultColor: Colors.white);
    _horizontalJustification = textData.hJustify;
    _verticalJustification = textData.vJustify;
    _maxLen = textData.maxLen;
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
  List<FskHitDetails> doHitTest(
    vm.Ray ray, {
    FskHitTestMode mode = FskHitTestMode.closest,
  }) {
    final vm.Vector3? hit = refBox.rayIntersect(ray);
    if (hit == null) return [];

    return [
      FskHitDetails(
        hitObject: this,
        hitPoint: hit,
        distance: ray.origin.distanceTo(hit),
        normal: refBox.normal,
        hitData: null,
      ),
    ];
  }

  @override
  void draw(
    gpu.RenderPass renderPass,
    gpu.HostBuffer transients,
    vm.Matrix4 pMatrix,
    vm.Matrix4 mvMatrix,
    Size viewportSize,
  ) {
    if (!renderer.verticesDownloaded) {
      needsRebuild = true;
    }
    rebuildGeometryIfNeeded();
    if ((numQuads == 0) || needsRebuild) {
      // Nothing to draw
      return;
    }
    super.draw(renderPass, transients, pMatrix, mvMatrix, viewportSize);
  }

  /// Rebuilds the vertex buffer object
  @override
  void doRebuild() {
    if (!font.isInitialized || text.isEmpty) {
      needsRebuild = true;
      numQuads = 0;
      return;
    }

    FskTextureTextQuadBuilder quadBuilder = FskTextureTextQuadBuilder(
      text: text,
      font: font,
      screenRect: refBox,
      horizontalJustification: horizontalJustification,
      verticalJustification: verticalJustification,
      width: _width,
      scaleToFit: scaleToFit,
    );

    final result = quadBuilder.build();
    numQuads = result.numQuads;

    if (result.numQuads != 0) {
      _renderer.setFromUnrolledQuads(result.numQuads, result.vertexData);
    }
  }
}
