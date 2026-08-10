import 'dart:typed_data';
import 'package:flutter_gpu/gpu.dart' as gpu;

/// Manages a flutter_gpu DeviceBuffer.
class FskVertexBuffer {
  // The GPU buffer to store the vertices in
  gpu.DeviceBuffer? _deviceBuffer;
  gpu.DeviceBuffer? get deviceBuffer => _deviceBuffer;

  // Constants for the vertex buffer stride and component count
  // Currently, vertex buffers always allocate all 12 components for V3T2N3C4
  // even if not used. Shaders all need to use that layout
  static const int strideInBytes = 48;
  static const int componentCount = 12;

  // The host buffer for the vertices. Now optional as the Mesh may own the data.
  Float32List? vertexData;

  // The number of vertices
  int _vertexCount = 0;
  int get vertexCount => _vertexCount;

  FskVertexBuffer();

  /// Sends CPU data over to physical GPU device memory.
  void uploadData([Float32List? data]) {
    final uploadSource = data ?? vertexData;
    if (uploadSource == null || uploadSource.isEmpty) return;

    // Store the data in the host buffer for debugging and retrieval
    if (data != null) {
      vertexData = data;
    }

    final int count = uploadSource.length ~/ componentCount;
    final int activeBytesSize = count * strideInBytes;

    final ByteData view = uploadSource.buffer.asByteData(
      uploadSource.offsetInBytes,
      activeBytesSize,
    );

    _deviceBuffer = gpu.gpuContext.createDeviceBufferWithCopy(view);
    _vertexCount = count;
  }

  void clear() {
    _deviceBuffer = null;
    vertexData = null;
    _vertexCount = 0;
  }

  /// Explicitly releases GPU resources.
  void dispose() {
    clear();
  }

  /// Allocate host CPU memory arrays to store structural coordinates.
  Float32List? requestBuffer(int newVertexCount) {

    if (newVertexCount == 0) {
      clear();
      return null;
    }

    if (newVertexCount != _vertexCount || vertexData == null) {
      vertexData = Float32List(newVertexCount * componentCount);
      _vertexCount = newVertexCount;
    }
    return vertexData;
  }

  /// Copies vertex data from another list.
  void setFrom(Float32List source) {
    final int count = source.length ~/ componentCount;
    requestBuffer(count);
    vertexData!.setAll(0, source);
  }

  /// Records buffer bindings to a specific binding slot on an active RenderPass.
  void bind(gpu.RenderPass renderPass, {int slot = 0, int offsetInVertices = 0}) {
    if (_deviceBuffer == null) return;
    assert(
      _deviceBuffer != null,
      "FskVertexBuffer::bind called with null device buffer",
    );

    final int offsetInBytes = offsetInVertices * strideInBytes;

    final gpu.BufferView view = gpu.BufferView(
      _deviceBuffer!,
      offsetInBytes: offsetInBytes,
      lengthInBytes: _deviceBuffer!.sizeInBytes - offsetInBytes,
    );

    renderPass.bindVertexBuffer(view, slot: slot);
  }

  /// Draws the currently active vertices as triangles.
  void drawTriangles(gpu.RenderPass renderPass) {
    if (_deviceBuffer == null) return;
    assert(
      _deviceBuffer != null,
      "FskVertexBuffer::drawTriangles called with null device buffer",
    );
    assert(
      _vertexCount > 0,
      "FskVertexBuffer::drawTriangles called with zero vertex count",
    );
    renderPass.draw(_vertexCount);
  }
}
