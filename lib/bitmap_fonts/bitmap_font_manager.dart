import 'package:flutter/services.dart';

import '../logging.dart';
import 'bitmap_font.dart';
part 'built_in_font.dart';


/// A manager for loading, creating, and accessing [BitmapFont] objects.
///
/// This class is intended to be held by a central singleton (e.g., FSG) and is
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
    }
    return font;
  }

Future<void> createFontFromFile(String fontName, String filename, String textureName) async {
  // Load the XML data from the file as a string
  final xmlData = await rootBundle.loadString("$assetsRoot$filename");

  logVerbose("createFontFromFile: $fontName, $filename, $textureName");
  // Call the createFont method with the retrieved data
  createFont(fontName, xmlData, textureName);
}

  /// Creates a font from XML data, loads its texture, and registers it.
  /// The XML data is processed synchronously, but the texture is loaded asynchronously.
  /// Thus it is possible for fonts to temporarily have no texture loaded
  void createFont(
      String fontName, String xmlString, String textureName) {

    var font = BitmapFont.fromXml(fontName, xmlString);

    // NOTE: The texture loads asynchronously
    font.loadTexture(textureName);
    registerFont(fontName, font);
  }

  /// A convenience method to create and register the default font for the application.
  void createDefaultFont() {
    createFont("default", creatoDisplayBoldXml, "CreatoDisplay-Bold.png");
  }
}
