import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';
import 'polyline.dart';
/// Represents one edge of the convex clipping polygon, defined by a point on the
/// edge and an inward-pointing normal vector.
class ClipEdge {
  final Vector2 normal;
  final Vector2 pointOnEdge;

  ClipEdge(this.normal, this.pointOnEdge);
}

/// A class that clips a [Polyline] against a rectangular boundary using the
/// Sutherland-Hodgman algorithm.
class PolylineClipper {
  final List<ClipEdge> clipEdges;
  final double left, bottom, right, top;
  static const double _epsilon = 1e-6;

  static List<ClipEdge> _precomputeClipEdgesFromRect(
    double left, double top, double right, double bottom) {
    return [
      ClipEdge(Vector2(1, 0), Vector2(left, top)),
      ClipEdge(Vector2(-1, 0), Vector2(right, top)),
      ClipEdge(Vector2(0, -1), Vector2(left, top)),
      ClipEdge(Vector2(0, 1), Vector2(left, bottom)),
    ];
  }

  /// Clips an input polygon (a flat list of vertex data) against a single edge.
  /// This method is optimized to avoid allocations in its inner loop.
  Float32List _clipAgainstEdge(Float32List vertices, ClipEdge edge) {
    if (vertices.isEmpty) return Float32List(0);

    final outputBuffer = Float32List(vertices.length * 2);
    int outputComponentCount = 0;

    double sX = vertices[vertices.length - 3];
    double sY = vertices[vertices.length - 2];
    double sZ = vertices[vertices.length - 1];

    for (int i = 0; i < vertices.length; i += 3) {
      final pX = vertices[i];
      final pY = vertices[i + 1];
      final pZ = vertices[i + 2];

      final bool sInside = (edge.normal.x * (sX - edge.pointOnEdge.x) + edge.normal.y * (sY - edge.pointOnEdge.y)) >= 0;
      final bool pInside = (edge.normal.x * (pX - edge.pointOnEdge.x) + edge.normal.y * (pY - edge.pointOnEdge.y)) >= 0;

      if (sInside && pInside) {
        outputBuffer[outputComponentCount++] = pX;
        outputBuffer[outputComponentCount++] = pY;
        outputBuffer[outputComponentCount++] = pZ;
      } else if (sInside && !pInside) {
        _getIntersection(outputBuffer, outputComponentCount, sX, sY, sZ, pX, pY, pZ, edge);
        outputComponentCount += 3;
      } else if (!sInside && pInside) {
        _getIntersection(outputBuffer, outputComponentCount, sX, sY, sZ, pX, pY, pZ, edge);
        outputComponentCount += 3;
        outputBuffer[outputComponentCount++] = pX;
        outputBuffer[outputComponentCount++] = pY;
        outputBuffer[outputComponentCount++] = pZ;
      }
      
      sX = pX;
      sY = pY;
      sZ = pZ;
    }
    return Float32List.sublistView(outputBuffer, 0, outputComponentCount);
  }

  /// Calculates the intersection and writes it directly into the output buffer.
  void _getIntersection(
      Float32List outputBuffer, int writeIndex,
      double sX, double sY, double sZ, 
      double pX, double pY, double pZ, 
      ClipEdge edge) {
    final dX = pX - sX;
    final dY = pY - sY;
    final dZ = pZ - sZ;

    final denominator = edge.normal.x * dX + edge.normal.y * dY;
    if (denominator.abs() < _epsilon) {
      outputBuffer[writeIndex] = sX;
      outputBuffer[writeIndex + 1] = sY;
      outputBuffer[writeIndex + 2] = sZ;
      return;
    }

    final t = -(edge.normal.x * (sX - edge.pointOnEdge.x) + edge.normal.y * (sY - edge.pointOnEdge.y)) / denominator;
    
    outputBuffer[writeIndex] = sX + dX * t;
    outputBuffer[writeIndex + 1] = sY + dY * t;
    outputBuffer[writeIndex + 2] = sZ + dZ * t;
  }

  /// Cleans the final list of vertices by removing duplicates and creates a Polyline.
  Polyline? _cleanAndCreatePolyline(Float32List vertices) {
    if (vertices.length < 9) return null; // Fewer than 3 vertices

    final uniqueVerticesBuffer = Float32List(vertices.length);
    int uniqueVertexComponentCount = 0;
    final double epsilonSq = _epsilon * _epsilon;

    if (vertices.isNotEmpty) {
      uniqueVerticesBuffer[0] = vertices[0];
      uniqueVerticesBuffer[1] = vertices[1];
      uniqueVerticesBuffer[2] = vertices[2];
      uniqueVertexComponentCount = 3;

      for (int i = 3; i < vertices.length; i += 3) {
        final lastVx = uniqueVerticesBuffer[uniqueVertexComponentCount - 3];
        final lastVy = uniqueVerticesBuffer[uniqueVertexComponentCount - 2];
        final currentVx = vertices[i];
        final currentVy = vertices[i + 1];

        final dx = currentVx - lastVx;
        final dy = currentVy - lastVy;

        if ((dx * dx + dy * dy) > epsilonSq) {
          uniqueVerticesBuffer[uniqueVertexComponentCount++] = vertices[i];
          uniqueVerticesBuffer[uniqueVertexComponentCount++] = vertices[i + 1];
          uniqueVerticesBuffer[uniqueVertexComponentCount++] = vertices[i + 2];
        }
      }
    }

    if (uniqueVertexComponentCount > 3) {
      final lastVx = uniqueVerticesBuffer[uniqueVertexComponentCount - 3];
      final lastVy = uniqueVerticesBuffer[uniqueVertexComponentCount - 2];
      final firstVx = uniqueVerticesBuffer[0];
      final firstVy = uniqueVerticesBuffer[1];

      final dx = firstVx - lastVx;
      final dy = firstVy - lastVy;

      if ((dx * dx + dy * dy) < epsilonSq) {
        uniqueVertexComponentCount -= 3;
      }
    }

    if (uniqueVertexComponentCount < 9) return null;

    final finalVertices = Float32List.sublistView(
        uniqueVerticesBuffer, 0, uniqueVertexComponentCount);

    return Polyline.fromFloat32List(finalVertices);
  }

  Polyline? clip(Polyline polyline) {
    if (polyline.length < 3) return null;

    final polyBounds = polyline.getBounds2D();
    if (polyBounds.max.x < left ||
        polyBounds.min.x > right ||
        polyBounds.max.y < bottom ||
        polyBounds.min.y > top) {
      return null;
    }

    if (polyBounds.min.x >= left &&
        polyBounds.max.x <= right &&
        polyBounds.min.y >= bottom &&
        polyBounds.max.y <= top) {
      return polyline;
    }

    Float32List clippedVertices = Float32List.fromList(polyline.vertices);

    for (final edge in clipEdges) {
      clippedVertices = _clipAgainstEdge(clippedVertices, edge);
    }

    return _cleanAndCreatePolyline(clippedVertices);
  }

  PolylineClipper({
    required this.left,
    required this.bottom,
    required this.right,
    required this.top,
  }) : clipEdges = _precomputeClipEdgesFromRect(left, top, right, bottom);
}
