import 'dart:math';
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart' as vm;
import '../fsk.dart';

class FskTextureTextQuadBuilderResult {
  int numQuads = 0;
  final Float32List vertexData;

  FskTextureTextQuadBuilderResult(this.numQuads, this.vertexData);
  FskTextureTextQuadBuilderResult.empty(): numQuads = 0, vertexData = Float32List(0);
}

class CharLayoutInfo {
  final CharInfo char;
  final double kerning;
  CharLayoutInfo({required this.char, required this.kerning});
}

class FskTextureTextQuadBuilder {
  final String text;
  final TextureFont font;
  final ReferenceBox screenRect;
  final TextHorizontalJustification horizontalJustification;
  final TextVerticalJustification verticalJustification;
  final double _width;
  final bool scaleToFit;

  static final int _vertexStride = 5;

  // Computed Internally
  late double _ratio;
  late double _lineLength;
  late double _stringAscent;
  late double _stringDescent;

  final List<CharLayoutInfo> layoutData = [];
  int _numQuads;
  Float32List _vertexData;

  FskTextureTextQuadBuilder({
    required this.text,
    required this.font,
    required this.screenRect,
    required this._width,
    required this.horizontalJustification,
    required this.verticalJustification,
    this.scaleToFit = false,
  }) : _numQuads = 0, _vertexData = Float32List(0);

  FskTextureTextQuadBuilderResult build() {
    layoutData.clear();
    _numQuads = 0;
    _vertexData = Float32List(0);

    _lineLength = 0;
    _ratio = 0;
    _stringAscent = 0;
    _stringDescent = 0;

    if (text.isEmpty) {
      return FskTextureTextQuadBuilderResult.empty();
    }

    // Pass 1: Gather layout information and calculate total width/height bounds
    _gatherLayoutData();

    if (_lineLength == 0) {
      return FskTextureTextQuadBuilderResult.empty();
    }

    // Pass 2: Pre-allocate lists and generate scaled quads
    _allocateListsAndCalculateRatio();

    // Pass 3: Horizontal Justification
    final currentX = _calculateHorizontalJustification();

    // Pass 4: Vertical Justification
    final unscaledVAdjust = _calculateVerticalJustification();

    // Pass 5: Quad Construction Loop
    _constructQuads(currentX, unscaledVAdjust);

    return FskTextureTextQuadBuilderResult(_numQuads, _vertexData);
  }

  /// Pass 1: Gathers character bounding information and computes unscaled text line length.
  void _gatherLayoutData() {
    _lineLength = 0;
    _stringAscent = 0;
    _stringDescent = 0;

    final double base = font.baseline;

    for (int i = 0; i < text.length; i++) {
      final charInfo = font.chars[text[i]];
      if (charInfo == null) continue;

      // Track the visual bounds of the actual string
      final double charAscent = base - charInfo.yOffset;
      final double charDescent = (charInfo.yOffset + charInfo.region.height) - base;
      
      if (charAscent > _stringAscent) _stringAscent = charAscent;
      if (charDescent > _stringDescent) _stringDescent = charDescent;

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

    // Fallback for whitespace strings
    if (_stringAscent == 0) _stringAscent = font.baseline;
  }

  /// Pass 2: Initializes backing collections and limits scale bounds to container constraints.
  void _allocateListsAndCalculateRatio() {
    int characterCount = layoutData.length;

    _numQuads = characterCount;

    // Allocate 4 vertices per quad, each of which has _vertexStride components
    _vertexData = Float32List(_numQuads * _vertexStride * 4);

    final double fitWidthRatio = (_lineLength > 0) ? _width / _lineLength : 1.0;

    // Ensure the visual part of the text (ascent) fits vertically within the box height
    final double boxHeight = screenRect.yVector.length;
    final double fitHeightRatio = (_stringAscent > 0) ? boxHeight / _stringAscent : 1.0;

    // Use the most restrictive ratio to maintain aspect ratio
    _ratio = min(fitWidthRatio, fitHeightRatio);

    if (!scaleToFit) {
      _ratio = min(1.0, _ratio);
    }
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
    final double unscaledBoxHeight = boxHeight / _ratio;

    switch (verticalJustification) {
      case TextVerticalJustification.top:
        // Anchors the visual top of the string to the box top (unscaledBoxHeight)
        return unscaledBoxHeight - _stringAscent;

      case TextVerticalJustification.center:
        // Centers the visual ascent in the box
        return (unscaledBoxHeight - _stringAscent) / 2.0;

      case TextVerticalJustification.bottom:
        // Anchors the baseline to the box bottom (0)
        // Descenders will drop below the reference box
        return 0.0;
    }
  }

  int  _addQuad(int index, vm.Vector2 blc, vm.Vector2 trc, double tLeft, double tTop, double tRight, double tBottom) {
    vm.Quad q = screenRect.calcQuadFrom2DVectors(blc, trc);
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
    final double unscaledVAdjust,
  ) {
    double currentX = startX;
    final double unscaledBase = font.baseline;

    int vDataIndex = 0;
    for (int i = 0; i < layoutData.length; i++) {
      final data = layoutData[i];
      final charInfo = data.char;
      final kerning = data.kerning;

      final left = currentX;
      final right = left + charInfo.region.width;

      // Position relative to the baseline (Y-up math)
      final double charTop = unscaledVAdjust + unscaledBase - charInfo.yOffset;
      final double charBottom = charTop - charInfo.region.height;

      final blc = vm.Vector2(left * _ratio, charBottom * _ratio );
      final trc = vm.Vector2(right * _ratio, charTop * _ratio);
      
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
