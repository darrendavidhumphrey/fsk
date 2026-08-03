import 'dart:math';
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart' hide Colors;
import '../fsk.dart';

class FskBitmapTextQuadBuilderResult {
  int numQuads = 0;
  final Float32List vertexData;

  FskBitmapTextQuadBuilderResult(this.numQuads, this.vertexData);
  FskBitmapTextQuadBuilderResult.empty(): numQuads = 0, vertexData = Float32List(0);
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

  static final int _vertexStride = 5;

  // Computed Internally
  late double _ratio;
  late double _lineLength;

  final List<CharLayoutInfo> layoutData = [];
  int _numQuads;
  Float32List _vertexData;

  FskBitmapTextQuadBuilder({
    required this.text,
    required this.font,
    required this.screenRect,
    required this._width,
    required this.horizontalJustification,
    required this.verticalJustification,
  }) : _numQuads = 0, _vertexData = Float32List(0);

  FskBitmapTextQuadBuilderResult build() {
    layoutData.clear();
    _numQuads = 0;
    _vertexData = Float32List(0);

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

    return FskBitmapTextQuadBuilderResult(_numQuads, _vertexData);
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

    _numQuads = characterCount;

    // Allocate 4 vertices per quad, each of which has _vertexStride components
    _vertexData = Float32List(_numQuads * _vertexStride*4);

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
    final double unscaledBase = font.baseline.toDouble();

    switch (verticalJustification) {
      case TextVerticalJustification.bottom:
        return unscaledBoxHeight - unscaledBase;

      case TextVerticalJustification.center:
        return (unscaledBoxHeight / 2.0) - unscaledBase + (unscaledLineHeight / 2.0);

      case TextVerticalJustification.top:
        return unscaledLineHeight - unscaledBase;
    }
  }

  int  _addQuad(int index, Vector2 blc,Vector2 trc,double tLeft,double tTop,double tRight,double tBottom) {
    Quad q = screenRect.calcQuadFrom2DVectors(blc, trc);
    _vertexData[index++] = q.point0.x;
    _vertexData[index++] = q.point0.y;
    _vertexData[index++] = q.point0.z;
    _vertexData[index++] = tLeft;
    _vertexData[index++] = tBottom;

    _vertexData[index++] = q.point1.x;
    _vertexData[index++] = q.point1.y;
    _vertexData[index++] = q.point1.z;
    _vertexData[index++] = tRight;
    _vertexData[index++] = tBottom;

    _vertexData[index++] = q.point2.x;
    _vertexData[index++] = q.point2.y;
    _vertexData[index++] = q.point2.z;
    _vertexData[index++] = tRight;
    _vertexData[index++] = tTop;

    _vertexData[index++] = q.point3.x;
    _vertexData[index++] = q.point3.y;
    _vertexData[index++] = q.point3.z;
    _vertexData[index++] = tLeft;
    _vertexData[index++] = tTop;

    return index;
  }

  /// Pass 5: Builds spatial transformation matrices and coordinates texture mapping vectors.
  void _constructQuads(
    double startX,
    final double unscaledVAdjust, // This is now the unscaled BASELINE position
  ) {
    double currentX = startX;
    final double unscaledBase = font.baseline.toDouble();

    int vDataIndex = 0;
    for (int i = 0; i < layoutData.length; i++) {
      final data = layoutData[i];
      final charInfo = data.char;
      final kerning = data.kerning;

      final left = currentX;
      final right = left + charInfo.region.width;

      // Position relative to the baseline
      final double charTop = unscaledVAdjust + unscaledBase - charInfo.yOffset;
      final double charBottom = charTop - charInfo.region.height;

      final blc = Vector2(left * _ratio, charBottom * _ratio );
      final trc = Vector2(right * _ratio, charTop * _ratio);
      final tLeft = charInfo.region.left / font.scaleW;
      final tTop = charInfo.region.top / font.scaleH;
      final tRight =
          (charInfo.region.left + charInfo.region.width) / font.scaleW;
      final tBottom =
          (charInfo.region.top + charInfo.region.height) / font.scaleH;

      vDataIndex = _addQuad(vDataIndex, blc, trc, tLeft, tTop, tRight, tBottom);
      currentX += charInfo.xAdvance + kerning;
    }
  }
}
