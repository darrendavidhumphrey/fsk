import 'dart:math';
import 'package:flutter/material.dart'; // Adds the 'Colors' constant utility
import 'package:flutter_angle/flutter_angle.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../fsk.dart';

enum TextVerticalJustification {
  top('top'),
  center('center'),
  bottom('bottom');

  // The underlying string value associated with each enum value
  final String value;

  // Enhanced enum constructor
  const TextVerticalJustification(this.value);

  /// Parses a string into a [TextVerticalJustification].
  /// Returns the matching enum, or [defaultValue] if no match is found.
  static TextVerticalJustification fromString(
    String input, {
    TextVerticalJustification defaultValue = TextVerticalJustification.top,
  }) {
    final cleanInput = input.trim().toLowerCase();

    return TextVerticalJustification.values.firstWhere(
      (element) => element.value == cleanInput,
      orElse: () => defaultValue,
    );
  }
}

enum TextHorizontalJustification {
  left('left'),
  center('center'),
  right('right');

  // The underlying string value associated with each enum value
  final String value;

  // Enhanced enum constructor
  const TextHorizontalJustification(this.value);

  /// Parses a string into a [TextHorizontalJustification].
  /// Returns the matching enum, or [defaultValue] if no match is found.
  static TextHorizontalJustification fromString(
    String input, {
    TextHorizontalJustification defaultValue = TextHorizontalJustification.left,
  }) {
    final cleanInput = input.trim().toLowerCase();

    return TextHorizontalJustification.values.firstWhere(
      (element) => element.value == cleanInput,
      orElse: () => defaultValue,
    );
  }
}

/// A class that manages the geometry and rendering for a single line of text
/// using a [BitmapFont].
///
/// It generates a set of quads for the text, scaled to fit within a target
/// [ReferenceBox], and manages the associated [VertexBuffer] for rendering.
class FskBitmapText extends FskSceneObject {
  /// The list of 3D quads representing the geometry of each character.
  List<Quad> quads = [];

  /// The list of texture coordinate rectangles corresponding to each character quad.
  List<Rect> textureQuads = [];

  String _text;

  /// The [ReferenceBox] that defines the target area for the text to be rendered into.
  late final ReferenceBox _screenRect;

  bool _needsRebuild = true;

  /// A flag indicating if the text geometry needs to be recalculated.
  bool get needsRebuild => _needsRebuild;

  /// The text string to be rendered.
  String get text => _text;

  BitmapFont? _font;

  /// The [BitmapFont] to use for rendering.
  BitmapFont? get font => _font;

  late double _width;

  // Optional max length field
  int? _maxLen;
  int? get maxLen => _maxLen;
  set maxLen(int? value) {
    _maxLen = value;

    // Truncate the text if required
    if (_maxLen != null) {
      _text = _text.substring(0, min(_maxLen!, text.length));
    }
    _needsRebuild = true;
  }

  /// The color applied to modulate the text texture quads.
  Color textColor = const Color(0xFFFFFFFF);

  /// The vertex buffer object that holds the geometry for rendering.
  final VertexBuffer _vbo = VertexBuffer.v3t2();

  // One shader shared by all text instances
  static GlslShader? _shader;

  GlslShader? get _activeShader => _shader;

  void setShader(GlslShader? s) {
    _shader = s ?? FSK().shaders.getShader<BitmapTextShader>();
  }

  TextVerticalJustification _verticalJustification;

  TextVerticalJustification get verticalJustification => _verticalJustification;

  set verticalJustification(TextVerticalJustification value) {
    _verticalJustification = value;
    _needsRebuild = true;
  }

  TextHorizontalJustification _horizontalJustification;
  TextHorizontalJustification get horizontalJustification =>
      _horizontalJustification;
  set horizontalJustification(TextHorizontalJustification value) {
    _horizontalJustification = value;
    _needsRebuild = true;
  }

  /// Creates a [FskBitmapText] object.
  FskBitmapText(
    this._font,
    this._text,
    this._screenRect, {
    this.textColor = const Color(0xFFFFFFFF),
    this._verticalJustification = TextVerticalJustification.bottom,
    this._horizontalJustification = TextHorizontalJustification.left,
    this._maxLen,
  }) {

    // Default to the bitmap texture shader if not set.
    _shader ??= FSK().shaders.getShader<BitmapTextShader>();

    // Cache the target width from the reference box.
    _width = _screenRect.xVector.length;
  }

  FskBitmapText.origin({
    required this._text,
    required BitmapFont font,
    Vector3? origin,
    Color? color,
    double? width,
    this._verticalJustification = TextVerticalJustification.bottom,
    this._horizontalJustification = TextHorizontalJustification.left,
    this._maxLen,
  }) {
    origin ??= Vector3.zero();
    _font = font;

    if (width == null) {
      _width = _font!.widthOfString(_text);
    } else {
      _width = width;
    }
    _screenRect = ReferenceBox(
      origin,
      Vector3(_width, 0, 0),
      Vector3(0, _width, 0),
      Vector3(0, 0, 1),
    );
    if (color != null) {
      textColor = color;
    }
  }

  /// Disposes the vertex buffer associated with this text.
  @override
  void dispose() {
    _vbo.dispose();
  }

  /// Sets a new font and flags the text for a rebuild.
  void setFont(BitmapFont font) {
    if (_font != font) {
      _font = font;
      _needsRebuild = true;
    }
  }

  /// Sets a new text string and flags the text for a rebuild.
  void setText(String text) {

    if (_maxLen != null) {
      text = text.substring(0, min(_maxLen!, text.length));
    }

    if (_text != text) {
      _text = text;
      _needsRebuild = true;
    }
  }

  @override
  void applyShaderParams(Map<String, String> params) {
    final activeShader = _activeShader;
    if (activeShader != null) {
      params.forEach((name, value) {
        activeShader.setUniformValue(name, value);
      });
    }
  }

  @override
  void init(GlStateManager gls) {
    _vbo.init(gls);
    rebuild(gls);
  }

  /// Rebuilds the vertex buffer object if the text or font has changed.
  @override
  void rebuild(GlStateManager gls) {
    // Guard against unnecessary, expensive rebuilds.
    if (!_needsRebuild) return;

    rebuildQuads();

    int vertexCount = quads.length * 6; // Two triangles per character quad.

    Float32Array? vertexTexCoordArray = _vbo.requestBuffer(vertexCount);

    if (vertexTexCoordArray != null) {
      // Fill the VBO with the generated quad data.
      VboFiller.addTexturedQuads(quads, textureQuads, _vbo);
    }

    _vbo.setActiveVertexCount(vertexCount);
    _needsRebuild = false; // Reset the flag after a successful rebuild.
  }

  /// Rebuilds the list of geometry and texture quads for the current text string.
  void rebuildQuads() {
    if ((text.isEmpty) || (font == null)) {
      quads = [];
      textureQuads = [];
      return;
    }

    // --- Pass 1: Gather layout information and calculate total width ---
    final layoutData = <({CharInfo char, double kerning})>[];
    double lineLength = 0;

    for (int i = 0; i < _text.length; i++) {
      final charInfo = _font!.chars[_text[i]];
      if (charInfo == null) continue;

      double kerning = 0.0;
      if ((i + 1) < _text.length) {
        kerning = _font!.kerningForPair(
          _text.codeUnitAt(i),
          _text.codeUnitAt(i + 1),
        );
      }
      layoutData.add((char: charInfo, kerning: kerning));
      lineLength += charInfo.xAdvance + kerning;
    }

    // Nothing to render
    if (lineLength == 0) {
      return;
    }

    // --- Pass 2: Pre-allocate lists and generate scaled quads ---
    final characterCount = layoutData.length;
    quads = List<Quad>.filled(characterCount, Quad());
    textureQuads = List<Rect>.filled(characterCount, Rect.zero);

    // Calculate the ratio needed to fit or size the text horizontally
    double ratio = (lineLength > 0) ? _width / lineLength : 1.0;

    // Don't let characters get bigger than the box
    ratio = min(1.0, ratio);

    // --- Pass 3: Horizontal Justification (Calculated in Pure Unscaled Font Space) ---
    // Bring target width into unscaled font space to prevent drift on small ratios
    final double unscaledBoxWidth = _width / ratio;
    double currentX = 0.0;

    switch (horizontalJustification) {
      case TextHorizontalJustification.left:
        // Text starts flush at X = 0
        currentX = 0.0;
        break;
      case TextHorizontalJustification.center:
        // Centers the line block cleanly within the unscaled virtual width
        currentX = (unscaledBoxWidth - lineLength) / 2;
        break;
      case TextHorizontalJustification.right:
        // Pushes the entire line layout flush against the right container wall
        currentX = unscaledBoxWidth - lineLength;
        break;
    }

    // --- Pass 4: Vertical Justification (Calculated in Pure Unscaled Font Space) ---
    final double boxHeight = _screenRect.yVector.length;
    final double unscaledLineHeight = _font!.lineHeight.toDouble();

    // Map the box height into unscaled font space using the ratio
    final double unscaledBoxHeight = boxHeight / ratio;
    double unscaledVAdjust = 0.0;

    switch (verticalJustification) {
      case TextVerticalJustification.top:
        // Pushes the line block to the top ceiling edge of the container box
        unscaledVAdjust = unscaledBoxHeight - unscaledLineHeight;
        break;
      case TextVerticalJustification.center:
        // Centers the line block cleanly within the unscaled virtual container height
        unscaledVAdjust = (unscaledBoxHeight - unscaledLineHeight) / 2;
        break;
      case TextVerticalJustification.bottom:
        // Anchors the line block directly to the floor of the box (Y = 0)
        unscaledVAdjust = 0.0;
        break;
    }

    // --- Pass 5: Quad Construction Loop ---
    for (int i = 0; i < characterCount; i++) {
      final data = layoutData[i];
      final charInfo = data.char;
      final kerning = data.kerning;

      // Horizontal boundaries (unscaled)
      final left = currentX;
      final right = left + charInfo.region.width;

      // Vertical boundaries (calculated entirely in unscaled space)
      // Top of our glyph is the line cell start + cell height - font yOffset
      double qTop = (unscaledVAdjust + unscaledLineHeight) - charInfo.yOffset;

      // The bottom of the glyph is physically below qTop, so we subtract the visual height
      double qBottom = qTop - charInfo.region.height;

      // To shift the quad anchor relative to the reference frame box,
      // do it in unscaled coordinates so the shift scales uniformly with the ratio!
      qTop -= unscaledBoxHeight;
      qBottom -= unscaledBoxHeight;

      // Keep points configured for Y-up projection context
      final unscaledQuad = Quad.points(
        Vector3(left, qBottom, 0), // Bottom-left
        Vector3(right, qBottom, 0), // Bottom-right
        Vector3(right, qTop, 0), // Top-right
        Vector3(left, qTop, 0), // Top-left
      );

      // Uniformly scale the 2D coordinates using the ratio multiplier
      final blc = Vector2(
        unscaledQuad.point0.x * ratio,
        unscaledQuad.point0.y * ratio,
      );
      final trc = Vector2(
        unscaledQuad.point2.x * ratio,
        unscaledQuad.point2.y * ratio,
      );

      // Transform the 2D scaled quad into the 3D space of the reference box
      quads[i] = _screenRect.calcQuadFrom2DVectors(blc, trc);

      // Calculate standard normalized texture coordinates from the font atlas region
      final tLeft = charInfo.region.left / _font!.scaleW;
      final tTop = charInfo.region.top / _font!.scaleH;
      final tRight =
          (charInfo.region.left + charInfo.region.width) / _font!.scaleW;
      final tBottom =
          (charInfo.region.top + charInfo.region.height) / _font!.scaleH;
      textureQuads[i] = Rect.fromLTRB(tLeft, tTop, tRight, tBottom);

      // Advance the cursor position for the next character
      currentX += charInfo.xAdvance + kerning;
    }
  }

  @override
  void drawSetup(GlStateManager gls, Matrix4 pMatrix, Matrix4 mvMatrix) {
    final activeShader = _activeShader;

    if ((font == null) || (activeShader == null)) return;

    gls.useProgram(activeShader.program);
    ShaderList.setMatrixUniforms(activeShader, pMatrix, mvMatrix);

    gls.setBlend(true);
    gls.setTexturingEnabled(true);
    gls.activeTexture(WebGL.TEXTURE0);
    gls.setDepthTest(false);

    if (activeShader is BitmapTextShader) {
      activeShader.setTextColor(textColor);
    }

    gls.blendFuncSeparate(
      WebGL.ONE,
      WebGL.ONE_MINUS_SRC_ALPHA,
      WebGL.ONE,
      WebGL.ONE_MINUS_SRC_ALPHA,
    );
    activeShader.setTextureSampler(0);
  }

  @override
  void draw(GlStateManager gls) {
    final activeShader = _activeShader;
    if ((font == null) || (!font!.isInitialized) || (activeShader == null)) return;

    gls.bindTexture(WebGL.TEXTURE_2D, font!.textureInfo!.texture);

    _vbo.bind();
    _vbo.drawTriangles();
  }
}
