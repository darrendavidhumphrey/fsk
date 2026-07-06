import 'package:flutter/foundation.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/fsk.dart';

/// Represents the possible components a vertex can have.
enum VertexComponent {
  position(3, GlslShader.v3Attrib, 0), // Location 0, 3 floats
  texCoord(2, GlslShader.t2Attrib, 1), // Location 1, 2 floats
  normal(3, GlslShader.n3Attrib, 2),   // Location 2, 3 floats
  color(4, GlslShader.c4Attrib, 3);    // Location 3, 4 floats (RGBA)

  final int size;
  final String shaderAttributeName;
  final int attributeLocation;

  const VertexComponent(
      this.size, this.shaderAttributeName, this.attributeLocation);

  int get byteSize => size * Float32List.bytesPerElement;
}

/// A bitmask class for specifying which vertex components are enabled.
class VertexComponentFlags {
  static const int none = 0;
  static const int position = 1 << 0;
  static const int texCoord = 1 << 1; // Fixed bit order to match enum
  static const int normal = 1 << 2;   // Fixed bit order to match enum
  static const int color = 1 << 3;

  static const int all = position | normal | texCoord | color;

  final int value;
  const VertexComponentFlags(this.value);

  bool contains(int other) => (value & other) == other;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is VertexComponentFlags &&
              runtimeType == other.runtimeType &&
              value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Manages a WebGL Array Buffer / Vertex Buffer Object (VBO).
class VertexBuffer with LoggableClass {
  late GlStateManager _gls;
  late Buffer _vboId;
  bool _initialized = false;

  final VertexComponentFlags enabledComponents;
  int _activeVertexCount = 0;
  int _capacity = 0;
  final int _stride;
  final int _componentCount;

  int get activeVertexCount => _activeVertexCount;
  int get capacity => _capacity;
  int get stride => _stride;
  int get componentCount => _componentCount;

  Float32Array? vertexData;

  VertexBuffer({required this.enabledComponents})
      : _stride = _calculateStride(enabledComponents),
        _componentCount = _calculateComponentCount(enabledComponents);

  void init(GlStateManager gls) {
    _gls = gls;
    _vboId = _gls.gl.createBuffer();
    _initialized = true;
  }

  // Convenience constructors
  VertexBuffer.v3t2n3c4() : this(enabledComponents: const VertexComponentFlags(VertexComponentFlags.position | VertexComponentFlags.normal | VertexComponentFlags.texCoord | VertexComponentFlags.color));
  VertexBuffer.v3t2() : this(enabledComponents: const VertexComponentFlags(VertexComponentFlags.position | VertexComponentFlags.texCoord));
  VertexBuffer.v3t2n3() : this(enabledComponents: const VertexComponentFlags(VertexComponentFlags.position | VertexComponentFlags.normal | VertexComponentFlags.texCoord));

  /// Sets the active vertex count and automatically uploads the buffer data.
  void setActiveVertexCount(int count) {
    _activeVertexCount = count; // Fixed: update count before running checks
    uploadData();
  }

  /// Sends the current CPU-side memory over to the GPU VBO.
  void uploadData() {
    if (_initialized  && _activeVertexCount > 0 && vertexData != null) {
      _gls.bindVertexBuffer(_vboId);
      _gls.bufferData(WebGL.ARRAY_BUFFER, vertexData, WebGL.STATIC_DRAW);
      _gls.bindVertexBuffer(null);
    }
  }

  /// Allocates CPU memory to hold up to [newVertexCount] elements.
  Float32Array? requestBuffer(int newVertexCount) {
    final bool needsReallocation = newVertexCount > _capacity || (newVertexCount < _capacity / 2);

    if (needsReallocation) {
      vertexData?.dispose();
      vertexData = newVertexCount > 0 ? Float32Array(newVertexCount * _componentCount) : null;
      _capacity = newVertexCount;

      if (_activeVertexCount > _capacity) {
        _activeVertexCount = _capacity;
      }
    }
    return vertexData;
  }

  /// Binds the VBO and sets up layout pointers matching shader attributes layout locations.
  void bind() {
    if (!_initialized) return;

    _gls.bindVertexBuffer(_vboId);

    int currentOffset = 0;

    // Setup matching the exact iteration order of VertexComponent entries
    for (var component in VertexComponent.values) {
      int bitFlag = _getFlagForComponent(component);

      if (enabledComponents.contains(bitFlag)) {
        int loc = component.attributeLocation;
        _gls.enableVertexAttribArray(loc);
        _gls.vertexAttribPointer(
          loc,
          component.size,
          WebGL.FLOAT,
          false,
          _stride,
          currentOffset,
        );
        currentOffset += component.byteSize;
      }
    }
  }

  void unbind() {
    if (!_initialized) return;
    _gls.bindVertexBuffer(null);
  }

  void dispose() {
    if (_initialized) {
      _gls.deleteBuffer(_vboId);
    }
    vertexData?.dispose();
    vertexData = null;
  }

  /// Maps VertexComponent entries cleanly to bitmasks.
  static int _getFlagForComponent(VertexComponent component) {
    switch (component) {
      case VertexComponent.position: return VertexComponentFlags.position;
      case VertexComponent.texCoord: return VertexComponentFlags.texCoord;
      case VertexComponent.normal: return VertexComponentFlags.normal;
      case VertexComponent.color: return VertexComponentFlags.color;
    }
  }

  /// Iterates values in enum declaration order to guarantee correct calculations.
  static int _calculateStride(VertexComponentFlags flags) {
    int calculatedStride = 0;
    for (var component in VertexComponent.values) {
      if (flags.contains(_getFlagForComponent(component))) {
        calculatedStride += component.byteSize;
      }
    }
    return calculatedStride;
  }

  /// Iterates values in enum declaration order to guarantee correct calculations.
  static int _calculateComponentCount(VertexComponentFlags flags) {
    int count = 0;
    for (var component in VertexComponent.values) {
      if (flags.contains(_getFlagForComponent(component))) {
        count += component.size;
      }
    }
    return count;
  }

  /// Draws the currently active vertices as triangles.
  void drawTriangles() {
    if (activeVertexCount > 0) {
      _gls.gl.drawArrays(WebGL.TRIANGLES, 0, activeVertexCount);
    }
  }
}
