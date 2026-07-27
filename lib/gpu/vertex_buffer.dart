import 'dart:typed_data';
import 'package:flutter_gpu/gpu.dart' as gpu;


/// Manages a flutter_gpu DeviceBuffer.
class VertexBuffer {
  gpu.DeviceBuffer? _deviceBuffer;
  gpu.DeviceBuffer? get deviceBuffer => _deviceBuffer;

  int _activeVertexCount = 0;
  int _capacity = 0;


  static const int _stride = 48;
  static const int _componentCount = 12;

  int get activeVertexCount => _activeVertexCount;
  int get capacity => _capacity;
  int get stride => _stride;
  int get componentCount => _componentCount;

  // Layout is V3, T2, N3, C4
  Float32List? vertexData;

  VertexBuffer();

  /// Sets the active vertex count and automatically uploads the buffer data.
  void setActiveVertexCount(int count) {
    _activeVertexCount = count;
    uploadData();
  }

  /// Sends current CPU data over to physical GPU device memory.
  void uploadData() {
    if (_activeVertexCount <= 0 || vertexData == null) return;

    final int activeBytesSize = _activeVertexCount * _stride;

    final ByteData view = vertexData!.buffer.asByteData(
      vertexData!.offsetInBytes, // Start at byte 0
      activeBytesSize,           // Total length in bytes (e.g., 120)
    );

    _deviceBuffer = gpu.gpuContext.createDeviceBufferWithCopy(view);
  }

  /// Allocates host CPU memory arrays to store structural coordinates.
  Float32List? requestBuffer(int newVertexCount) {
    final bool needsReallocation = newVertexCount > _capacity || (newVertexCount < _capacity / 2);

    if (needsReallocation) {
      vertexData = newVertexCount > 0 ? Float32List(newVertexCount * _componentCount) : null;
      _capacity = newVertexCount;

      if (_activeVertexCount > _capacity) {
        _activeVertexCount = _capacity;
      }
    }
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
    if (_activeVertexCount > 0) {
      renderPass.draw(_activeVertexCount);
    }
  }

  void dispose() {
    _deviceBuffer = null;
    vertexData = null;
  }

  void printVertices() {
    print("Printing vertices:");
    if (vertexData == null) return;
    for (int i = 0; i < _activeVertexCount; i++) {
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