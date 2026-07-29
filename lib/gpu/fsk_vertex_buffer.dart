import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';

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

  // The host buffer for the vertices
  Float32List? vertexData;

  // The number of vertices in vertexData
  int _vertexCount = 0;

  FskVertexBuffer();

  /// Sends current CPU data over to physical GPU device memory.
  void uploadData() {
    if ((_vertexCount == 0) || (vertexData == null)) return;

    final int activeBytesSize = _vertexCount * strideInBytes;

    final ByteData view = vertexData!.buffer.asByteData(
      vertexData!.offsetInBytes,
      activeBytesSize,
    );

    _deviceBuffer = gpu.gpuContext.createDeviceBufferWithCopy(view);
  }

  void clear() {
    _deviceBuffer = null;
    vertexData = null;
    _vertexCount = 0;
  }

  /// Allocate host CPU memory arrays to store structural coordinates.
  Float32List? requestBuffer(int newVertexCount) {

    if (newVertexCount == 0) {
      clear();
      return null;
    }

    if (newVertexCount != _vertexCount) {
      vertexData = Float32List(newVertexCount * componentCount);
      _vertexCount = newVertexCount;
    }
    return vertexData;
  }

  /// Records buffer bindings to a specific binding slot on an active RenderPass.
  void bind(gpu.RenderPass renderPass, {int slot = 0}) {
    if (_deviceBuffer == null) return;
    assert(
      _deviceBuffer != null,
      "FskVertexBuffer::bind called with null device buffer",
    );

    final gpu.BufferView view = gpu.BufferView(
      _deviceBuffer!,
      offsetInBytes: 0,
      lengthInBytes: _deviceBuffer!.sizeInBytes,
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

  void dispose() {
    _deviceBuffer = null;
    vertexData = null;
  }

  int addV3T2(int index, double x, double y, double z, double u, double v) {
    const int padding =
        componentCount - 5; // Storing first 5 components per vertex
    vertexData![index++] = x;
    vertexData![index++] = y;
    vertexData![index++] = z;
    vertexData![index++] = u;
    vertexData![index++] = v;
    index += padding;
    return index;
  }

  bool setFromQuads(List<Quad> quads, List<Rect> textureQuads) {
    if (quads.isEmpty ||
        textureQuads.isEmpty ||
        quads.length != textureQuads.length) {
      clear();
      return false;
    }

    // Create two triangles per quad, so six vertices per quad
    requestBuffer(6 * quads.length);
    if (vertexData == null) {
      clear();
      return false;
    }

    int index = 0;
    for (int i = 0; i < quads.length; i++) {
      final q = quads[i];
      final tr = textureQuads[i];

      // First triangle: bottom-left, bottom-right, top-right
      index = addV3T2(
        index,
        q.point0.x,
        q.point0.y,
        q.point0.z,
        tr.left,
        tr.bottom,
      );
      index = addV3T2(
        index,
        q.point1.x,
        q.point1.y,
        q.point1.z,
        tr.right,
        tr.bottom,
      );
      index = addV3T2(
        index,
        q.point2.x,
        q.point2.y,
        q.point2.z,
        tr.right,
        tr.top,
      );

      // Second triangle: bottom-left, top-right, top-left
      index = addV3T2(
        index,
        q.point0.x,
        q.point0.y,
        q.point0.z,
        tr.left,
        tr.bottom,
      );
      index = addV3T2(
        index,
        q.point2.x,
        q.point2.y,
        q.point2.z,
        tr.right,
        tr.top,
      );
      index = addV3T2(
        index,
        q.point3.x,
        q.point3.y,
        q.point3.z,
        tr.left,
        tr.top,
      );
    }

    return true;
  }

  bool setFromUnrolledQuads(int numQuads, Float32List xyzuv) {
    const int arrayStride = 5; // Unrolled array is 5 components per vertex (XYZUV)

    // Guard that array length is correct
    if ((numQuads == 0) || xyzuv.isEmpty || xyzuv.length != arrayStride * numQuads*4) {
      clear();
      return false;
    }

    final int numQuadVerts = 6 * numQuads; // Two triangles per quad
    requestBuffer(numQuadVerts);

    if (vertexData == null) {
      clear();
      return false;
    }

    int currentVboIndex = 0;
    for (int i = 0; i < numQuads; i++) {
      // Calculate array indices for this quad
      int v0Index = (i * arrayStride*4);
      int v1Index = v0Index + arrayStride;
      int v2Index = v1Index + arrayStride;
      int v3Index = v2Index + arrayStride;

      // Calculate texture indices for this quad
      int blIndex = v0Index + 3;
      int brIndex = v1Index + 3;
      int trIndex = v2Index + 3;
      int tlIndex = v3Index + 3;

      // First triangle: bottom-left, bottom-right, top-right
      currentVboIndex = addV3T2(
        currentVboIndex,
        xyzuv[v0Index],
        xyzuv[v0Index + 1],
        xyzuv[v0Index + 2],
        xyzuv[blIndex],
        xyzuv[blIndex + 1],
      );
      currentVboIndex = addV3T2(
        currentVboIndex,
        xyzuv[v1Index],
        xyzuv[v1Index + 1],
        xyzuv[v1Index + 2],
        xyzuv[brIndex],
        xyzuv[brIndex + 1],
      );
      currentVboIndex = addV3T2(
        currentVboIndex,
        xyzuv[v2Index],
        xyzuv[v2Index + 1],
        xyzuv[v2Index + 2],
        xyzuv[trIndex],
        xyzuv[trIndex + 1],
      );

      // Second triangle: bottom-left, top-right, top-left
      currentVboIndex = addV3T2(
        currentVboIndex,
        xyzuv[v0Index],
        xyzuv[v0Index + 1],
        xyzuv[v0Index + 2],
        xyzuv[blIndex],
        xyzuv[blIndex + 1],
      );
      currentVboIndex = addV3T2(
        currentVboIndex,
        xyzuv[v2Index],
        xyzuv[v2Index + 1],
        xyzuv[v2Index + 2],
        xyzuv[trIndex],
        xyzuv[trIndex + 1],
      );
      currentVboIndex = addV3T2(
        currentVboIndex,
        xyzuv[v3Index],
        xyzuv[v3Index + 1],
        xyzuv[v3Index + 2],
        xyzuv[tlIndex],
        xyzuv[tlIndex + 1],
      );
    }
    return true;
  }
}
