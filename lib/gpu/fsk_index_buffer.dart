import 'dart:typed_data';
import 'package:flutter_gpu/gpu.dart' as gpu;

/// Manages a flutter_gpu DeviceBuffer used as an Index Buffer Object (IBO).
///
/// This class handles the creation, allocation, data transfer, and disposal of a
/// buffer used for indexed drawing with `renderPass.drawIndexed`.
class FskIndexBuffer {
  /// The underlying physical GPU hardware memory block allocation pointer.
  gpu.DeviceBuffer? _deviceBuffer;

  /// The number of indices that are currently active and will be used for drawing.
  int _activeIndexCount = 0;

  /// The total number of indices that the buffer can currently hold.
  int _capacity = 0;

  /// The number of active indices for drawing.
  int get indexCount => _activeIndexCount;

  /// The client-side array that holds the index data before it's sent to the GPU.
  /// Uses Uint16List for maximum compatibility with mobile hardware.
  Uint16List? _indexData;

  /// Creates an index buffer wrapper.
  FskIndexBuffer();

  /// Ensures the underlying buffer has at least [newIndexCount] capacity and
  /// returns it.
  ///
  /// The buffer will grow if the requested count is larger than the current
  /// capacity. It will shrink if the requested count is less than half the
  /// current capacity to save memory.
  Uint16List? requestBuffer(int newIndexCount) {
    final bool needsToReallocate =
        newIndexCount > _capacity || (newIndexCount < _capacity / 2);

    if (needsToReallocate) {
      if (newIndexCount > 0) {
        _indexData = Uint16List(newIndexCount);
      } else {
        _indexData = null;
      }
      _capacity = newIndexCount;

      // Ensure the active count doesn't exceed the new, smaller capacity.
      if (_activeIndexCount > _capacity) {
        _activeIndexCount = _capacity;
      }
    }

    return _indexData;
  }

  /// Sets the number of active indices to be drawn.
  /// Call uploadData() after updating the contents of the buffer.
  void setActiveIndexCount(int count) {
    assert(count <= _capacity);
    _activeIndexCount = count;

    if (count == 0) {
      _deviceBuffer = null;
    }
  }

  /// Sends current CPU data over to physical GPU device memory.
  void uploadData() {
    if (_activeIndexCount == 0 || _indexData == null) {
      _deviceBuffer = null;
      return;
    }

    final int bytesPerElement = Uint16List.bytesPerElement;
    final int activeBytesSize = _activeIndexCount * bytesPerElement;
    
    // Use ByteData.view on the buffer for explicit byte-level control
    final ByteData view = _indexData!.buffer.asByteData(
      _indexData!.offsetInBytes,
      activeBytesSize,
    );

    // Create the hardware buffer in the gpu memory
    _deviceBuffer = gpu.gpuContext.createDeviceBufferWithCopy(view);
  }

  /// Clears the local data and the GPU buffer reference.
  void clear() {
    _deviceBuffer = null;
    _indexData = null;
    _activeIndexCount = 0;
    _capacity = 0;
  }

  /// Binds the index buffer into the active recording stream of a RenderPass.
  ///
  /// In flutter_gpu, binding is an operation performed explicitly on the transient
  /// RenderPass object, rather than mutating global WebGL state drivers.
  void bind(gpu.RenderPass renderPass, {int offsetInIndices = 0}) {
    if (_deviceBuffer == null) return;

    final int bytesPerElement = Uint16List.bytesPerElement;
    final int offsetInBytes = offsetInIndices * bytesPerElement;
    
    final gpu.BufferView view = gpu.BufferView(
      _deviceBuffer!,
      offsetInBytes: offsetInBytes,
      lengthInBytes: _deviceBuffer!.sizeInBytes - offsetInBytes,
    );

    // Bind index buffer and explicitly tell flutter_gpu that we are using 16-bit unsigned ints
    renderPass.bindIndexBuffer(view, gpu.IndexType.int16);
  }

  /// Draws the currently bound indices as triangles.
  ///
  /// Replaces global canvas state invocation rules with a direct pass execution pipeline script.
  void drawTrianglesIndexed(gpu.RenderPass renderPass, {int? count}) {
    final drawCount = count ?? _activeIndexCount;
    if (drawCount > 0) {
      // Executes an indexed draw call with the active index element count
      renderPass.drawIndexed(drawCount);
    }
  }

  /// Checks for value equality. Two [IndexBuffer] instances are considered equal
  /// if they manage the same underlying physical device allocation.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is FskIndexBuffer &&
              runtimeType == other.runtimeType &&
              _deviceBuffer == other._deviceBuffer;

  @override
  int get hashCode => _deviceBuffer.hashCode;
}
