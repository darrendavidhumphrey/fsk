import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsk/fsk.dart';
import 'package:fsk/shaders/simple_texture_shader.dart';
import 'package:vector_math/vector_math_64.dart';

/// A class that manages the lifecycle of all shader programs in the application.
class ShaderList with GlContextManager,LoggableClass {


  // --- Custom Shader Registration ---
  final Map<Type, GlslShader> _cachedShaders = {};
  final Map<Type, GlslShader Function()> _shaderFactories = {};

  /// Initializes all shader programs with the given rendering context.
  void init(RenderingContext gl) {
    initializeGl(gl);
    GlStateManager gls = FSK().glStateManager;
    // Register default shaders
    registerShader<OneLightShader>(()=> OneLightShader(gls));
    registerShader<BasicLightingShader>(()=> BasicLightingShader(gls));
    registerShader<CheckerBoardShader>(()=> CheckerBoardShader(gls));
    registerShader<GridShader>(()=> GridShader(gls));
    registerShader<BitmapTextShader>(()=> BitmapTextShader(gls));
    registerShader<FlatShader>(()=> FlatShader(gls));
    registerShader<SimpleTextureShader>(()=> SimpleTextureShader(gls));
  }

  /// Registers a custom shader by name for later retrieval.
  void registerShader<T extends GlslShader>(T Function() factory) {
    _shaderFactories[T] = factory;
  }

  /// Retrieves a previously registered shader strictly by its class type definition.
  T getShader<T extends GlslShader>() {
    // 1. Check if the type instance has already been lazily generated
    if (_cachedShaders.containsKey(T)) {
      return _cachedShaders[T] as T;
    }

    // 2. Fetch the concrete factory mapping
    final factory = _shaderFactories[T];
    if (factory == null) {
      var message = "Shader Type '$T' has not been registered.";
      logError(message);
      throw Exception(message);
    }

    // 3. Lazy execute, save cache entry, and return strongly-typed instance
    final shaderInstance = factory();
    _cachedShaders[T] = shaderInstance;
    return shaderInstance as T;
  }

  /// A utility to set the standard model-view and projection matrices on a shader.
  static void setMatrixUniforms(GlslShader shader,Matrix4 pMatrix, Matrix4 mvMatrix) {
    shader.gls.setUniformMatrix4fv(
      shader.uniforms[GlslShader.uProj]!,
      pMatrix,
    );
    shader.gls.setUniformMatrix4fv(
      shader.uniforms[GlslShader.uModelView]!,
      mvMatrix,
    );
  }
}
