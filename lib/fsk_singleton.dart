import 'package:flutter/material.dart';
import 'package:fsk/shaders/materials.dart';
import 'package:fsk/fsk_texture_manager.dart';
import 'fsk_shader_library.dart';
import 'logging.dart';

/// Enum to manage the initialization state of the FSK singleton.
enum FskState {
  /// The engine has not been initialized at all.
  uninitialized,

  /// Ready to go (only two stages now)
  initialized,
}

/// The main singleton for the rendering engine.
///
/// This class is responsible for managing global state, including the FlutterAngle
/// engine instance, scenes, and shared resources like shaders, materials, and
/// textures.
class FSK with LoggableClass {
  /// The current initialization state of the engine.
  FskState _state = FskState.uninitialized;
  FskState get state => _state;

  /// The default size for textures that are rendered to.
  static double renderToTextureSize = 2048;

  // Default device pixel ratio for rendering to texture
  static double devicePixelRatio = 1.0;

  /// The manager for all rendering materials.
  final materials = MaterialList();

  /// The manager for textures loaded from assets.
  late FskTextureManager textureManager;

  /// The singleton instance.
  static final FSK _singleton = FSK._internal();

  static final String _builtInShaderBundlePath =
      'packages/fsk/build/shaderbundles/fsk.shaderbundle';

  late final FskShaderLibrary shaderLibrary;

  /// Factory constructor to return the singleton instance.
  factory FSK() {
    return _singleton;
  }

  /// Internal constructor for the singleton.
  FSK._internal() {
    textureManager = FskTextureManager();
    initDefaultMaterial();
  }

  /// This must be called once before any other operations.
  Future<bool> init() async {
    try {
      if (_state == FskState.uninitialized) {

        shaderLibrary = FskShaderLibrary();
        await shaderLibrary.registerBundle(_builtInShaderBundlePath);

        _state = FskState.initialized;
        return true;
      }
    } catch (e) {
      debugPrint('Exception initializing GpuShader Pipeline: $e');
      return false;
    }

    return true;
  }


  /// Initializes the default material used for rendering.
  void initDefaultMaterial() {
    Color defaultGrey = Colors.grey[200]!;
    Color defaultSpecular = Colors.black;
    const double defaultShininess = 5;

    materials.setDefaultMaterial(
      GlMaterial(defaultGrey, defaultGrey, defaultSpecular, defaultShininess),
    );
  }

}
