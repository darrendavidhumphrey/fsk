import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';

import '../util.dart';

class CheckerBoardUniforms {
  // --- Class Instance Variables ---
  final gpu.Shader? _vertexShader;
  final gpu.Shader? _fragmentShader;

  Matrix4 _mvMatrix = Matrix4.identity();
  Matrix4 _pMatrix = Matrix4.identity();

  Color _patternColor1 = const Color(0xFFFFFFFF);
  Color _patternColor2 = const Color(0xFF000000);
  bool _useTexture = false;
  double _textureMix = 0.0;
  double _patternScale = 1.0;


  // --- Vertex Attribute Setters ---
  set mvMatrix(Matrix4 value) => _mvMatrix = value;
  set pMatrix(Matrix4 value) => _pMatrix = value;

  // --- Fragment Parameter Setters ---
  set patternColor1(Color value) => _patternColor1 = value;
  set patternColor2(Color value) => _patternColor2 = value;
  set useTexture(bool value) => _useTexture = value;
  set textureMix(double value) => _textureMix = value;
  set patternScale(double value) => _patternScale = value;

  CheckerBoardUniforms({this._vertexShader, this._fragmentShader});

  /// Binds vertex matrices and fragment settings to the modern render pass.
  /// Reads configuration parameters directly from class instance state variables.
  void bind(gpu.RenderPass renderPass) {
    // Safety assertions to ensure context anchors are active before processing
    if ( _vertexShader == null || _fragmentShader == null) {
      throw StateError(
          'Cannot set uniforms: renderPass, vertexShader, and fragmentShader must all be assigned first.'
      );
    }

    // 1. Create a transient host allocator for this frames' uniform data
    final gpu.HostBuffer transients = gpu.gpuContext.createHostBuffer();

    // =========================================================================
    // VERTEX UNIFORMS: Layout std140
    // Structural order matching: mat4 uMVMatrix, mat4 uPMatrix
    // =========================================================================
    final Float32List vertexData = Float32List(32); // 2 matrices * 16 floats

    // Copy the float storage arrays directly from state
    vertexData.setAll(0, _mvMatrix.storage);
    vertexData.setAll(16, _pMatrix.storage);

    // Emplace the raw bytes onto the GPU host memory channel
    final gpu.BufferView vertexBufferView = transients.emplace(
      vertexData.buffer.asByteData(),
    );

    // Fetch the structural block slot configuration and bind it
    final gpu.UniformSlot vertexSlot = _vertexShader!.getUniformSlot('VertexUniforms');
    renderPass.bindUniform(vertexSlot, vertexBufferView);

    // =========================================================================
    // FRAGMENT UNIFORMS: Layout std140
    // Structural order matching: vec4 c1, vec4 c2, vec4 uConfig
    // =========================================================================
    final Float32List fragmentData = Float32List(12); // Exactly 48 bytes (3 x vec4)
    int offset = 0;

    // Block 1: vec4 uPatternColor1 (Offset: 0 bytes / float indices 0-3)
    offset = packColor(fragmentData, offset, _patternColor1);

    // Block 2: vec4 uPatternColor2 (Offset: 16 bytes / float indices 4-7)
    offset = packColor(fragmentData, offset, _patternColor2);

    // Block 3: vec4 uConfig (Offset: 32 bytes / float indices 8-11)
    fragmentData[8] = _useTexture ? 1.0 : 0.0;     // maps to uConfig.x
    fragmentData[9] = _textureMix.toDouble();      // maps to uConfig.y
    fragmentData[10] = _patternScale.toDouble();   // maps to uConfig.z
    fragmentData[11] = 0.0;                        // maps to uConfig.w (safety padding)

    // Emplace fragment byte data
    final gpu.BufferView fragmentBufferView = transients.emplace(
      fragmentData.buffer.asByteData(),
    );

    // Fetch the structural fragment configuration block slot and bind it
    final gpu.UniformSlot fragmentSlot = _fragmentShader!.getUniformSlot('FragmentUniforms');
    renderPass.bindUniform(fragmentSlot, fragmentBufferView);
  }
}
