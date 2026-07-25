
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
  // Structural order matching: vec4 c1, vec4 c2, float useTex, float mix, float scale
  // =========================================================================
  // Total float reservation calculation:
  // vec4 (4) + vec4 (4) + float (1) + float (1) + float (1) = 11 floats.
  // std140 structs must be rounded up to the nearest vec4 boundary (12 floats / 48 bytes).
  final Float32List fragmentData = Float32List(12);
  int offset = 0;

  // vec4 uPatternColor1 (16 bytes, Offset: 0)
  offset = packColor(fragmentData, offset, patternColor1);

  // vec4 uPatternColor2 (16 bytes, Offset: 16)
  offset = packColor(fragmentData, offset, patternColor2);

  // float uUseTexture (4 bytes, Offset: 32)
  fragmentData[offset++] = useTexture ? 1.0 : 0.0;

  // float uTextureMix (4 bytes, Offset: 36)
  fragmentData[offset++] = textureMix.toDouble();

  // float uPatternScale (4 bytes, Offset: 40)
  fragmentData[offset++] = patternScale.toDouble();

  // Final Explicit struct boundary padding alignment (4 bytes, Offset: 44)
  fragmentData[offset++] = 0.0;

  // Emplace fragment byte data
  final gpu.BufferView fragmentBufferView = transients.emplace(
  fragmentData.buffer.asByteData(),
  );

  // Fetch the structural fragment configuration block slot and bind it
  final gpu.UniformSlot fragmentSlot = fragmentShader.getUniformSlot('FragmentUniforms');
  renderPass.bindUniform(fragmentSlot, fragmentBufferView);
  }
}