import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/shaders/shaders.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import 'float32_array_filler.dart';
import 'native_array/index.dart';

/// Represents the possible components a vertex can have.
///
/// Each component is associated with a specific, constant OpenGL attribute location
/// to ensure a stable contract between the client code and the GLSL shaders.
enum VertexComponent {
  position(3, ShaderList.v3Attrib, 0), // Location 0, 3 floats
  normal(3, ShaderList.n3Attrib, 1), // Location 1, 3 floats
  texCoord(2, ShaderList.t2Attrib, 2), // Location 2, 2 floats
  color(4, ShaderList.c4Attrib, 3); // Location 3, 4 floats (RGBA)

  /// The number of float components (e.g., 3 for a vec3).
  final int size;

  /// The name of the corresponding attribute in the GLSL shader source.
  final String shaderAttributeName;

  /// The fixed layout location for this vertex attribute in the shader.
  final int attributeLocation;

  const VertexComponent(
      this.size, this.shaderAttributeName, this.attributeLocation);

  /// Get the total size in bytes for this component.
  int get byteSize => size * Float32List.bytesPerElement;
}

/// A bitmask class for specifying which vertex components are enabled for a
/// [VertexBuffer].
///
/// This allows combining multiple components using bitwise OR operations.
class VertexComponentFlags {
  static const int none = 0;
  static const int position = 1 << 0;
  static const int normal = 1 << 1;
  static const int texCoord = 1 << 2;
  static const int color = 1 << 3;

  static const int all = position | normal | texCoord | color;


  final int value;

  const VertexComponentFlags(this.value);

  /// Checks if this flag set contains all the flags from another set.
  bool contains(int other) {
    return (value & other) == other;
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

/// Manages a WebGL Array Buffer, also known as a Vertex Buffer Object (VBO).
///
/// This class handles the creation, allocation, data transfer, and disposal of a
/// buffer used to supply vertex data to a shader program.
class VertexBuffer {
  /// The underlying rendering context.
  final RenderingContext _gl;

  /// The WebGL identifier for the buffer object.
  final Buffer _vboId;

  /// A bitmask defining the vertex layout for this buffer.
  final VertexComponentFlags enabledComponents;

  /// The number of vertices that are currently active and will be drawn.
  int _activeVertexCount = 0;

  /// The total number of vertices that the buffer can currently hold.
  int _capacity = 0;

  /// The total size in bytes for a single vertex.
  final int _stride;

  /// The number of float components for a single vertex.
  final int _componentCount;

  /// The number of active vertices to be drawn.
  int get activeVertexCount => _activeVertexCount;

  /// The current maximum number of vertices the buffer can hold.
  int get capacity => _capacity;

  /// The byte offset between consecutive vertices.
  int get stride => _stride;

  /// The number of float values per vertex.
  int get componentCount => _componentCount;

  /// The client-side array that holds the vertex data before it's sent to the GPU.
  Float32Array? vertexData;

  /// Creates a vertex buffer with a specific vertex layout.
  VertexBuffer(this._gl, {required this.enabledComponents})
      : _vboId = _gl.createBuffer(),
        _stride = _calculateStride(enabledComponents),
        _componentCount = _calculateComponentCount(enabledComponents);


  /// A convenience constructor for a buffer with position and color (V3C4).
  VertexBuffer.v3c4(RenderingContext gl)
      : this(gl,
            enabledComponents: const VertexComponentFlags(
              VertexComponentFlags.position | VertexComponentFlags.color,
            ));

  /// A convenience constructor for a buffer with position and texture coords (V3T2).
  VertexBuffer.v3t2(RenderingContext gl)
      : this(gl,
            enabledComponents: const VertexComponentFlags(
              VertexComponentFlags.position | VertexComponentFlags.texCoord,
            ));

  /// A convenience constructor for a buffer with position and normals (V3N3).
  VertexBuffer.v3n3(RenderingContext gl)
      : this(gl,
            enabledComponents: const VertexComponentFlags(
              VertexComponentFlags.position | VertexComponentFlags.normal,
            ));

  /// A convenience constructor for a buffer with position, texture coords, and normals (V3T2N3).
  VertexBuffer.v3t2n3(RenderingContext gl)
      : this(gl,
            enabledComponents: const VertexComponentFlags(
              VertexComponentFlags.position |
                  VertexComponentFlags.normal |
                  VertexComponentFlags.texCoord
            ));

/* TODO: Add back in
  VertexBuffer.all(RenderingContext gl)
      : this(gl,
      enabledComponents: const VertexComponentFlags(
          VertexComponentFlags.all
      ));

 */
  /// Updates the GPU buffer with the data from the local [Float32Array] and
  /// sets the number of active vertices to be drawn.
  void setActiveVertexCount(int count) {
    assert(count <= _capacity);
    _activeVertexCount = count;

    if ((_activeVertexCount > 0) && (vertexData != null)) {
      _gl.bindBuffer(WebGL.ARRAY_BUFFER, _vboId);
      _gl.bufferData(WebGL.ARRAY_BUFFER, vertexData!.toList(), WebGL.STATIC_DRAW);
    }
  }

  /// Ensures the underlying buffer has at least [newVertexCount] capacity and returns it.
  Float32Array? requestBuffer(int newVertexCount) {
    final bool needsReallocation =
        newVertexCount > _capacity || (newVertexCount < _capacity / 2);

    if (needsReallocation) {
      vertexData?.dispose();
      vertexData = newVertexCount > 0
          ? Float32Array(newVertexCount * _componentCount)
          : null;
      _capacity = newVertexCount;

      if (_activeVertexCount > _capacity) {
        _activeVertexCount = _capacity;
      }
    }

    return vertexData;
  }

  /// Disposes of all WebGL resources and the client-side buffer held by this object.
  void dispose() {
    _gl.deleteBuffer(_vboId);
    vertexData?.dispose();
    vertexData = null;
  }

  // TODO: Possibly obsolete if buffers always have all components
  /// Calculates the stride in bytes for a vertex with the given [flags].
  static int _calculateStride(VertexComponentFlags flags) {
    int calculatedStride = 0;
    if (flags.contains(VertexComponentFlags.position)) {
      calculatedStride += VertexComponent.position.byteSize;
    }
    if (flags.contains(VertexComponentFlags.normal)) {
      calculatedStride += VertexComponent.normal.byteSize;
    }
    if (flags.contains(VertexComponentFlags.texCoord)) {
      calculatedStride += VertexComponent.texCoord.byteSize;
    }
    if (flags.contains(VertexComponentFlags.color)) {
      calculatedStride += VertexComponent.color.byteSize;
    }
    return calculatedStride;
  }

  /// Calculates the total number of float components for a vertex with the given [flags].
  static int _calculateComponentCount(VertexComponentFlags flags) {
    int count = 0;
    if (flags.contains(VertexComponentFlags.position)) {
      count += VertexComponent.position.size;
    }
    if (flags.contains(VertexComponentFlags.normal)) {
      count += VertexComponent.normal.size;
    }
    if (flags.contains(VertexComponentFlags.texCoord)) {
      count += VertexComponent.texCoord.size;
    }
    if (flags.contains(VertexComponentFlags.color)) {
      count += VertexComponent.color.size;
    }
    return count;
  }

  void disableAllVertexAttributes() {
    if (kIsWeb) {
      // Query the browser's hardware limit for attributes (typically 16)
      int maxAttributes = 16; // TODO: HACK for  _gl.getParameter(_gl.GL_MAX_VERTEX_ATTRIBS);

      // Loop through every possible slot and turn it off
      for (int i = 0; i < maxAttributes; i++) {
        _gl.disableVertexAttribArray(i);
      }
    }
  }

  /// Configures the vertex attribute pointers for the enabled components.
  void enableComponents() {
    int offset = 0;
    disableAllVertexAttributes();
    if (enabledComponents.contains(VertexComponentFlags.position)) {
      final comp = VertexComponent.position;
      _gl.enableVertexAttribArray(comp.attributeLocation);
      _gl.vertexAttribPointer(
        comp.attributeLocation,
        comp.size,
        WebGL.FLOAT,
        false,
        _stride,
        offset,
      );
      offset += comp.byteSize;
    }

    if (enabledComponents.contains(VertexComponentFlags.normal)) {
      final comp = VertexComponent.normal;
      _gl.enableVertexAttribArray(comp.attributeLocation);
      _gl.vertexAttribPointer(
        comp.attributeLocation,
        comp.size,
        WebGL.FLOAT,
        false,
        _stride,
        offset,
      );
      offset += comp.byteSize;
    }

    if (enabledComponents.contains(VertexComponentFlags.texCoord)) {
      final comp = VertexComponent.texCoord;
      _gl.enableVertexAttribArray(comp.attributeLocation);
      _gl.vertexAttribPointer(
        comp.attributeLocation,
        comp.size,
        WebGL.FLOAT,
        false,
        _stride,
        offset,
      );
      offset += comp.byteSize;
    }

    if (enabledComponents.contains(VertexComponentFlags.color)) {
      final comp = VertexComponent.color;
      _gl.enableVertexAttribArray(comp.attributeLocation);
      _gl.vertexAttribPointer(
        comp.attributeLocation,
        comp.size,
        WebGL.FLOAT,
        false,
        _stride,
        offset,
      );
      offset += comp.byteSize;
    }
  }

  /// Disables the vertex attribute arrays for the enabled components.
  void disableComponents() {
    if (enabledComponents.contains(VertexComponentFlags.position)) {
      _gl.disableVertexAttribArray(VertexComponent.position.attributeLocation);
    }
    if (enabledComponents.contains(VertexComponentFlags.normal)) {
      _gl.disableVertexAttribArray(VertexComponent.normal.attributeLocation);
    }
    if (enabledComponents.contains(VertexComponentFlags.texCoord)) {
      _gl.disableVertexAttribArray(VertexComponent.texCoord.attributeLocation);
    }
    if (enabledComponents.contains(VertexComponentFlags.color)) {
      _gl.disableVertexAttribArray(VertexComponent.color.attributeLocation);
    }
  }

  /// Fills the buffer with six vertices to form a textured quad.
  void makeTexturedUnitQuad(Rect r, double z) {
    int newVertexCount = 6;

    Float32Array vertTextureArray = requestBuffer(newVertexCount)!;
    Float32ArrayFiller filler = Float32ArrayFiller(vertTextureArray);

    Rect tr = Rect.fromLTWH(0, 0, 1, 1);

    Quad q = Quad.points(
      Vector3(r.left, r.bottom, z),
      Vector3(r.right, r.bottom, z),
      Vector3(r.right, r.top, z),
      Vector3(r.left, r.top, z),
    );

    filler.addTexturedQuad(q, tr);
    setActiveVertexCount(newVertexCount);
  }

  /// Binds this buffer to the `ARRAY_BUFFER` target.
  /// but does NOT enable the vertex components.
  void bindVbo() {
    _gl.bindBuffer(WebGL.ARRAY_BUFFER, _vboId);
  }

  /// Binds the Vertex Buffer, enables the vertex components for drawing, and
  /// sets the active texture unit.
  void bind() {
    _gl.bindBuffer(WebGL.ARRAY_BUFFER, _vboId);
    enableComponents();
    _gl.activeTexture(WebGL.TEXTURE0);
  }

  /// Disables the vertex components after drawing.
  void unbind() {
    disableComponents();
  }

  /// Draws the currently active vertices as triangles.
  void drawTriangles() {
    if (activeVertexCount > 0) {
      _gl.drawArrays(WebGL.TRIANGLES, 0, activeVertexCount);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VertexBuffer &&
          runtimeType == other.runtimeType &&
          _vboId == other._vboId &&
          enabledComponents == other.enabledComponents;

  @override
  int get hashCode => Object.hash(_vboId, enabledComponents);
}
