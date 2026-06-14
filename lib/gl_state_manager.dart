import 'package:flutter_angle/flutter_angle.dart';
import 'package:vector_math/vector_math_64.dart';
import 'fsg_singleton.dart';

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
  final Map<int, WebGLTexture?> _boundTexturesByUnit = {}; // Map texture unit to specific WebGLTexture
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

  GlStateManager();

  void initializeGl(RenderingContext gl) {
    this.gl = gl;
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

    _viewport =[-1,-1,-1,-1];
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
      _currentProgram = program;
      gl.useProgram(program);
      _shaderUniformCache.putIfAbsent(program, () => {});
    }
  }

  void setUniform1i(UniformLocation uniformPos, int v, {bool force = false}) {
    if (_currentProgram == null) return;

    final uniforms = _shaderUniformCache[_currentProgram]!;
    var uniform = uniforms[uniformPos];
// TODO: Check for same or use force logic
    gl.uniform1i(uniformPos, v);
  }

  void setUniform1f(UniformLocation uniformPos, double v, {bool force = false}) {
    if (_currentProgram == null) return;

    final uniforms = _shaderUniformCache[_currentProgram]!;
    var uniform = uniforms[uniformPos];
// TODO: Check for same or use force logic
    gl.uniform1f(uniformPos, v);
  }

  void setUniform2f(UniformLocation uniformPos, double x, double y, {bool force = false}) {
    if (_currentProgram == null) return;

    final uniforms = _shaderUniformCache[_currentProgram]!;
    var uniform = uniforms[uniformPos];
// TODO: Check for same or use force logic
    gl.uniform2f(uniformPos, x, y);
  }

  void setUniform3f(UniformLocation uniformPos, double x, double y, double z, {bool force = false}) {
    if (_currentProgram == null) return;

    final uniforms = _shaderUniformCache[_currentProgram]!;
    var uniform = uniforms[uniformPos];
// TODO: Check for same or use force logic
    gl.uniform3f(uniformPos, x, y, z);
  }

  void setUniform4f(UniformLocation uniformPos, double x, double y, double z, double w,{bool force = false}) {
    if (_currentProgram == null) return;

    final uniforms = _shaderUniformCache[_currentProgram]!;
    var uniform = uniforms[uniformPos];
// TODO: Check for same or use force logic
    gl.uniform4f(uniformPos, x, y, z, w);
  }

  void setUniform4fv(UniformLocation uniformPos, List<double> u,{bool force = false}) {
    if (_currentProgram == null) return;

    final uniforms = _shaderUniformCache[_currentProgram]!;
    var uniform = uniforms[uniformPos];
// TODO: Check for same or use force logic
    gl.uniform4fv(uniformPos, u);
  }
  void setUniformMatrix3fv(UniformLocation uniformPos,Matrix3 m) {
    final uniforms = _shaderUniformCache[_currentProgram]!;
    var uniform = uniforms[uniformPos];
    uniforms[uniformPos] = m.storage;
    // TODO: Check for same or use force logic
    gl.uniformMatrix3fv(uniformPos, false, m.storage);
  }

  void setUniformMatrix4fv(UniformLocation uniformPos,Matrix4 m) {
    final uniforms = _shaderUniformCache[_currentProgram]!;
    var uniform = uniforms[uniformPos];
    uniforms[uniformPos] = m.storage;
    // TODO: Check for same or use force logic
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
      _boundTexturesByUnit[currentUnit] = texture;
      gl.bindTexture(target, texture);
    }
  }

  void cullFace(int mode, {bool force = false}) {
    if (force || _cullFaceMode != mode) {
      _cullFaceMode = mode;
      gl.cullFace(mode);
    }
  }

  void clearColor(double r, double g, double b, double a, {bool force = false}) {
    if (force ||
        _clearColor[0] != r ||
        _clearColor[1] != g ||
        _clearColor[2] != b ||
        _clearColor[3] != a) {
      _clearColor = [r, g, b, a];
      gl.clearColor(r, g, b, a);
    }
  }

  void blendFuncSeparate(int srcRGB, int dstRGB, int srcAlpha, int dstAlpha, {bool force = false}) {
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
    FSG().textureManager.bindUnboundTextures();
  }
}
