import 'dart:typed_data';
import 'package:flutter_gpu/gpu.dart' as gpu;

import '../fsk_scene.dart';

/// Manages a flutter_gpu DeviceBuffer.
class VertexBuffer {
  gpu.DeviceBuffer? _deviceBuffer;
  gpu.DeviceBuffer? get deviceBuffer => _deviceBuffer;

  // TODO: Hardcoded
  int _vertexCount = 0;
  static const int _strideInBytes = 48;
  static const int _componentCount = 12;

  int get stride => _strideInBytes;
  int get componentCount => _componentCount;

  // Layout is V3, T2, N3, C4
  Float32List? vertexData;

  VertexBuffer();

  /// Sends current CPU data over to physical GPU device memory.
  void uploadData(FskScene parentScene) {
    if (vertexData == null) {
      print("Abort. No vertex data to upload!");
      return;
    }

    final int activeBytesSize = _vertexCount * _strideInBytes;

    final ByteData view = vertexData!.buffer.asByteData(
      vertexData!.offsetInBytes,
      activeBytesSize,
    );

    if (_deviceBuffer != null) {
      parentScene.retainedOldBuffers.add(_deviceBuffer!);
    }

    _deviceBuffer = gpu.gpuContext.createDeviceBufferWithCopy(view);
  }

  /// Allocates host CPU memory arrays to store structural coordinates.
  Float32List? requestBuffer(int newVertexCount) {
    assert(newVertexCount > 0);

    vertexData = Float32List(newVertexCount * _componentCount);
    _vertexCount = newVertexCount;

    return vertexData;
  }

  /// Records buffer bindings to a specific binding slot on an active RenderPass.
  void bind(gpu.RenderPass renderPass, {int slot = 0}) {
    if (_deviceBuffer == null) return;

    final gpu.BufferView view = gpu.BufferView(
      _deviceBuffer!,
      offsetInBytes: 0,
      lengthInBytes: _deviceBuffer!.sizeInBytes,
    );

    renderPass.bindVertexBuffer(view, slot: slot);
  }

  /// Draws the currently active vertices as triangles.
  void drawTriangles(gpu.RenderPass renderPass) {
    // TODO: Vertex count of 0 is not possible
    if (_vertexCount <= 0) return;
    renderPass.draw(_vertexCount);
  }

  void dispose() {
    _deviceBuffer = null;
    vertexData = null;
  }

  void printVertices() {
    print("Printing vertices:");
    if (vertexData == null) return;
    for (int i = 0; i < _vertexCount; i++) {
      final int offset = i * _componentCount;
      final double x = vertexData![offset];
      final double y = vertexData![offset + 1];
      final double z = vertexData![offset + 2];
      final double t1 = vertexData![offset + 3];
      final double t2 = vertexData![offset + 4];

      print('Vertex $i: ($x, $y, $z), texture coords($t1, $t2)');
    }
  }
}
