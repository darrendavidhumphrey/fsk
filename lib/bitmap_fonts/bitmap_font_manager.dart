import 'package:flutter/services.dart';

import '../fsk_singleton.dart';
import '../logging.dart';
import 'bitmap_font.dart';
part 'built_in_font.dart';

/// A manager for loading, creating, and accessing [BitmapFont] objects.
///
/// This class is intended to be held by a central singleton (e.g., FSK) and is
/// responsible for caching fonts and ensuring their textures are loaded before use.
class BitmapFontManager with LoggableClass {
  /// The internal cache of registered fonts, keyed by their unique name.
  final Map<String, BitmapFont> _fonts = {};

  /// The singleton instance.
  static final BitmapFontManager _singleton = BitmapFontManager._internal();

  static String assetsRoot = "assets/";

  /// Factory constructor to return the singleton instance.
  factory BitmapFontManager() {
    return _singleton;
  }

  /// Internal constructor for the singleton.
  BitmapFontManager._internal();

  // List of textures that are still loading
  // This future tracks the end of the current chain line
  Future<void> loadQueue = Future.value();

  /// Registers a pre-loaded [BitmapFont] instance with a given [name].
  void registerFont(String name, BitmapFont font) {
    logInfo("Registering font $name");
    _fonts[name] = font;
  }

  /// Clears all registered fonts from the manager.
  void clear() {
    _fonts.clear();
    logInfo("BitmapFontManager cleared.");
  }

  /// Retrieves a font by its registered [name].
  ///
  /// Returns `null` if a font with the given name has not been registered.
  BitmapFont? getFont(String name) {
    return _fonts[name];
  }

  /// Returns the default font, which is expected to be named "default".
  /// Lazily creates the font if it doesn't exist.
  BitmapFont? get defaultFont {
    final font = _fonts["default"];

    // Asynchronously Lazily instantiate the default font
    if (font == null) {
      createDefaultFont();
      return _fonts["default"];
    }
    return font;
  }

  Future<void> createFontFromFile(
    String fontName,
    String filename,
    String textureName,
  ) async {
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
      await createFont(fontName, xmlData, textureName);
    } catch (e, stackTrace) {
      logError("Error loading or parsing font XML '$fontPath': $e");
      logError("StackTrace: $stackTrace");
    }
  }

  /// Creates a font from XML data, loads its texture, and registers it.
  /// The XML data is processed synchronously, but the texture is loaded asynchronously.
  /// Thus it is possible for fonts to temporarily have no texture loaded
  Future<void> createFont(String fontName, String xmlString, String textureName) async {
    try {
      var font = BitmapFont.fromXml(fontName, xmlString);
      // The texture loads asynchronously, so wait for it.
      await font.loadFontTexture(textureName);
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
      var font = BitmapFont.fromXml(fontName, xmlString);

      // NOTE: The texture loads asynchronously
      font.loadFontTexture(textureName);
      registerFont(fontName, font);
    } catch (e, stackTrace) {
      logError("Error loading font '$fontName': $e");
      logError("StackTrace: $stackTrace");
    }
  }

  /// A convenience method to create and register the default font for the application.
  void createDefaultFont() {
    createFontSync("default", creatoDisplayBoldXml, "CreatoDisplay-Bold.png");
  }
}
