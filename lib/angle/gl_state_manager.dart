import 'package:flutter/foundation.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:vector_math/vector_math_64.dart';
import '../fsk_singleton.dart';

/// Helper to store texture parameter states for individual textures.
class TextureSettings {
  int wrapS;
  int wrapT;
  int minFilter;
  int magFilter;

  TextureSettings({
    required this.wrapS,
    required this.wrapT,
    required this.minFilter,
    required this.magFilter,
  });
}

class GlStateManager {
  // The official flutter_angle WebGL rendering context wrapper
  late RenderingContext gl;

  // Shader Tracking using flutter_angle types
  Program? _currentProgram;
  final Map<Program, Map<UniformLocation, dynamic>> _shaderUniformCache = {};

  // GL State Capabilities
  bool? _blendEnabled;
  bool? _depthTestEnabled;
  bool? _cullFaceEnabled;
  bool? _texturingEnabled;
  bool? _scissorTestEnabled;

  // State Functions & Values (mapped via int/enums from the library)
  int? _depthFunc;
  bool? _depthMask;
  int? _activeTextureUnit;
  final Map<int, WebGLTexture?> _boundTexturesByUnit =
      {}; // Map texture unit to specific WebGLTexture
  int? _cullFaceMode;

  List<double> _clearColor = [-1.0, -1.0, -1.0, -1.0];

  // Viewport tracking: [x, y, width, height]
  List<int> _viewport = [-1, -1, -1, -1];

  // Blending Enums
  int? _blendSrcRGB;
  int? _blendDstRGB;
  int? _blendSrcAlpha;
  int? _blendDstAlpha;

  // Buffer bindings using flutter_angle classes
  Buffer? _currentVBO;
  Buffer? _currentIBO;

  // Texture state tracking parameter cache
  final Map<WebGLTexture, TextureSettings> _textureParameterCache = {};

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  GlStateManager();

  void initializeGl(RenderingContext gl) {
    this.gl = gl;
    _isInitialized = true;
  }

  /// Clears all internal caches to force the next state change to be pushed to the hardware.
  /// This is critical on Web when the canvas is resized, as the browser resets the GL state.
  void hardReset() {
    _currentProgram = null;
    _shaderUniformCache.clear();
    _blendEnabled = null;
    _depthTestEnabled = null;
    _cullFaceEnabled = null;
    _texturingEnabled = null;
    _scissorTestEnabled = null;
    _depthFunc = null;
    _depthMask = null;
    _activeTextureUnit = null;
    _boundTexturesByUnit.clear();
    _cullFaceMode = null;
    _clearColor = [-1.0, -1.0, -1.0, -1.0];
    _viewport = [-1, -1, -1, -1];
    _blendSrcRGB = null;
    _blendDstRGB = null;
    _blendSrcAlpha = null;
    _blendDstAlpha = null;
    _currentVBO = null;
    _currentIBO = null;
    _textureParameterCache.clear();
  }

  void resetToDefaultState() {
    // 1. Reset Capabilities
    _blendEnabled = false;
    gl.disable(WebGL.BLEND);

    _depthTestEnabled = false;
    gl.disable(WebGL.DEPTH_TEST);

    _cullFaceEnabled = false;
    gl.disable(WebGL.CULL_FACE);

    _texturingEnabled = true;

    // 2. Reset Core Functions & Configurations
    _depthFunc = WebGL.LESS;
    gl.depthFunc(WebGL.LESS);

    _depthMask = true;
    gl.depthMask(true);

    _cullFaceMode = WebGL.BACK;
    gl.cullFace(WebGL.BACK);

    _clearColor = [0.0, 0.0, 0.0, 0.0];
    gl.clearColor(0.0, 0.0, 0.0, 0.0);

    _viewport = [-1, -1, -1, -1];
    gl.viewport(0, 0, 0, 0);

    // 3. Reset Blend Functions (Standard alpha blending defaults)
    _blendSrcRGB = WebGL.ONE;
    _blendDstRGB = WebGL.ZERO;
    _blendSrcAlpha = WebGL.ONE;
    _blendDstAlpha = WebGL.ZERO;
    gl.blendFuncSeparate(WebGL.ONE, WebGL.ZERO, WebGL.ONE, WebGL.ZERO);



    // 4. Reset Texture Units & Active Bindings
    _activeTextureUnit = WebGL.TEXTURE0;
    gl.activeTexture(WebGL.TEXTURE0);

    _boundTexturesByUnit.clear();
    gl.bindTexture(WebGL.TEXTURE_2D, null);
    _textureParameterCache.clear();

    // 5. Reset Buffer Bindings
    _currentVBO = null;
    gl.bindBuffer(WebGL.ARRAY_BUFFER, null);

    _currentIBO = null;
    gl.bindBuffer(WebGL.ELEMENT_ARRAY_BUFFER, null);

    // 6. Clear Shaders & Uniform Cache
    _currentProgram = null;
    gl.useProgram(null);
    _shaderUniformCache.clear();

    _scissorTestEnabled = false;
    gl.disable(WebGL.SCISSOR_TEST);
  }

  // --- SHADER METHODS ---

  void useProgram(Program? program, {bool force = false}) {
    if (program == null) return;
    if (force || _currentProgram != program) {
      if (kIsWeb) print("GLStateManager: Switching Program to ${program.id}");
      _currentProgram = program;
      gl.useProgram(program);
      _shaderUniformCache.putIfAbsent(program, () => {});
    }
  }

  void setUniform1i(UniformLocation uniformPos, int v, {bool force = false}) {
    if (_currentProgram == null) return;

    final uniforms = _shaderUniformCache[_currentProgram]!;
    var uniform = uniforms[uniformPos];
    if (force || uniform != v) {
      uniforms[uniformPos] = v;
      gl.uniform1i(uniformPos, v);
    }
  }

  void setUniform1f(
    UniformLocation uniformPos,
    double v, {
    bool force = false,
  }) {
    if (_currentProgram == null) return;

    final uniforms = _shaderUniformCache[_currentProgram]!;
    var uniform = uniforms[uniformPos];
    if (force || uniform != v) {
      uniforms[uniformPos] = v;
      gl.uniform1f(uniformPos, v);
    }
  }

  /// Compares values against the cache and updates it. Returns true if it was a cache hit.
  bool _checkAndUpdateCache(
    UniformLocation pos,
    List<double> newValues,
    bool force,
  ) {
    if (_currentProgram == null) return true; // Skip upload if no program

    final uniforms = _shaderUniformCache[_currentProgram]!;
    final cached = uniforms[pos];

    if (!force && cached is List<double> && cached.length == newValues.length) {
      bool identical = true;
      for (int i = 0; i < newValues.length; i++) {
        if (cached[i] != newValues[i]) {
          identical = false;
          break;
        }
      }
      if (identical) return true; // Cache hit: skip upload
    }

    // Cache miss or forced update: save a copy
    uniforms[pos] = List<double>.from(newValues);
    return false;
  }

  bool _checkAndUpdateCacheInt(
      UniformLocation pos,
      List<int> newValues,
      bool force,
      ) {
    if (_currentProgram == null) return true; // Skip upload if no program

    final uniforms = _shaderUniformCache[_currentProgram]!;
    final cached = uniforms[pos];

    if (!force && cached is List<int> && cached.length == newValues.length) {
      bool identical = true;
      for (int i = 0; i < newValues.length; i++) {
        if (cached[i] != newValues[i]) {
          identical = false;
          break;
        }
      }
      if (identical) return true; // Cache hit: skip upload
    }

    // Cache miss or forced update: save a copy
    uniforms[pos] = List<int>.from(newValues);
    return false;
  }

  void setUniform2fv(
    UniformLocation uniformPos,
    List<double> v, {
    bool force = false,
  }) {
    if (_checkAndUpdateCache(uniformPos, v, force)) return;
    gl.uniform2fv(uniformPos, v);
  }

  void setUniform3fv(
    UniformLocation uniformPos,
    List<double> v, {
    bool force = false,
  }) {
    if (_checkAndUpdateCache(uniformPos, v, force)) return;
    gl.uniform3fv(uniformPos, v);
  }

  void setUniform4fv(
    UniformLocation uniformPos,
    List<double> v, {
    bool force = false,
  }) {
    if (_checkAndUpdateCache(uniformPos, v, force)) return;
    gl.uniform4fv(uniformPos, v);
  }

  void setUniform2iv(
      UniformLocation uniformPos,
      List<int> v, {
        bool force = false,
      }) {
    if (_checkAndUpdateCacheInt(uniformPos, v, force)) return;
    gl.uniform2iv(uniformPos, v);
  }

  void setUniform3iv(
      UniformLocation uniformPos,
      List<int> v, {
        bool force = false,
      }) {
    if (_checkAndUpdateCacheInt(uniformPos, v, force)) return;
    gl.uniform3iv(uniformPos, v);
  }

  void setUniform4iv(
      UniformLocation uniformPos,
      List<int> v, {
        bool force = false,
      }) {
    if (_checkAndUpdateCacheInt(uniformPos, v, force)) return;
    gl.uniform4iv(uniformPos, v);
  }

  // It's expensive to check an entire matrix, so there's not much point in caching it.
  void setUniformMatrix2fv(UniformLocation uniformPos, Matrix2 m) {
    gl.uniformMatrix2fv(uniformPos, false, m.storage);
  }

  void setUniformMatrix3fv(UniformLocation uniformPos, Matrix3 m) {
    gl.uniformMatrix3fv(uniformPos, false, m.storage);
  }

  // It's expensive to check an entire matrix, so there's not much point in caching it.
  void setUniformMatrix4fv(UniformLocation uniformPos, Matrix4 m) {
    gl.uniformMatrix4fv(uniformPos, false, m.storage);
  }

  // --- GL CAPABILITIES ---
  void setDepthMask(bool enable, {bool force = false}) {
    if (force || _depthMask != enable) {
      _depthMask = enable;
      gl.depthMask(_depthMask!);
    }
  }

  void setBlend(bool enable, {bool force = false}) {
    if (force || _blendEnabled != enable) {
      _blendEnabled = enable;
      enable ? gl.enable(WebGL.BLEND) : gl.disable(WebGL.BLEND);
    }
  }

  void setDepthTest(bool enable, {bool force = false}) {
    if (force || _depthTestEnabled != enable) {
      _depthTestEnabled = enable;
      enable ? gl.enable(WebGL.DEPTH_TEST) : gl.disable(WebGL.DEPTH_TEST);
    }
  }

  void setCullFace(bool enable, {bool force = false}) {
    if (force || _cullFaceEnabled != enable) {
      _cullFaceEnabled = enable;
      enable ? gl.enable(WebGL.CULL_FACE) : gl.disable(WebGL.CULL_FACE);
    }
  }

  /// App-level helper state to toggle texturing routines inside drawing scripts or shaders.
  void setTexturingEnabled(bool enable, {bool force = false}) {
    if (force || _texturingEnabled != enable) {
      _texturingEnabled = enable;
    }
  }

  bool get isTexturingEnabled => _texturingEnabled ?? true;

  // --- GL STATES ---

  void setViewport(int x, int y, int width, int height, {bool force = false}) {
    if (force ||
        _viewport[0] != x ||
        _viewport[1] != y ||
        _viewport[2] != width ||
        _viewport[3] != height) {
      if (kIsWeb) print("GLStateManager: Viewport set to ${x},${y} ${width}x${height}");
      _viewport = [x, y, width, height];
      gl.viewport(x, y, width, height);
    }
  }

  void depthFunc(int func, {bool force = false}) {
    if (force || _depthFunc != func) {
      _depthFunc = func;
      gl.depthFunc(func);
    }
  }

  void scissorEnabled(bool enable, {bool force = false}) {
    if (force || _scissorTestEnabled != enable) {
      _scissorTestEnabled = enable;
      enable ? gl.enable(WebGL.SCISSOR_TEST) : gl.disable(WebGL.SCISSOR_TEST);
    }
  }

  void depthMask(bool flag, {bool force = false}) {
    if (force || _depthMask != flag) {
      _depthMask = flag;
      gl.depthMask(flag);
    }
  }

  void activeTexture(int textureUnit, {bool force = false}) {
    if (force || _activeTextureUnit != textureUnit) {
      _activeTextureUnit = textureUnit;
      gl.activeTexture(textureUnit);
    }
  }

  void bindTexture(int target, WebGLTexture? texture, {bool force = false}) {
    final currentUnit = _activeTextureUnit ?? WebGL.TEXTURE0;
    if (force || _boundTexturesByUnit[currentUnit] != texture) {
      if (kIsWeb && texture != null) print("GLStateManager: Binding Texture ${texture.id} to Unit $currentUnit");
      _boundTexturesByUnit[currentUnit] = texture;
      gl.bindTexture(target, texture);

      // Apply cached parameters immediately if a real texture is bound
      if (texture != null) {
        _applyCachedTextureParameters(target, texture);
      }
    }
  }

  /// Internal utility to execute parameter updates against bound context.
  void _applyCachedTextureParameters(int target, WebGLTexture texture,{TextureSettings? settings}) {
    if (settings == null) return;
    gl.texParameteri(target, WebGL.TEXTURE_WRAP_S, settings.wrapS);
    gl.texParameteri(target, WebGL.TEXTURE_WRAP_T, settings.wrapT);
    gl.texParameteri(target, WebGL.TEXTURE_MIN_FILTER, settings.minFilter);
    gl.texParameteri(target, WebGL.TEXTURE_MAG_FILTER, settings.magFilter);
  }

  void setTextureParameters(
    WebGLTexture texture, {
    required int wrapS,
    required int wrapT,
    required int minFilter,
    required int magFilter,
  }) {
    final settings = _textureParameterCache.putIfAbsent(
      texture,
      () => TextureSettings(
        wrapS: wrapS,
        wrapT: wrapT,
        minFilter: minFilter,
        magFilter: magFilter,
      ),
    );

    // If this texture is currently bound to the active unit, push modifications immediately
    final currentUnit = _activeTextureUnit ?? WebGL.TEXTURE0;
    if (_boundTexturesByUnit[currentUnit] == texture) {
      _applyCachedTextureParameters(WebGL.TEXTURE_2D, texture,settings: settings);
    }
  }

  void cullFace(int mode, {bool force = false}) {
    if (force || _cullFaceMode != mode) {
      _cullFaceMode = mode;
      gl.cullFace(mode);
    }
  }

  void clearColor(
    double r,
    double g,
    double b,
    double a, {
    bool force = false,
  }) {
    if (force ||
        _clearColor[0] != r ||
        _clearColor[1] != g ||
        _clearColor[2] != b ||
        _clearColor[3] != a) {
      if (kIsWeb) print("GLStateManager: Clear Color set to ($r, $g, $b, $a)");
      _clearColor = [r, g, b, a];
      gl.clearColor(r, g, b, a);
    }
  }

  void blendFuncSeparate(
    int srcRGB,
    int dstRGB,
    int srcAlpha,
    int dstAlpha, {
    bool force = false,
  }) {
    if (force ||
        _blendSrcRGB != srcRGB ||
        _blendDstRGB != dstRGB ||
        _blendSrcAlpha != srcAlpha ||
        _blendDstAlpha != dstAlpha) {
      _blendSrcRGB = srcRGB;
      _blendDstRGB = dstRGB;
      _blendSrcAlpha = srcAlpha;
      _blendDstAlpha = dstAlpha;
      gl.blendFuncSeparate(srcRGB, dstRGB, srcAlpha, dstAlpha);
    }
  }

  // --- BUFFER BINDINGS ---
  void bufferData(int target, dynamic data, int usage) {
    gl.bufferData(target, data, usage);
  }

  /// Activates state parameters on individual index layouts.
  void enableVertexAttribArray(int index) {
    gl.enableVertexAttribArray(index);
  }

  /// Deactivates layout channels when arrays complete drawing tasks.
  void disableVertexAttribArray(int index) {
    gl.disableVertexAttribArray(index);
  }

  /// Sets array formatting specifications relative to strides and offsets.
  void vertexAttribPointer(
    int index,
    int size,
    int type,
    bool normalized,
    int stride,
    int offset,
  ) {
    gl.vertexAttribPointer(index, size, type, normalized, stride, offset);
  }

  /// Disposes GPU allocated buffers and resets local active bindings if tracked.
  void deleteBuffer(Buffer? buffer) {
    if (buffer == null) return;

    gl.deleteBuffer(buffer);

    if (_currentVBO == buffer) _currentVBO = null;
    if (_currentIBO == buffer) _currentIBO = null;
  }

  void bindVertexBuffer(Buffer? vbo, {bool force = false}) {
    if (force || _currentVBO != vbo) {
      _currentVBO = vbo;
      gl.bindBuffer(WebGL.ARRAY_BUFFER, vbo);
    }
  }

  void bindIndexBuffer(Buffer? ibo, {bool force = false}) {
    if (force || _currentIBO != ibo) {
      _currentIBO = ibo;
      gl.bindBuffer(WebGL.ELEMENT_ARRAY_BUFFER, ibo);
    }
  }

  // Must be called before rendering a scene
  void startFrame() {
    if (kIsWeb) {
      int error = gl.getError();
      if (error != 0) {
        print("GLStateManager: StartFrame error detected: $error");
      }
    }
    FSK().textureManager.bindUnboundTextures();
  }
}
