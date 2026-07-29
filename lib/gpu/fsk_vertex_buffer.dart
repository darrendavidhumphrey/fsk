import 'dart:typed_data';
import 'package:flutter_gpu/gpu.dart' as gpu;

import '../fsk_scene.dart';

/// Manages a flutter_gpu DeviceBuffer.
class FskVertexBuffer {

  // The GPU buffer to store the vertices in
  gpu.DeviceBuffer? _deviceBuffer;
  gpu.DeviceBuffer? get deviceBuffer => _deviceBuffer;

  // Constants for the vertex buffer stride and component count
  // Currently, vertex buffers always allocate all 12 components for VTNC
  // even if not used. Shaders all need to use that layout
  static const int _strideInBytes = 48;
  static const int _componentCount = 12;

  int get stride => _strideInBytes;
  int get componentCount => _componentCount;

  // The host buffer for the vertices
  Float32List? vertexData;

  // The number of vertices in vertexData
  int _vertexCount = 0;

  FskVertexBuffer();

  /// Sends current CPU data over to physical GPU device memory.
  void uploadData(FskScene parentScene) {
    assert(_vertexCount > 0,"FskVertexBuffer::uploadData called with zero vertex count");
    assert(vertexData != null,"FskVertexBuffer::uploadData called and vertexData is null");

    final int activeBytesSize = _vertexCount * _strideInBytes;

    final ByteData view = vertexData!.buffer.asByteData(
      vertexData!.offsetInBytes,
      activeBytesSize,
    );

    // If the vertex buffer is reallocated, don't delete the old buffer immediately
    // Instead, place it in a list to be cleared after the rendering completed
    // This is POSSIBLY necessary to prevent weird rendering bugs
    if (_deviceBuffer != null) {
      parentScene.retainedOldBuffers.add(_deviceBuffer!);
    }

    _deviceBuffer = gpu.gpuContext.createDeviceBufferWithCopy(view);
  }

  /// Allocate host CPU memory arrays to store structural coordinates.
  Float32List? requestBuffer(int newVertexCount) {
    assert(newVertexCount > 0,"FskVertexBuffer::requestBuffer called with zero vertex count");

    vertexData = Float32List(newVertexCount * _componentCount);
    _vertexCount = newVertexCount;

    return vertexData;
  }

  /// Records buffer bindings to a specific binding slot on an active RenderPass.
  void bind(gpu.RenderPass renderPass, {int slot = 0}) {
    assert(_deviceBuffer != null,"FskVertexBuffer::bind called with null device buffer");

    final gpu.BufferView view = gpu.BufferView(
      _deviceBuffer!,
      offsetInBytes: 0,
      lengthInBytes: _deviceBuffer!.sizeInBytes,
    );

    renderPass.bindVertexBuffer(view, slot: slot);
  }

  /// Draws the currently active vertices as triangles.
  void drawTriangles(gpu.RenderPass renderPass) {
    assert(_deviceBuffer != null,"FskVertexBuffer::drawTriangles called with null device buffer");
    assert(_vertexCount > 0, "FskVertexBuffer::drawTriangles called with zero vertex count");
    renderPass.draw(_vertexCount);
  }

  void dispose() {
    _deviceBuffer = null;
    vertexData = null;
  }
}
