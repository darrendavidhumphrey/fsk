import 'dart:math';
import 'dart:ui';
import 'package:vector_math/vector_math.dart' hide Colors;
import '../fsk.dart';

class FskBitmapTextQuadBuilderResult {
  final List<Quad> quads;
  final List<Rect> textureQuads;

  FskBitmapTextQuadBuilderResult(this.quads, this.textureQuads);
  FskBitmapTextQuadBuilderResult.empty() : quads = [], textureQuads = [];
}

class CharLayoutInfo {
  final CharInfo char;
  final double kerning;
  CharLayoutInfo({required this.char, required this.kerning});
}

class FskBitmapTextQuadBuilder {
  final String text;
  final BitmapFont font;
  final ReferenceBox screenRect;
  final TextHorizontalJustification horizontalJustification;
  final TextVerticalJustification verticalJustification;
  final double _width;

  // Computed Internally
  late double _ratio;
  late double _lineLength;

  final List<CharLayoutInfo> layoutData = [];
  late List<Quad> quads = [];
  late List<Rect> textureQuads = [];

  FskBitmapTextQuadBuilder({
    required this.text,
    required this.font,
    required this.screenRect,
    required this._width,
    required this.horizontalJustification,
    required this.verticalJustification,
  });

  FskBitmapTextQuadBuilderResult build() {
    layoutData.clear();
    quads.clear();
    textureQuads.clear();

    _lineLength = 0;
    _ratio = 0;

    if (text.isEmpty) {
      return FskBitmapTextQuadBuilderResult.empty();
    }

    // Pass 1: Gather layout information and calculate total width
    _gatherLayoutData();

    if (_lineLength == 0) {
      return FskBitmapTextQuadBuilderResult.empty();
    }

    // Pass 2: Pre-allocate lists and generate scaled quads
    _allocateListsAndCalculateRatio();

    // Pass 3: Horizontal Justification
    final currentX = _calculateHorizontalJustification();

    // Pass 4: Vertical Justification
    final unscaledVAdjust = _calculateVerticalJustification();

    // Pass 5: Quad Construction Loop (CRITICAL: Make sure unscaledVAdjust is passed here!)
    _constructQuads(currentX, unscaledVAdjust);

    return FskBitmapTextQuadBuilderResult(quads, textureQuads);
  }

  /// Pass 1: Gathers character bounding information and computes unscaled text line length.
  void _gatherLayoutData() {
    _lineLength = 0;

    for (int i = 0; i < text.length; i++) {
      final charInfo = font.chars[text[i]];
      if (charInfo == null) continue;

      double kerning = 0.0;
      if ((i + 1) < text.length) {
        kerning = font.kerningForPair(
          text.codeUnitAt(i),
          text.codeUnitAt(i + 1),
        );
      }
      layoutData.add(CharLayoutInfo(char: charInfo, kerning: kerning));
      _lineLength += charInfo.xAdvance + kerning;
    }
  }

  /// Pass 2: Initializes backing collections and limits scale bounds to container constraints.
  void _allocateListsAndCalculateRatio() {
    int characterCount = layoutData.length;

    quads = List<Quad>.filled(characterCount, Quad());
    textureQuads = List<Rect>.filled(characterCount, Rect.zero);

    _ratio = (_lineLength > 0) ? _width / _lineLength : 1.0;
    _ratio = min(1.0, _ratio);
  }

  /// Pass 3: Computes the starting horizontal offset inside unscaled canvas bounds.
  double _calculateHorizontalJustification() {
    final double unscaledBoxWidth = _width / _ratio;

    switch (horizontalJustification) {
      case TextHorizontalJustification.left:
        return 0.0;
      case TextHorizontalJustification.center:
        return (unscaledBoxWidth - _lineLength) / 2;
      case TextHorizontalJustification.right:
        return unscaledBoxWidth - _lineLength;
    }
  }

  /// Pass 4: Computes the vertical layout anchor corrected for the box origin.
  double _calculateVerticalJustification() {
    final double boxHeight = screenRect.yVector.length;
    final double unscaledLineHeight = font.lineHeight.toDouble();
    final double unscaledBoxHeight = boxHeight / _ratio;

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
    double startX,
    final double unscaledVAdjust, // Caught from Pass 4 calculation block
  ) {
    double currentX = startX;
    final double unscaledLineHeight = font.lineHeight.toDouble();

    for (int i = 0; i < layoutData.length; i++) {
      final data = layoutData[i];
      final charInfo = data.char;
      final kerning = data.kerning;

      final left = currentX;
      final right = left + charInfo.region.width;

      final double lineTopCeiling = unscaledVAdjust + unscaledLineHeight;
      double qTop = lineTopCeiling - charInfo.yOffset;
      double qBottom = qTop - charInfo.region.height;

      final blc = Vector2(left * _ratio, qBottom * _ratio);
      final trc = Vector2(right * _ratio, qTop * _ratio);

      quads[i] = screenRect.calcQuadFrom2DVectors(blc, trc);

      final tLeft = charInfo.region.left / font.scaleW;
      final tTop = charInfo.region.top / font.scaleH;
      final tRight =
          (charInfo.region.left + charInfo.region.width) / font.scaleW;
      final tBottom =
          (charInfo.region.top + charInfo.region.height) / font.scaleH;

      textureQuads[i] = Rect.fromLTRB(tLeft, tTop, tRight, tBottom);

      currentX += charInfo.xAdvance + kerning;
    }
  }
}
