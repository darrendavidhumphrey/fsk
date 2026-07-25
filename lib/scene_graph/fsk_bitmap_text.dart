import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' hide Colors;
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
class FskBitmapText extends FskRenderableObject {
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
  late double _height;

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
  Color _textColor = const Color(0xFFFFFFFF);

  void setTextColor(Color value) {
    _textColor = value;
    _needsRebuild = true;
  }

  /// The vertex buffer object that holds the geometry for rendering.
  final VertexBuffer _vbo = VertexBuffer.v3t2();

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
    this._textColor = const Color(0xFFFFFFFF),
    this._verticalJustification = TextVerticalJustification.bottom,
    this._horizontalJustification = TextHorizontalJustification.left,
    this._maxLen,
  }) {
    // Cache the target width from the reference box.
    _width = _screenRect.xVector.length;
    _height = _screenRect.yVector.length;
  }

  FskBitmapText.origin({
    required this._text,
    required BitmapFont font,
    Vector3? origin,
    Color? color,
    double? width,
    double? height,
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

    if (height == null) {
      _height = _font!.lineHeight.toDouble();
    } else {
      _height = height;
    }
    _screenRect = ReferenceBox(
      origin,
      Vector3(_width, 0, 0),
      Vector3(0, _height, 0),
      Vector3(0, 0, 1),
    );
    if (color != null) {
      setTextColor(color);
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
  void init() {
    rebuild();
  }

  /// Rebuilds the vertex buffer object if the text or font has changed.
  @override
  void rebuild() {
    // Guard against unnecessary, expensive rebuilds.
    if (!_needsRebuild) return;

    rebuildQuads();

    int vertexCount = quads.length * 6; // Two triangles per character quad.

    Float32List? vertexTexCoordArray = _vbo.requestBuffer(vertexCount);

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

    // Pass 1: Gather layout information and calculate total width
    final (layoutData, lineLength) = _gatherLayoutData();
    if (lineLength == 0) return;

    // Pass 2: Pre-allocate lists and generate scaled quads
    final ratio = _allocateListsAndCalculateRatio(layoutData.length, lineLength);

    // Pass 3: Horizontal Justification
    final currentX = _calculateHorizontalJustification(ratio, lineLength);

    // Pass 4: Vertical Justification
    final unscaledVAdjust = _calculateVerticalJustification(ratio);

    // Pass 5: Quad Construction Loop (CRITICAL: Make sure unscaledVAdjust is passed here!)
    _constructQuads(layoutData, ratio, currentX, unscaledVAdjust);
  }


  // --- Refactored Helper Methods ---

  /// Pass 1: Gathers character bounding information and computes unscaled text line length.
  (List<({CharInfo char, double kerning})>, double) _gatherLayoutData() {
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

    return (layoutData, lineLength);
  }

  /// Pass 2: Initializes backing collections and limits scale bounds to container constraints.
  double _allocateListsAndCalculateRatio(int characterCount, double lineLength) {
    quads = List<Quad>.filled(characterCount, Quad());
    textureQuads = List<Rect>.filled(characterCount, Rect.zero);

    double ratio = (lineLength > 0) ? _width / lineLength : 1.0;
    return min(1.0, ratio);
  }

  /// Pass 3: Computes the starting horizontal offset inside unscaled canvas bounds.
  double _calculateHorizontalJustification(double ratio, double lineLength) {
    final double unscaledBoxWidth = _width / ratio;

    switch (horizontalJustification) {
      case TextHorizontalJustification.left:
        return 0.0;
      case TextHorizontalJustification.center:
        return (unscaledBoxWidth - lineLength) / 2;
      case TextHorizontalJustification.right:
        return unscaledBoxWidth - lineLength;
    }
  }
  /// Pass 4: Computes the vertical layout anchor corrected for the box origin.
  double _calculateVerticalJustification(double ratio) {
    final double boxHeight = _screenRect.yVector.length;
    final double unscaledLineHeight = _font!.lineHeight.toDouble();
    final double unscaledBoxHeight = boxHeight / ratio;

    switch (verticalJustification) {
      case TextVerticalJustification.top:
      // Text window sits flush with the ceiling (0.0)
        return -unscaledLineHeight;

      case TextVerticalJustification.center:
      // Centers the line block cleanly within the reference space
        return (-unscaledBoxHeight / 2.0) - (unscaledLineHeight / 2.0);

      case TextVerticalJustification.bottom:
      // Move down by a full box height step to drop it below the center horizon
        return -unscaledLineHeight;
    }
  }


  /// Pass 5: Builds spatial transformation matrices and coordinates texture mapping vectors.
  void _constructQuads(
      List<({CharInfo char, double kerning})> layoutData,
      double ratio,
      double startX,
      final double unscaledVAdjust, // Caught from Pass 4 calculation block
      ) {
    double currentX = startX;
    final double unscaledLineHeight = _font!.lineHeight.toDouble();

    for (int i = 0; i < layoutData.length; i++) {
      final data = layoutData[i];
      final charInfo = data.char;
      final kerning = data.kerning;

      final left = currentX;
      final right = left + charInfo.region.width;

      final double lineTopCeiling = unscaledVAdjust + unscaledLineHeight;
      double qTop = lineTopCeiling - charInfo.yOffset;
      double qBottom = qTop - charInfo.region.height;

      final blc = Vector2(left * ratio, qBottom * ratio);
      final trc = Vector2(right * ratio, qTop * ratio);

      quads[i] = _screenRect.calcQuadFrom2DVectors(blc, trc);

      final tLeft = charInfo.region.left / _font!.scaleW;
      final tTop = charInfo.region.top / _font!.scaleH;
      final tRight = (charInfo.region.left + charInfo.region.width) / _font!.scaleW;
      final tBottom = (charInfo.region.top + charInfo.region.height) / _font!.scaleH;

      textureQuads[i] = Rect.fromLTRB(tLeft, tTop, tRight, tBottom);

      currentX += charInfo.xAdvance + kerning;
    }
  }


  /// Rebuilds the list of geometry and texture quads for the current text string.
  void rebuildQuadsOld() {
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
  void drawSetup(gpu.RenderPass renderPass,Matrix4 pMatrix, Matrix4 mvMatrix) {
    if (font == null)  return;

    /*
    // TODO: bind the shader and set the uniforms

    gls.useProgram(shader!.program);
    shader!.setMatrixUniforms(pMatrix, mvMatrix);
    _textColorUniformValue?.value = _textColor;
    applyShaderParams();

    gls.setBlend(true);
    gls.setTexturingEnabled(true);
    gls.activeTexture(WebGL.TEXTURE0);
    gls.setDepthTest(false);

    shader!.setTextureSampler(0);

    gls.blendFuncSeparate(
      WebGL.ONE,
      WebGL.ONE_MINUS_SRC_ALPHA,
      WebGL.ONE,
      WebGL.ONE_MINUS_SRC_ALPHA,
    );

     */
  }

  @override
  void draw(gpu.RenderPass renderPass) {
    if ((font == null) || (!font!.isInitialized) ) return;

    // TODO: TEST FORCE always rebuild
    rebuild();

/*
    gls.bindTexture(WebGL.TEXTURE_2D, font!.textureInfo!.texture);

    _vbo.bind();
    _vbo.drawTriangles();

 */
  }
}
