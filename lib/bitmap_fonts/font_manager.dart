import 'package:flutter/services.dart';

import '../fsk_singleton.dart';
import '../logging.dart';
import 'texture_font.dart';
part 'built_in_font.dart';

/// A manager for loading, creating, and accessing [TextureFont] objects.
///
/// This class is intended to be held by a central singleton (e.g., FSK) and is
/// responsible for caching fonts and ensuring their textures are loaded before use.
class FontManager with LoggableClass {
  /// The internal cache of registered fonts, keyed by their unique name.
  final Map<String, TextureFont> _fonts = {};

  /// The singleton instance.
  static final FontManager _singleton = FontManager._internal();

  static String assetsRoot = "assets/";

  /// Factory constructor to return the singleton instance.
  factory FontManager() {
    return _singleton;
  }

  /// Internal constructor for the singleton.
  FontManager._internal();

  // List of textures that are still loading
  // This future tracks the end of the current chain line
  Future<void> loadQueue = Future.value();

  /// Registers a pre-loaded [TextureFont] instance with a given [name].
  void registerFont(String name, TextureFont font) {
    logInfo("Registering font $name");
    _fonts[name] = font;
  }

  /// Clears all registered fonts from the manager.
  void clear() {
    if (_fonts.isNotEmpty) {
      _fonts.clear();
      logInfo("FontManager cleared ==================================");
    }
  }

  /// Retrieves a font by its registered [name].
  ///
  /// Returns `null` if a font with the given name has not been registered.
  TextureFont? getFont(String name) {
    return _fonts[name];
  }

  /// Returns the default font, which is expected to be named "default".
  TextureFont? get defaultFont {
    return _fonts["default"];
  }

  /// Explicitly initializes the manager, ensuring the default font is loaded.
  Future<void> init() async {
    await createFont("default", creatoDisplayBoldXml, "CreatoDisplay-Bold.png", generateMipmaps: true);
  }

  Future<void> createFontFromFile(
    String fontName,
    String filename,
    String textureName, {
    bool generateMipmaps = true,
  }) async {
    if (_fonts.containsKey(fontName)) {
      logInfo("Font $fontName already registered, skipping load.");
      return;
    }

    // Load the XML data from the file as a string
    final fontPath = "$assetsRoot$filename";

    try {
      if (!FSK().assetManifest.listAssets().contains(fontPath)) {
        logError("Font file not found in asset manifest: '$fontPath'");
        return;
      }

      final xmlData = await rootBundle.loadString(fontPath);

      logVerbose("createFontFromFile: $fontName, $filename, $textureName");

      // Call the createFont method with the retrieved data
      await createFont(fontName, xmlData, textureName, generateMipmaps: generateMipmaps);
    } catch (e, stackTrace) {
      logError("Error loading or parsing font XML '$fontPath': $e");
      logError("StackTrace: $stackTrace");
    }
  }

  /// Creates a font from XML data, loads its texture, and registers it.
  /// The XML data is processed synchronously, but the texture is loaded asynchronously.
  /// Thus it is possible for fonts to temporarily have no texture loaded
  Future<void> createFont(String fontName, String xmlString, String textureName, {bool generateMipmaps = false}) async {
    try {
      var font = TextureFont.fromXml(fontName, xmlString);
      // The texture loads asynchronously, so wait for it.
      await font.loadFontTexture(textureName, generateMipmaps: generateMipmaps);
      registerFont(fontName, font);
    } catch (e, stackTrace) {
      logError("Error loading font '$fontName': $e");
      logError("StackTrace: $stackTrace");
    }
  }

  // Synchronous version that ensures the font is loaded before use, but the
  // texture still loads asynchronously.
  void createFontSync(String fontName, String xmlString, String textureName)  {
    try {
      var font = TextureFont.fromXml(fontName, xmlString);

      // NOTE: The texture loads asynchronously
      font.loadFontTexture(textureName);
      registerFont(fontName, font);
    } catch (e, stackTrace) {
      logError("Error loading font '$fontName': $e");
      logError("StackTrace: $stackTrace");
    }
  }
}
