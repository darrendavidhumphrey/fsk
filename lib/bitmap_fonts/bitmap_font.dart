import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:xml/xml.dart';
import '../fsk_singleton.dart';
import '../logging.dart';
import '../texture_manager.dart';

/// A data class that holds rendering information for a single character
/// in a [BitmapFont].
class CharInfo {
  /// A flag indicating if the character exists in the font.
  final bool isCharAvailable;

  /// The rectangular region of the character within the font's texture atlas.
  final Rect region;

  /// The horizontal offset to apply to the character when rendering.
  final double xOffset;

  /// The vertical offset to apply to the character from the baseline.
  final double yOffset;

  /// The horizontal distance to advance the cursor after rendering this character.
  final double xAdvance;

  CharInfo(
    this.isCharAvailable,
    this.region,
    this.xOffset,
    this.yOffset,
    this.xAdvance,
  );

  @override
  String toString() {
    return 'CharInfo{isCharAvailable: $isCharAvailable, region: $region, xOffset: $xOffset, yOffset: $yOffset, xAdvance: $xAdvance}';
  }
}

/// Represents a bitmap font, loaded from an XML `.fnt` file.
///
/// This class holds the font's metrics, character information, kerning pairs,
/// and the associated WebGL texture.
class BitmapFont with LoggableClass {
  /// The name of the font.
  final String name;

  /// The height of a line of text in this font.
  final double lineHeight;

  /// The distance from the top of a line to the baseline of the characters.
  final double baseline;

  /// The width of the texture atlas.
  final double scaleW;

  /// The height of the texture atlas.
  final double scaleH;

  /// A map of character strings to their corresponding [CharInfo] data.
  final Map<String, CharInfo> chars;

  /// A nested map for efficient kerning lookups.
  /// The outer key is the first character's code unit, the inner key is the
  /// second character's code unit, and the value is the kerning amount.
  final Map<int, Map<int, double>> kerningPairs;

  /// The WebGL texture containing the rendered font characters (the texture atlas).
  /// This is null until [loadTexture] is called and completes.
  TextureInfo? textureInfo;

  /// Returns true if the font's texture has been loaded and is ready for use.
  bool get isInitialized => (textureInfo != null) && (textureInfo!.isBound);

  /// Creates a new BitmapFont.
  BitmapFont(
    this.name,
    this.lineHeight,
    this.baseline,
    this.scaleW,
    this.scaleH,
    this.chars,
    this.kerningPairs,
  );

  Future<void> loadTexture(String textureName) async {
    try {
      // Execute the asynchronous asset creation
      textureInfo = await FSK().textureManager.createTextureFromAsset(
        name,
        textureName,
        magFilter: WebGL.NEAREST,
        minFilter: WebGL.NEAREST,
        wrapS: WebGL.CLAMP_TO_EDGE,
        wrapT: WebGL.CLAMP_TO_EDGE,
      );
      logVerbose("Loaded font texture: $textureName");
    } catch (e) {
      logError("Failed loading $textureName: $e");
      rethrow; // Rethrow to let the caller handle individual file failures
    }
  }

  /// Factory constructor to load and parse a BitmapFont from an XML string.
  factory BitmapFont.fromXml(String name, String xmlString) {
    final document = XmlDocument.parse(xmlString);

    final commonElement = document.findAllElements('common').first;
    final lineHeight = int.parse(commonElement.getAttribute('lineHeight')!);
    final base = int.parse(commonElement.getAttribute('base')!);
    final scaleW = int.parse(commonElement.getAttribute('scaleW')!);
    final scaleH = int.parse(commonElement.getAttribute('scaleH')!);

    final chars = <String, CharInfo>{};
    final charElements = document.findAllElements('char');
    for (final charElement in charElements) {
      final id = int.parse(charElement.getAttribute('id')!);
      final x = int.parse(charElement.getAttribute('x')!);
      final y = int.parse(charElement.getAttribute('y')!);
      final width = int.parse(charElement.getAttribute('width')!);
      final height = int.parse(charElement.getAttribute('height')!);
      final xOffset = int.parse(charElement.getAttribute('xoffset')!);
      final yOffset = int.parse(charElement.getAttribute('yoffset')!);
      final xAdvance = int.parse(charElement.getAttribute('xadvance')!);

      chars.putIfAbsent(
        String.fromCharCode(id),
        () => CharInfo(
          true,
          Rect.fromLTWH(
            x.toDouble(),
            y.toDouble(),
            width.toDouble(),
            height.toDouble(),
          ),
          xOffset.toDouble(),
          yOffset.toDouble(),
          xAdvance.toDouble(),
        ),
      );
    }

    final kerningPairs = <int, Map<int, double>>{};
    final kerningElements = document.findAllElements('kerning');
    for (final kerningElement in kerningElements) {
      final first = int.parse(kerningElement.getAttribute('first')!);
      final second = int.parse(kerningElement.getAttribute('second')!);
      final amount = int.parse(kerningElement.getAttribute('amount')!);

      final innerMap = kerningPairs.putIfAbsent(first, () => {});
      innerMap[second] = amount.toDouble();
    }

    return BitmapFont(
      name,
      lineHeight.toDouble(),
      base.toDouble(),
      scaleW.toDouble(),
      scaleH.toDouble(),
      chars,
      kerningPairs,
    );
  }

  /// Returns the kerning amount between two character codes.
  /// Returns 0.0 if no specific kerning is defined for the pair.
  double kerningForPair(int first, int second) {
    return kerningPairs[first]?[second] ?? 0.0;
  }

  /// Calculates the total width of a string if rendered with this font.
  double widthOfString(String str) {
    double lineLength = 0.0;

    for (int i = 0; i < str.length; i++) {
      final CharInfo? charInfo = chars[str[i]];

      double kerning = 0.0;

      if (charInfo != null) {
        if ((i + 1) < str.length) {
          kerning = kerningForPair(str.codeUnitAt(i), str.codeUnitAt(i + 1));
        }
        lineLength += charInfo.xAdvance + kerning;
      }
    }
    return lineLength;
  }

  /// Calculates the size of the bounding box for a single line of text.
  Size sizeOfString(String str) {
    return Size(widthOfString(str), lineHeight);
  }
}
