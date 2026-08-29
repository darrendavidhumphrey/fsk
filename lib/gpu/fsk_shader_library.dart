import 'package:flutter_gpu/gpu.dart' as gpu;
import '../logging.dart';

class FskShaderLibrary with LoggableClass {
  // Store all of your loaded individual shader libraries
  final List<gpu.ShaderLibrary> _libraries = [];
  final Set<String> _registeredPaths = {};

  /// Register and initialize an isolated shader bundle file
  Future<void> registerBundle(String assetPath) async {
    if (_registeredPaths.contains(assetPath)) return;
    try {
      // Uses the .then() callback chain to wait for the Future asset to load
      await gpu.ShaderLibrary.fromAsset(assetPath).then((library) {
        _registerShaderLibrary(library, assetPath);
      }).catchError((error) {
        logError(
            'Failed to asynchronously load shader bundle $assetPath: $error');
      });
    }
    catch (e) {
      logError('Failed to load shader bundle $assetPath: $e');
    }
  }

  void _registerShaderLibrary(gpu.ShaderLibrary? library,String assetPath) {
    if (library != null) {
      _libraries.add(library);
      _registeredPaths.add(assetPath);
      logVerbose('Successfully added shader bundle to registry: $assetPath');
    } else {
      logWarning('Warning: Shader library resolved to null for path: $assetPath');
    }
  }

  Future<void> registerBuiltInShaderLibrary(String assetPath) async {
    if (_registeredPaths.contains(assetPath)) return;
    var library = await gpu.ShaderLibrary.fromAsset(assetPath);
    _registerShaderLibrary(library,assetPath);
  }

  /// Searches all registered libraries sequentially for the shader name
  gpu.Shader? findShader(String shaderName) {
    for (final library in _libraries) {
      final shader = library[shaderName]; 
      if (shader != null) {
        return shader;
      }
    }
    // logInfo("FskShaderLibrary: '$shaderName' not found. Registered libraries: ${_libraries.length}");
    return null; 
  }

  /// Optional: Operator overloading to match native syntax registry['Name']
  gpu.Shader? operator [](String shaderName) => findShader(shaderName);
}