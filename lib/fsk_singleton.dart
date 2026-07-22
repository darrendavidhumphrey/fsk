import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsk/shaders/shaders.dart';
import 'package:fsk/shaders/materials.dart';
import 'package:fsk/fsk_texture_manager.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'angle/gl_state_manager.dart';
import 'logging.dart';

import 'fsk_scene.dart';
// 1. Conditionally import: Defaults to stub, switches to web file on Web builds
import '../web/web_injector_stub.dart' if (dart.library.html) '../web/web_injector_web.dart';

/// Enum to manage the initialization state of the FSK singleton.
enum FskState {
  /// The engine has not been initialized at all.
  uninitialized,

  /// Initialization just started,but engine is not yet ready.
  inProgress,

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
class FSK with LoggableClass {
  /// The core FlutterAngle engine instance.
  FlutterAngle angle = FlutterAngle();

  /// The current initialization state of the engine.
  FskState _state = FskState.uninitialized;
  FskState get state => _state;

  /// The default size for textures that are rendered to.
  static double renderToTextureSize = 2048;

  // Default device pixel ratio for rendering to texture
  static double devicePixelRatio = 1.0;

  /// A map of all registered scenes and their corresponding output textures.
  final Map<FskScene, FlutterAngleTexture> scenes = {};

  /// The manager for all shader programs.
  late ShaderList shaders;

  /// A list of all textures created by the engine, for later disposal.
  final renderToTextureList = <FlutterAngleTexture>[];

  /// The manager for all rendering materials.
  final materials = MaterialList();

  /// The manager for textures loaded from assets.
  late FskTextureManager textureManager;

  /// OpenGL State manager to reduce unneeded OpenGL state changes
  final GlStateManager glStateManager = GlStateManager();

  /// The singleton instance.
  static final FSK _singleton = FSK._internal();

  /// Factory constructor to return the singleton instance.
  factory FSK() {
    return _singleton;
  }

  /// Internal constructor for the singleton.
  FSK._internal() {
    textureManager = FskTextureManager(glStateManager);
  }

  /// Initializes the core FlutterAngle engine.
  /// This must be called once before any other operations.
  Future<bool> init() async {
    if (_state != FskState.uninitialized) {

      // Fix web CSS so that render context follows flutter size requests
      if (kIsWeb) {
        injectWebCSS();
      }
      return false;
    }
    _state = FskState.inProgress;

    await angle.init();
    shaders = ShaderList();
    _state = FskState.glInitialized;
    return true;
  }

  /// Allocates a new FlutterAngleTexture with the given options.
  Future<FlutterAngleTexture?> allocTexture(
    AngleOptions options, {
    double textureSize = 4096,
  }) async {
    if (_state == FskState.uninitialized) {
      logWarning("allocTexture called before FSK is initialized.");
      return null;
    }
    var newTexture = await angle.createTexture(options);
    renderToTextureList.add(newTexture);
    return newTexture;
  }

  /// Initializes a [FskScene] with its rendering context.
  void initScene(FskScene scene) {
    if (!scene.isInitialized) {
      scene.init(scene.renderToTextureId!.getContext());
    }
  }

  /// Initializes platform-specific state, including the frame counter and the engine.
  Future<void> initPlatformState() async {
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
    if (_state == FskState.contextInitialized) {
      return;
    }

    // Default to true on Web
    FSK.isYFlipped = false;

    // If not web, set it on a case by case
    if (!kIsWeb) {
      // TODO: Set axis inversions for mac,linux, and ios
      if (Platform.isAndroid) {
        FSK.isYFlipped = false;
      } else if (Platform.isWindows) {
        FSK.isYFlipped = true;
      }
    }

    glStateManager.initializeGl(gl);
    textureManager.initializeGl(gl);
    initDefaultMaterial();
    shaders.init(gl);
    _state = FskState.contextInitialized;
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

    // TODO:  Dispose shaders
    //  shaders.dispose();
    await textureManager.dispose();

    // After disposing context-specific resources, we revert to the GL-initialized state.
    if (_state == FskState.contextInitialized) {
      _state = FskState.glInitialized;
    }
  }

  /// Registers a scene with the engine and allocates a texture for it to render to.
  /// This is the primary method for setting up a new renderable scene.
  Future<bool> registerSceneAndAllocateTexture(FskScene scene, {double? dpr}) async {
    bool useSurface = true;

    if (!kIsWeb) {
      if (Platform.isWindows) {
        useSurface = true;
      }
    }

    final options = AngleOptions(
      width: scene.textureWidth,
      height: scene.textureHeight,
      dpr: dpr ?? FSK.devicePixelRatio,
      antialias: true,
      useSurfaceProducer: useSurface,
    );

    // Allocate an OpenGL texture for the scene.
    var textureId = await allocTexture(options);

    bool success = (textureId != null);
    if (success) {
      scene.renderToTextureId = textureId;
      scenes[scene] = textureId;

      if (kIsWeb) {
        // Apply CSS to the canvas to ensure it fills the container and is visible.
        try {
          final dynamic canvas = textureId.surfaceId;
          canvas.style.width = '100%';
          canvas.style.height = '100%';
          canvas.style.display = 'block';
          canvas.style.position = 'absolute';
          canvas.style.top = '0px';
          canvas.style.left = '0px';
          canvas.style.zIndex = '-1'; // Place behind Flutter UI
          canvas.style.pointerEvents = 'none'; // Don't block Flutter gestures
        } catch (e) {
          logWarning("Failed to apply CSS to web canvas: $e");
        }
      }
    }
    return success;
  }

  void reuseTexture(FlutterAngleTexture textureId, FskScene scene) async {
    scene.renderToTextureId = textureId;
    scenes[scene] = textureId;
  }

  /// Resizes an existing texture.
  Future<void> resize(FlutterAngleTexture texture, AngleOptions options) async {
    if (_state == FskState.uninitialized) {
      return;
    }

    // The flutter_angle plugin currently does not support resizing textures on Android.
    // We skip the resize and metadata update to prevent viewport mismatches.
    if (!kIsWeb && Platform.isAndroid) {
      return;
    }

    await angle.resize(texture, options);

    // Ensure the texture object's metadata is updated to match the new size.
    // This is critical for scene viewport calculations on Windows and Web.
    texture.options = options;

    if (kIsWeb) {
      // IMPORTANT: Resizing a canvas on Web resets the WebGL state.
      // We must force the state manager to resync with the hardware,
      // but only if it has already been initialized.
      if (glStateManager.isInitialized) {
        glStateManager.hardReset();
        glStateManager.resetToDefaultState();
      }
    }
  }

  static void normalizeUpAxis(Matrix4 mat) {
    if (isYFlipped) {
      // If the viewer (Texture widget) flips the texture (e.g. Android/Web),
      // we must counteract it in the projection matrix to keep the scene right-side up.
      // Net effect: Projection flip (1) + Mapping flip (1) = 2 (Rotation).
      mat.scaleByVector3(Vector3(1.0, -1.0, 1.0));
    }
  }

  /// Whether the platform's viewer flips the Y-axis.
  /// This defaults to true and ensures a net even number of reflections (Right-handed rotation)
  /// on platforms that use the Texture widget.
  static bool isYFlipped = true;
}
