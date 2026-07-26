import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';

class GridUniforms {
  // --- Pipeline Allocation Subsystems ---
  final gpu.Shader? _vertexShader;
  final gpu.Shader? _fragmentShader;

  GridUniforms({this._vertexShader, this._fragmentShader});

  // --- Vertex Transform Variables ---
  Matrix4 _mvMatrix = Matrix4.identity();
  Matrix4 _pMatrix = Matrix4.identity();

  // --- Fragment Grid Variables ---
  Color _majorLineColor = const Color(0xFFFFFFFF);
  Color _minorLineColor = const Color(0xFFB0B0B0);
  Color _mmLineColor = const Color(0xFF606060);

  double _resolutionWidth = 1024.0;
  double _resolutionHeight = 768.0;

  double _scale = 1.0;
  double _majorLineSpacingMM = 10.0;
  double _minorLineSpacingMM = 5.0;
  double _majorLineThickness = 1.5;
  double _minorLineThickness = 1.0;
  double _mmLineThickness = 0.5;


  // --- Vertex Attribute Setters ---
  set mvMatrix(Matrix4 value) => _mvMatrix = value;
  set pMatrix(Matrix4 value) => _pMatrix = value;

  // --- Fragment Visual Setters ---
  set majorLineColor(Color value) => _majorLineColor = value;
  set minorLineColor(Color value) => _minorLineColor = value;
  set mmLineColor(Color value) => _mmLineColor = value;

  void setResolution(double width, double height) {
    _resolutionWidth = width;
    _resolutionHeight = height;
  }

  set scale(double value) => _scale = value;
  set majorLineSpacingMM(double value) => _majorLineSpacingMM = value;
  set minorLineSpacingMM(double value) => _minorLineSpacingMM = value;
  set majorLineThickness(double value) => _majorLineThickness = value;
  set minorLineThickness(double value) => _minorLineThickness = value;
  set mmLineThickness(double value) => _mmLineThickness = value;

  // --- Dry Byte-Packing Helper ---
  int _packColor(Float32List targetList, int offset, Color color) {
    targetList[offset++] = color.r;
    targetList[offset++] = color.g;
    targetList[offset++] = color.b;
    targetList[offset++] = color.a;
    return offset;
  }

  /// Synchronizes and commits all internal configuration parameters
  /// straight down to the execution pass uniform slots.
  void bind(gpu.RenderPass renderPass) {
    if (_vertexShader == null || _fragmentShader == null) {
      throw StateError(
          'Cannot commit grid uniforms: Active pipeline anchors are missing.'
      );
    }

    final gpu.HostBuffer transients = gpu.gpuContext.createHostBuffer();

    // =========================================================================
    // 1. COMMITTING VERTEX MATRIX TRANSLATIONS (std140 -> 32 floats / 128 bytes)
    // =========================================================================
    final Float32List vertexData = Float32List(32);
    vertexData.setAll(0, _mvMatrix.storage);
    vertexData.setAll(16, _pMatrix.storage);

    final gpu.BufferView vertexBufferView = transients.emplace(
      vertexData.buffer.asByteData(),
    );
    final gpu.UniformSlot vertexSlot = _vertexShader.getUniformSlot('VertexUniforms');
    renderPass.bindUniform(vertexSlot, vertexBufferView);

    // =========================================================================
    // 2. COMMITTING FRAGMENT SCHEMAS (std140 -> 22 floats / 88 bytes)
    // =========================================================================
    final Float32List fragmentData = Float32List(22);
    int offset = 0;

    // Phase 1: vec4 lines (Indices 0 - 11)
    offset = _packColor(fragmentData, offset, _majorLineColor);
    offset = _packColor(fragmentData, offset, _minorLineColor);
    offset = _packColor(fragmentData, offset, _mmLineColor);

    // Phase 2: vec2 u_resolution (Indices 12, 13)
    fragmentData[offset++] = _resolutionWidth;
    fragmentData[offset++] = _resolutionHeight;

    // Phase 3: Pack loose configuration scalar parameters tightly (Indices 14 - 19)
    fragmentData[offset++] = _scale;
    fragmentData[offset++] = _majorLineSpacingMM;
    fragmentData[offset++] = _minorLineSpacingMM;
    fragmentData[offset++] = _majorLineThickness;
    fragmentData[offset++] = _minorLineThickness;
    fragmentData[offset++] = _mmLineThickness;

    // Phase 4: Struct tail allocation alignment padding (Indices 20, 21)
    fragmentData[offset++] = 0.0;
    fragmentData[offset++] = 0.0;

    final gpu.BufferView fragmentBufferView = transients.emplace(
      fragmentData.buffer.asByteData(),
    );
    final gpu.UniformSlot fragmentSlot = _fragmentShader.getUniformSlot('FragmentUniforms');
    renderPass.bindUniform(fragmentSlot, fragmentBufferView);
  }
}
