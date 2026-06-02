import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/shaders/shaders.dart';
import 'package:fsg/shaders/materials.dart';
import 'package:fsg/texture_manager.dart';
import 'frame_counter.dart';
import 'logging.dart';
import 'bitmap_fonts/bitmap_font_manager.dart';
import 'scene.dart';

/// Enum to manage the initialization state of the FSG singleton.
enum _FsgState {
  /// The engine has not been initialized at all.
  uninitialized,

  /// The core FlutterAngle engine is ready, but no GL context has been created.
  glInitialized,

  /// A GL context has been created and context-specific resources are initialized.
  contextInitialized,
}

/// The main singleton for the rendering engine.
///
/// This class is responsible for managing global state, including the FlutterAngle
/// engine instance, scenes, and shared resources like shaders, materials, and
/// textures.
class FSG with LoggableClass {
  /// The core FlutterAngle engine instance.
  FlutterAngle angle = FlutterAngle();

  /// The current initialization state of the engine.
  _FsgState _state = _FsgState.uninitialized;

  /// The default size for textures that are rendered to.
  static double renderToTextureSize = 4096;

  /// A map of all registered scenes and their corresponding output textures.
  final Map<Scene, FlutterAngleTexture> scenes = {};

  /// The manager for all shader programs.
  final shaders = ShaderList();

  /// A list of all textures created by the engine, for later disposal.
  final renderToTextureList = <FlutterAngleTexture>[];

  /// The manager for all rendering materials.
  final materials = MaterialList();

  /// The manager for bitmap fonts.
  final fontManager = BitmapFontManager();

  /// The manager for textures loaded from assets.
  final textureManager = TextureManager();

  /// The singleton instance.
  static final FSG _singleton = FSG._internal();

  /// A model for tracking and displaying the frame rate.
  late FrameCounterModel frameCounter;

  /// Factory constructor to return the singleton instance.
  factory FSG() {
    return _singleton;
  }

  /// Internal constructor for the singleton.
  FSG._internal();

  /// Initializes the core FlutterAngle engine.
  /// This must be called once before any other operations.
  Future<bool> init() async {
    if (_state != _FsgState.uninitialized) {
      return false;
    }
    await angle.init();
    _state = _FsgState.glInitialized;
    return true;
  }

  /// Allocates a new FlutterAngleTexture with the given options.
  Future<FlutterAngleTexture?> allocTexture(
    AngleOptions options, {
    double textureSize = 4096,
  }) async {
    if (_state == _FsgState.uninitialized) {
      logWarning("allocTexture called before FSG is initialized.");
      return null;
    }
    var newTexture = await angle.createTexture(options);
    renderToTextureList.add(newTexture);
    return newTexture;
  }

  /// Initializes a [Scene] with its rendering context.
  void initScene(Scene scene) {
    if (!scene.isInitialized) {
      scene.init(scene.renderToTextureId!.getContext());
    }
  }

  /// Initializes platform-specific state, including the frame counter and the engine.
  Future<void> initPlatformState() async {
    frameCounter = FrameCounterModel();
    await init();
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

  /// Initializes shared context-specific resources like shaders and textures.
  /// This is called once a GL context becomes available.
  void initContext(RenderingContext gl) {
    if (_state == _FsgState.contextInitialized) {
      return;
    }
    textureManager.initializeGl(gl);
    initDefaultMaterial();

    shaders.init(gl);
    fontManager.createDefaultFont();
    _state = _FsgState.contextInitialized;
  }

  /// Disposes all scenes, textures, shaders, and other GPU resources.
  /// This is critical for preventing memory leaks on hot reload.
  Future<void> dispose() async {
    for (var scene in scenes.keys) {
      scene.dispose();
    }

    // TODO: Dispose textures
    // To prevent memory leaks, all textures in `renderToTextureList` must be
    // disposed of. The correct method is `angle.disposeTexture(texture)`,
    // as the `angle` instance is responsible for managing the lifecycle of the
    // textures it creates.
    // Example:
    // for (var texture in renderToTextureList) {
    //   angle.disposeTexture(texture);
    // }

    scenes.clear();
    renderToTextureList.clear();

    shaders.dispose();
    await textureManager.dispose();

    // After disposing context-specific resources, we revert to the GL-initialized state.
    if (_state == _FsgState.contextInitialized) {
      _state = _FsgState.glInitialized;
    }
  }

  /// Registers a scene with the engine and allocates a texture for it to render to.
  /// This is the primary method for setting up a new renderable scene.
  Future<bool> registerSceneAndAllocateTexture(Scene scene) async {
    final options = AngleOptions(
      width: scene.textureWidth,
      height: scene.textureHeight,
      dpr: 1,
      antialias: true,
      useSurfaceProducer: true,
    );

    // Allocate an OpenGL texture for the scene.
    var textureId = await allocTexture(options);

    bool success = (textureId != null);
    if (success) {
      scene.renderToTextureId = textureId;
      scenes[scene] = textureId;
    }
    return success;
  }

  void reuseTexture(FlutterAngleTexture textureId, Scene scene) async {
    scene.renderToTextureId = textureId;
    scenes[scene] = textureId;
  }
}
