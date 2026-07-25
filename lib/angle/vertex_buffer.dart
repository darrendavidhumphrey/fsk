import 'dart:typed_data';
import 'package:flutter_gpu/gpu.dart' as gpu;

/// Represents the possible components a vertex can have.
enum VertexComponent {
  position(3, 0, gpu.VertexFormat.float32x3),
  texCoord(2, 1, gpu.VertexFormat.float32x2),
  normal(3, 2, gpu.VertexFormat.float32x3),
  color(4, 3, gpu.VertexFormat.float32x4);

  final int size;
  final int attributeLocation;
  final gpu.VertexFormat format;

  const VertexComponent(this.size, this.attributeLocation, this.format);

  int get byteSize => size * Float32List.bytesPerElement;
}

/// A bitmask class for specifying which vertex components are enabled.
class VertexComponentFlags {
  static const int none = 0;
  static const int position = 1 << 0;
  static const int texCoord = 1 << 1;
  static const int normal = 1 << 2;
  static const int color = 1 << 3;

  static const int all = position | normal | texCoord | color;

  final int value;
  const VertexComponentFlags(this.value);

  bool contains(int other) => (value & other) == other;
  void debugPrint() {
    if (value == none) {
      print('VertexComponentFlags: [none]');
      return;
    }

    final List<String> activeFlags = [];

    // Evaluate each individual bit flag configuration sequentially
    if (contains(position)) activeFlags.add('position');
    if (contains(texCoord)) activeFlags.add('texCoord');
    if (contains(normal)) activeFlags.add('normal');
    if (contains(color)) activeFlags.add('color');

    print('VertexComponentFlags: [${activeFlags.join(', ')}] (Raw: $value)');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is VertexComponentFlags &&
              runtimeType == other.runtimeType &&
              value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Manages a flutter_gpu DeviceBuffer.
class VertexBuffer {
  gpu.DeviceBuffer? _deviceBuffer;

  final VertexComponentFlags enabledComponents;
  int _activeVertexCount = 0;
  int _capacity = 0;
  final int _stride;
  final int _componentCount;

  int get activeVertexCount => _activeVertexCount;
  int get capacity => _capacity;
  int get stride => _stride;
  int get componentCount => _componentCount;

  Float32List? vertexData;

  VertexBuffer({required this.enabledComponents})
      : _stride = _calculateStride(enabledComponents),
        _componentCount = _calculateComponentCount(enabledComponents);


  VertexBuffer.v3t2n3c4() : this(enabledComponents: const VertexComponentFlags(VertexComponentFlags.position | VertexComponentFlags.normal | VertexComponentFlags.texCoord | VertexComponentFlags.color));
  VertexBuffer.v3t2() : this(enabledComponents: const VertexComponentFlags(VertexComponentFlags.position | VertexComponentFlags.texCoord));
  VertexBuffer.v3t2n3() : this(enabledComponents: const VertexComponentFlags(VertexComponentFlags.position | VertexComponentFlags.normal | VertexComponentFlags.texCoord));

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

  static int _getFlagForComponent(VertexComponent component) {
    switch (component) {
      case VertexComponent.position: return VertexComponentFlags.position;
      case VertexComponent.texCoord: return VertexComponentFlags.texCoord;
      case VertexComponent.normal: return VertexComponentFlags.normal;
      case VertexComponent.color: return VertexComponentFlags.color;
    }
  }

  static int _calculateStride(VertexComponentFlags flags) {
    int calculatedStride = 0;
    for (var component in VertexComponent.values) {
      if (flags.contains(_getFlagForComponent(component))) {
        calculatedStride += component.byteSize;
      }
    }
    return calculatedStride;
  }

  static int _calculateComponentCount(VertexComponentFlags flags) {
    int count = 0;
    for (var component in VertexComponent.values) {
      if (flags.contains(_getFlagForComponent(component))) {
        count += component.size;
      }
    }
    return count;
  }
}