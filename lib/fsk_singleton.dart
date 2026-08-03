import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/shaders/materials.dart';
import 'package:fsk/gpu/fsk_texture_manager.dart';
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

  /// Factory constructor to return the singleton instance.
  factory FSK() {
    return _singleton;
  }

  // Cache of rendering pipelines -- NOW GLOBAL
  final PipelineCache _pipelineCache = PipelineCache();

  void activatePipeline( PipelineKey key,
      gpu.RenderPass renderPass,
      gpu.VertexLayout layout) {
    _pipelineCache.activate(key, renderPass, layout);
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
            await shaderLibrary.registerBuiltInShaderLibrary(path);
            logInfo('Successfully loaded shader bundle from: $path');
            loaded = true;
            break;
          } catch (_) {
            // Silently try next path
          }
        }
        
        if (!loaded) {
          logWarning('Failed to load shader bundle from prioritized paths. Searching AssetManifest...');
          
          final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
          final allAssets = manifest.listAssets();
          
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
        
        _state = FskState.initialized;
        return true;
      }
    } catch (e) {
      logError('Exception initializing GpuShader Pipeline: $e');
      logError('Make sure you are running with --enable-impeller.');
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
