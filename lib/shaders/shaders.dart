import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/fsg.dart';
import 'package:vector_math/vector_math_64.dart';

/// A class that manages the lifecycle of all shader programs in the application.
class ShaderList with GlContextManager,LoggableClass {
  // --- Shared Attribute Names ---
  static const String v3Attrib = "aVertexPosition";
  static const String c4Attrib = "aVertexColor";
  static const String t2Attrib = "aTextureCoord";
  static const String n3Attrib = "aVertexNormal";

  // --- Shared Uniform Names ---
  static const String uModelView = "uMVMatrix";
  static const String uProj = "uPMatrix";
  static const String uNormal = "uNMatrix";
  static const String textureSamplerAttrib = 'uSampler';

  // --- Custom Shader Registration ---
  final Map<Type, GlslShader> _cachedShaders = {};
  final Map<Type, GlslShader Function()> _shaderFactories = {};

  /// Initializes all shader programs with the given rendering context.
  void init(RenderingContext gl) {
    initializeGl(gl);
    // Register default shaders
    registerShader<OneLightShader>(()=> OneLightShader(gl));
    registerShader<BasicLightingShader>(()=> BasicLightingShader(gl));
    registerShader<CheckerBoardShader>(()=> CheckerBoardShader(gl));
    registerShader<GridShader>(()=> GridShader(gl));
    registerShader<BitmapTextShader>(()=> BitmapTextShader(gl));
    registerShader<FlatShader>(()=> FlatShader(gl));
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
    shader.gl.uniformMatrix4fv(
      shader.uniforms[ShaderList.uProj]!,
      false,
      pMatrix.storage,
    );
    shader.gl.uniformMatrix4fv(
      shader.uniforms[ShaderList.uModelView]!,
      false,
      mvMatrix.storage,
    );
  }
}
