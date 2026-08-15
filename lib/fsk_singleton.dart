import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/shaders/materials.dart';
import 'package:fsk/gpu/fsk_texture_manager.dart';
import 'bitmap_fonts/bitmap_font_manager.dart';
import 'gpu/fsk_shader_library.dart';
import 'gpu/gpu_pipeline_key.dart';
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
class FSK extends ChangeNotifier with LoggableClass {
  /// The current initialization state of the engine.
  FskState _state = FskState.uninitialized;
  FskState get state => _state;

  /// Tracks the number of asynchronous asset loading tasks currently in progress.
  int _pendingLoadCount = 0;
  int get pendingLoadCount => _pendingLoadCount;
  bool get isBusy => _pendingLoadCount > 0;

  /// Increments the pending load counter.
  void startLoad() {
    _pendingLoadCount++;
  }

  /// Decrements the pending load counter.
  void endLoad() {
    _pendingLoadCount--;
    if (_pendingLoadCount == 0) {
      notifyListeners();
    }
  }

  // Default device pixel ratio for rendering to texture
  static double devicePixelRatio = 1.0;

  /// The manager for all rendering materials.
  final materials = MaterialList();

  /// The manager for textures loaded from assets.
  late FskTextureManager textureManager;

  /// The singleton instance.
  static final FSK _singleton = FSK._internal();

  final FskShaderLibrary shaderLibrary = FskShaderLibrary();


  // Lazily cache the asset manifest the first time it's loaded to speed things up
  AssetManifest? _assetManifest;
  AssetManifest get assetManifest => _assetManifest!;

  /// Factory constructor to return the singleton instance.
  factory FSK() {
    return _singleton;
  }

  // Cache of rendering pipelines -- NOW GLOBAL
  final PipelineCache _pipelineCache = PipelineCache();

  void clearCaches() {
    Logging.logInfo('FSK.clearCaches: starting', source: 'FSK');
    _state = FskState.uninitialized; // Force re-init to rebuild built-in textures
    _pipelineCache.clear();
    textureManager.clear();
    BitmapFontManager().clear();
    materials.materials.clear();
    initDefaultMaterial();
    Logging.logInfo('FSK.clearCaches: finished', source: 'FSK');
  }

  void activatePipeline(
    PipelineKey key,
    gpu.RenderPass renderPass,
    gpu.VertexLayout layout,
  ) {
    // logInfo("FSK: activatePipeline: ${key.uniqueStringKey}");
    _pipelineCache.activate(key, renderPass, layout);
  }
  /// Internal constructor for the singleton.
  FSK._internal() {
    Logging.logInfo('FSK Singleton Created: $hashCode', source: 'FSK');
    textureManager = FskTextureManager();
    initDefaultMaterial();
  }

  /// This must be called once before any other operations.
  Future<bool> init() async {
    if (_state == FskState.initialized) return true;
    _state = FskState.initialized;

    logVerbose('FSK.init() called. Current state: $_state');
    try {

      _assetManifest ??= await AssetManifest.loadFromAssetBundle(rootBundle);
      await textureManager.init();
      await BitmapFontManager().init();

      // We try common paths for the compiled shader bundle in order of probability.
      final List<String> possiblePaths = [
        'packages/fsk/shaders/fsk.shaderbundle',
        'packages/fsk/flutter_gpu_shaders/shaderbundles/fsk.shaderbundle',
        'shaders/fsk.shaderbundle',
        'fsk.shaderbundle',
      ];

      bool loaded = false;
      for (final path in possiblePaths) {
        try {
          logVerbose('Trying to load shader bundle: $path');
          await shaderLibrary.registerBuiltInShaderLibrary(path);
          logInfo('Shader bundle load successful: $path');
          loaded = true;
          break;
        } catch (e) {
          logVerbose('Shader bundle load failed for $path: $e');
        }
      }
      if (!loaded) {
        logWarning('Failed to load shader bundle from prioritized paths. Searching AssetManifest...');

        final allAssets = assetManifest.listAssets();
        
        // Ultra-flexible search: Find any asset that contains "shaderbundle" and is not a JSON file.
        final match = allAssets.firstWhere(
          (a) => a.contains('shaderbundle') && !a.endsWith('.json'), 
          orElse: () => ''
        );
        
        if (match.isNotEmpty) {
          logInfo('Found alternative shader bundle path via fuzzy match: $match');
          await shaderLibrary.registerBuiltInShaderLibrary(match);
        } else {
          logError('CRITICAL: No binary shader bundle found in AssetManifest.');
          logError('Total assets bundled: ${allAssets.length}');
          
          // Log the ENTIRE manifest in chunks to avoid terminal truncation
          for (int i = 0; i < allAssets.length; i += 20) {
            final chunk = allAssets.skip(i).take(20).join(", ");
            logError('Manifest Chunk ${i~/20}: $chunk');
          }
          
          throw Exception('Shader bundle not found in assets. Ensure you are running with --enable-impeller and --enable-flutter-gpu.');
        }
      }
      logVerbose('FSK.init() success');
      return true;
    } catch (e) {
      _state = FskState.uninitialized; // Reset on failure
      logError('Exception initializing GpuShader Pipeline: $e');
      logError('Make sure you are running with --enable-impeller.');
      return false;
    }
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
