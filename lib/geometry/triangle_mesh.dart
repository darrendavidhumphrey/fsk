import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math.dart'
    show Vector3, Triangle, Vector2, Aabb3;

/// A data class that stores the geometry for a collection of triangles.
///
/// It holds a flat list of interleaved vertex data (position, texture coordinate,
/// and normal) and provides methods for building and managing this data.
class TriangleMesh {
  // The number of float values that make up a single vertex's data.
  // 3 for position (x, y, z), 2 for texture coordinates (u, v), 3 for normal (nx, ny, nz).
  static const int componentCount = 8;

  // The offset in floats to the start of the texture coordinate data within a vertex.
  static const int texCoordOffset = 6;

  // The offset in floats to the start of the normal vector data within a vertex.
  static const int normalOffset = 3;

  final int triangleCount;

  /// The cached bounding box of the mesh. Null until first computed.
  Aabb3? _bounds;

  /// The raw, flat list of interleaved vertex data for all triangles.
  late final Float32List vertexData;

  /// Creates a mesh, pre-allocating space for a given number of triangles.
  TriangleMesh(this.triangleCount)
      : vertexData = Float32List(triangleCount * componentCount * 3);

  /// Creates an empty mesh with no allocated space.
  TriangleMesh.empty()
      : triangleCount = 0,
        vertexData = Float32List(0);

  /// Returns a new [Vector3] with the vertex position at the given [index].
  /// This method allocates a new object. For performance-critical code, consider
  /// using [getVertexInto] instead.
  Vector3 getVertex(int index) {
    final int j = index * componentCount;
    return Vector3(vertexData[j], vertexData[j + 1], vertexData[j + 2]);
  }

  /// Copies the vertex position at [index] into the provided [out] vector.
  /// This method does not allocate new memory and is faster in tight loops.
  void getVertexInto(int index, Vector3 out) {
    final int j = index * componentCount;
    out.setValues(vertexData[j], vertexData[j + 1], vertexData[j + 2]);
  }

  /// Returns a new [Vector3] with the normal vector at the given [index].
  /// This method allocates a new object. For performance-critical code, consider
  /// using [getNormalInto] instead.
  Vector3 getNormal(int index) {
    final int j = index * componentCount + normalOffset;
    return Vector3(vertexData[j], vertexData[j + 1], vertexData[j + 2]);
  }

  /// Copies the normal vector at [index] into the provided [out] vector.
  /// This method does not allocate new memory and is faster in tight loops.
  void getNormalInto(int index, Vector3 out) {
    final int j = index * componentCount + normalOffset;
    out.setValues(vertexData[j], vertexData[j + 1], vertexData[j + 2]);
  }

  /// Returns a new [Triangle] at the given [index].
  /// This method allocates a new object. For performance-critical code, consider
  /// using [getTriangleInto] instead.
  Triangle getTriangle(int index) {
    final int i = index * componentCount * 3;
    final int j = i + componentCount;
    final int k = j + componentCount;

    return Triangle.points(
        Vector3(vertexData[i], vertexData[i + 1], vertexData[i + 2]),
        Vector3(vertexData[j], vertexData[j + 1], vertexData[j + 2]),
        Vector3(vertexData[k], vertexData[k + 1], vertexData[k + 2]));
  }

  /// Copies the triangle at [index] into the provided [out] triangle.
  /// This method does not allocate new memory and is faster in tight loops.
  void getTriangleInto(int index, Triangle out) {
    final int i = index * componentCount * 3;
    final int j = i + componentCount;
    final int k = j + componentCount;
    out.point0.setValues(vertexData[i], vertexData[i + 1], vertexData[i + 2]);
    out.point1.setValues(vertexData[j], vertexData[j + 1], vertexData[j + 2]);
    out.point2.setValues(vertexData[k], vertexData[k + 1], vertexData[k + 2]);
  }

  /// Computes the AABB for the entire mesh by iterating directly through the
  /// raw vertex data for efficiency.
  Aabb3 _computeBounds() {
    if (triangleCount == 0) {
      return Aabb3();
    }

    // Initialize min and max with the first vertex's coordinates.
    final minV = Vector3(vertexData[0], vertexData[1], vertexData[2]);
    final maxV = Vector3(vertexData[0], vertexData[1], vertexData[2]);

    // Iterate through the rest of the vertices directly in the flat array.
    for (int i = componentCount; i < vertexData.length; i += componentCount) {
      final x = vertexData[i];
      final y = vertexData[i + 1];
      final z = vertexData[i + 2];

      minV.x = min(minV.x, x);
      minV.y = min(minV.y, y);
      minV.z = min(minV.z, z);
      maxV.x = max(maxV.x, x);
      maxV.y = max(maxV.y, y);
      maxV.z = max(maxV.z, z);
    }

    return Aabb3.minMax(minV, maxV);
  }

  /// Recomputes the bounding box. Should be called after modifying vertices.
  void recomputeBounds() {
    _bounds = _computeBounds();
  }

  /// Returns the cached bounding box, computing it if necessary.
  Aabb3 getBounds() {
    // Use the null-aware assignment operator to compute only on the first call.
    return _bounds ??= _computeBounds();
  }

  /// A low-level helper to write a single vertex's full attribute data into the
  /// flat [vertexData] array at a specific [vertexIndex].
  void _addVertex(
      int vertexIndex, Vector3 pos, Vector3 normal, Vector2 tex) {
    int meshIndex = vertexIndex * componentCount;
    vertexData[meshIndex++] = pos.x;
    vertexData[meshIndex++] = pos.y;
    vertexData[meshIndex++] = pos.z;
    vertexData[meshIndex++] = tex.x;
    vertexData[meshIndex++] = tex.y;
    vertexData[meshIndex++] = normal.x;
    vertexData[meshIndex++] = normal.y;
    vertexData[meshIndex++] = normal.z;
  }

  /// A low-level method to add a single triangle to the mesh data.
  ///
  /// This is intended to be used by geometry creation APIs like [MeshFactory].
  int addTriangle(Vector3 v0, Vector3 v1, Vector3 v2, Vector3 normal,
      List<Vector2> texCoord, int currentTriangle) {
    int vertexIndex = currentTriangle * 3;
    _addVertex(vertexIndex, v0, normal, texCoord[0]);
    _addVertex(vertexIndex + 1, v1, normal, texCoord[1]);
    _addVertex(vertexIndex + 2, v2, normal, texCoord[2]);
    return currentTriangle + 1;
  }
}
