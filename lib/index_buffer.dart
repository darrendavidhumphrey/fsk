import 'package:flutter_angle/flutter_angle.dart';
import 'native_array/index.dart';

/// Manages a WebGL Element Array Buffer, also known as an Index Buffer Object (IBO).
///
/// This class handles the creation, allocation, data transfer, and disposal of a
/// buffer used for indexed drawing with `gl.drawElements`.
class IndexBuffer {
  /// The underlying rendering context.
  final RenderingContext _gl;

  /// The WebGL identifier for the buffer object.
  final Buffer _iboId;

  /// The number of indices that are currently active and will be used for drawing.
  int _activeIndexCount = 0;

  /// The total number of indices that the buffer can currently hold.
  int _capacity = 0;

  /// The number of active indices for drawing.
  int get indexCount => _activeIndexCount;

  /// The client-side array that holds the index data before it's sent to the GPU.
  Int16Array? _indexData;

  /// Creates an index buffer for the given rendering context.
  IndexBuffer(this._gl) : _iboId = _gl.createBuffer();

  /// Ensures the underlying buffer has at least [newIndexCount] capacity and
  /// returns it.
  ///
  /// The buffer will grow if the requested count is larger than the current
  /// capacity. It will shrink if the requested count is less than half the
  /// current capacity to save memory.
  Int16Array? requestBuffer(int newIndexCount) {
    final bool needsToReallocate =
        newIndexCount > _capacity || (newIndexCount < _capacity / 2);

    if (needsToReallocate) {
      // Dispose the old buffer if it exists.
      _indexData?.dispose();

      if (newIndexCount > 0) {
        _indexData = Int16Array(newIndexCount);
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

  /// Disposes of all WebGL resources and the client-side buffer held by this object.
  void dispose() {
    _gl.deleteBuffer(_iboId);
    _indexData?.dispose();
    _indexData = null;
  }

  /// Updates the GPU buffer with the data from the local [Int16Array] and
  /// sets the number of active indices to be drawn.
  void setActiveIndexCount(int count) {
    assert(count <= _capacity);
    _activeIndexCount = count;

    if (count > 0 && _indexData != null) {
      _gl.bindBuffer(WebGL.ELEMENT_ARRAY_BUFFER, _iboId);
      _gl.bufferData(WebGL.ELEMENT_ARRAY_BUFFER, _indexData, WebGL.STATIC_DRAW);
      _gl.bindBuffer(WebGL.ELEMENT_ARRAY_BUFFER, null);
    }
  }

  /// Binds the index buffer to make it the active ELEMENT_ARRAY_BUFFER.
  void bind() {
    _gl.bindBuffer(WebGL.ELEMENT_ARRAY_BUFFER, _iboId);
  }

  /// Unbinds the index buffer by binding `null`.
  void unbind() {
    _gl.bindBuffer(WebGL.ELEMENT_ARRAY_BUFFER, null);
  }

  /// Checks for value equality. Two [IndexBuffer] instances are considered equal
  /// if they manage the same underlying WebGL buffer object.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndexBuffer &&
          runtimeType == other.runtimeType &&
          _iboId == other._iboId;

  /// Provides a hash code consistent with value equality.
  @override
  int get hashCode => _iboId.hashCode;
}
