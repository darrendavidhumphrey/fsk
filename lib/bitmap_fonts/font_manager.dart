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

  /// Tracks active loading tasks to prevent redundant parallel requests.
  final Map<String, Future<TextureFont?>> _inProgressLoads = {};

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

  void removeFont(String name) {
    _fonts.remove(name);
  }

  /// Returns the default font, which is expected to be named "default".
  TextureFont? get defaultFont {
    return _fonts["default"];
  }

  /// Explicitly initializes the manager, ensuring the default font is loaded.
  Future<void> init() async {
    await createFont("default", creatoDisplayBoldXml, "CreatoDisplay-Bold.png", generateMipmaps: false);
  }

  Future<void> createFontFromFile(
    String fontName,
    String filename,
    String textureName, {
    bool generateMipmaps = false,
  }) async {
    // 1. Check if the font is already fully initialized and registered.
    if (_fonts.containsKey(fontName)) {
      final existingFont = _fonts[fontName]!;
      if (existingFont.isInitialized) {
        logVerbose("Font $fontName already registered and initialized, skipping load.");
        return;
      }
    }

    // 2. Check if a load for this font is already in progress.
    if (_inProgressLoads.containsKey(fontName)) {
      logVerbose("Font $fontName load is already in progress, awaiting existing task...");
      await _inProgressLoads[fontName];
      return;
    }

    // 3. Start a new atomic loading task.
    final loadTask = _runCreateFontFromFile(fontName, filename, textureName, generateMipmaps);
    _inProgressLoads[fontName] = loadTask;

    try {
      await loadTask;
    } finally {
      _inProgressLoads.remove(fontName);
    }
  }

  Future<TextureFont?> _runCreateFontFromFile(
    String fontName,
    String filename,
    String textureName,
    bool generateMipmaps,
  ) async {
    final fontPath = "$assetsRoot$filename";

    try {
      if (!FSK().assetManifest.listAssets().contains(fontPath)) {
        logError("Font file not found in asset manifest: '$fontPath'");
        return null;
      }

      final xmlData = await rootBundle.loadString(fontPath);
      logVerbose("createFontFromFile starting: $fontName, $filename, $textureName");

      return await createFont(fontName, xmlData, textureName, generateMipmaps: generateMipmaps);
    } catch (e, stackTrace) {
      logError("Error loading or parsing font XML '$fontPath': $e");
      logError("StackTrace: $stackTrace");
      return null;
    }
  }

  /// Creates a font from XML data, loads its texture, and registers it.
  Future<TextureFont?> createFont(String fontName, String xmlString, String textureName, {bool generateMipmaps = false}) async {
    try {
      var font = TextureFont.fromXml(fontName, xmlString);
      // The texture loads asynchronously, so wait for it.
      await font.loadFontTexture(textureName, generateMipmaps: generateMipmaps);
      
      // Settle Frame: ensure any pending GPU overwrite commands (like the clear) 
      // from the texture manager are fully submitted before the font is registered.
      // 100ms provides a massive buffer to ensure GPU tasks settle completely.
      await Future.delayed(const Duration(milliseconds: 100));

      // Enforce atomic "validated" registration: check wrapper AND hardware handle.
      if (font.isInitialized && font.textureInfo?.texture != null) {
        registerFont(fontName, font);
        return font;
      } else {
        logError("Font '$fontName' failed to initialize after texture load (handle is NULL).");
        return null;
      }
    } catch (e, stackTrace) {
      logError("Error creating font '$fontName': $e");
      logError("StackTrace: $stackTrace");
      return null;
    }
  }
}
