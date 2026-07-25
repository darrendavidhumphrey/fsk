import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';

class FskShaderLibrary with LoggableClass {
  // Store all of your loaded individual shader libraries
  final List<gpu.ShaderLibrary> _libraries = [];

  /// Register and initialize an isolated shader bundle file
  Future<void> registerBundle(String assetPath) async {
    // Uses the .then() callback chain to wait for the Future asset to load
    await gpu.ShaderLibrary.fromAsset(assetPath).then((library) {
      if (library != null) {
        _libraries.add(library);
        logVerbose('Successfully added shader bundle to registry: $assetPath');
      } else {
        logWarning('Warning: Shader library resolved to null for path: $assetPath');
      }
    }).catchError((error) {
      logError('Failed to asynchronously load shader bundle $assetPath: $error');
    });

  }

  /// Searches all registered libraries sequentially for the shader name
  gpu.Shader? findShader(String shaderName) {
    for (final library in _libraries) {
      final shader = library[shaderName]; // Queries library index operator
      if (shader != null) {
        return shader; // Return immediately once found
      } else {
        logWarning('Shader not found in library: $shaderName');
      }
    }
    return null; // Not found in any registered asset bundle
  }

  /// Optional: Operator overloading to match native syntax registry['Name']
  gpu.Shader? operator [](String shaderName) => findShader(shaderName);
}