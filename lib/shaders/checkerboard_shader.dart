
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';


class CheckerBoardUniforms {

// TODO: Move to base class
  static int packColor(Float32List targetList, int offset, Color color) {
    targetList[offset++] = color.r;
    targetList[offset++] = color.g;
    targetList[offset++] = color.b;
    targetList[offset++] = color.a;
    return offset;
  }


  /// Binds vertex matrices and fragment settings to the modern render pass.
  static void setUniforms({
  required gpu.RenderPass renderPass,
  required gpu.Shader vertexShader,
  required gpu.Shader fragmentShader,
  // Vertex parameters
  required Matrix4 mvMatrix,
  required Matrix4 pMatrix,
  // Fragment parameters
  required Color patternColor1,
  required Color patternColor2,
  required bool useTexture,
  required double textureMix,
  required double patternScale,
  }) {
  // 1. Create a transient host allocator for this frames' uniform data
  final gpu.HostBuffer transients = gpu.gpuContext.createHostBuffer();

  // =========================================================================
  // VERTEX UNIFORMS: Layout std140
  // Structural order matching: mat4 uMVMatrix, mat4 uPMatrix
  // =========================================================================
  final Float32List vertexData = Float32List(32); // 2 matrices * 16 floats

  // Copy the float storage arrays directly
  vertexData.setAll(0, mvMatrix.storage);
  vertexData.setAll(16, pMatrix.storage);

  // Emplace the raw bytes onto the GPU host memory channel
  final gpu.BufferView vertexBufferView = transients.emplace(
  vertexData.buffer.asByteData(),
  );

  // Fetch the structural block slot configuration and bind it
  final gpu.UniformSlot vertexSlot = vertexShader.getUniformSlot('VertexUniforms');
  renderPass.bindUniform(vertexSlot, vertexBufferView);

  // =========================================================================
  // FRAGMENT UNIFORMS: Layout std140
  // Structural order matching: vec4 c1, vec4 c2, vec4 uConfig
  // =========================================================================
  final Float32List fragmentData = Float32List(12); // Exactly 48 bytes (3 x vec4)
  int offset = 0;

  // Block 1: vec4 uPatternColor1 (Offset: 0 bytes / float indices 0-3)
  offset = packColor(fragmentData, offset, patternColor1);

  // Block 2: vec4 uPatternColor2 (Offset: 16 bytes / float indices 4-7)
  offset = packColor(fragmentData, offset, patternColor2);

  // Block 3: vec4 uConfig (Offset: 32 bytes / float indices 8-11)
  fragmentData[8] = useTexture ? 1.0 : 0.0;  // maps to uConfig.x
  fragmentData[9] = textureMix.toDouble();   // maps to uConfig.y
  fragmentData[10] = patternScale.toDouble(); // maps to uConfig.z
  fragmentData[11] = 0.0;                    // maps to uConfig.w (safety padding)

  // Emplace fragment byte data
  final gpu.BufferView fragmentBufferView = transients.emplace(
    fragmentData.buffer.asByteData(),
  );

  // Fetch the structural fragment configuration block slot and bind it
  final gpu.UniformSlot fragmentSlot = fragmentShader.getUniformSlot('FragmentUniforms');
  renderPass.bindUniform(fragmentSlot, fragmentBufferView);
  }
}