import 'dart:typed_data';
import 'package:flutter_gpu/gpu.dart' as gpu;

/// Manages a flutter_gpu DeviceBuffer used as an Index Buffer Object (IBO).
class FskIndexBuffer {
  gpu.DeviceBuffer? _deviceBuffer;
  int _activeIndexCount = 0;
  
  // Track the type of indices stored in the buffer
  gpu.IndexType _indexType = gpu.IndexType.int16;
  gpu.IndexType get indexType => _indexType;

  int get indexCount => _activeIndexCount;

  FskIndexBuffer();

  /// Sends CPU data over to physical GPU device memory.
  void uploadData(TypedData data) {
    int count = 0;
    int bytesPerElement = 1;
    
    if (data is Uint16List) {
      _indexType = gpu.IndexType.int16;
      count = data.length;
      bytesPerElement = 2;
    } else if (data is Uint32List) {
      _indexType = gpu.IndexType.int32;
      count = data.length;
      bytesPerElement = 4;
    } else if (data is Uint8List) {
      // Expand to 16-bit for safe flutter_gpu hardware compatibility
      final expanded = Uint16List.fromList(data);
      uploadData(expanded);
      return;
    } else {
      throw ArgumentError('Unsupported index data type: ${data.runtimeType}');
    }

    if (count == 0) {
      _deviceBuffer = null;
      _activeIndexCount = 0;
      return;
    }

    final int activeBytesSize = count * bytesPerElement;
    final ByteData view = data.buffer.asByteData(data.offsetInBytes, activeBytesSize);

    _deviceBuffer = gpu.gpuContext.createDeviceBufferWithCopy(view);
    _activeIndexCount = count;
  }

  /// Explicitly releases GPU resources.
  void dispose() {
    _deviceBuffer = null;
    _activeIndexCount = 0;
  }

  void bind(gpu.RenderPass renderPass, {int offsetInIndices = 0}) {
    if (_deviceBuffer == null) return;

    final int bytesPerElement = _indexType == gpu.IndexType.int32 ? 4 : 2;
    final int offsetInBytes = offsetInIndices * bytesPerElement;
    
    final gpu.BufferView view = gpu.BufferView(
      _deviceBuffer!,
      offsetInBytes: offsetInBytes,
      lengthInBytes: _deviceBuffer!.sizeInBytes - offsetInBytes,
    );

    renderPass.bindIndexBuffer(view, _indexType);
  }

  void drawTrianglesIndexed(gpu.RenderPass renderPass, {int? count}) {
    final drawCount = count ?? _activeIndexCount;
    if (drawCount > 0) {
      renderPass.drawIndexed(drawCount);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is FskIndexBuffer &&
              _deviceBuffer == other._deviceBuffer;

  @override
  int get hashCode => _deviceBuffer.hashCode;
}
