import 'dart:typed_data';
import 'package:vector_math/vector_math.dart' as vm;

import '../scene_graph/fsk_scene_object.dart';
import '../scene_graph/fsk_mesh.dart';
import '../scene_graph/fsk_indexed_mesh.dart';
import '../gpu/fsk_vertex_buffer.dart';

/// Modes for controlling hit test traversal and results.
enum FskHitTestMode {
  /// Stop at the first valid hit found.
  first,

  /// Search all objects and return only the single closest hit.
  closest,

  /// Return all hits found, sorted by distance (closest first).
  all,
}

/// A data class containing detailed information about a hit test intersection.
class FskHitDetails {
  /// The object that was hit.
  final FskSceneObject hitObject;

  /// The exact point of intersection in world space.
  final vm.Vector3 hitPoint;

  /// The exact point of intersection in the local coordinate space of [hitObject].
  final vm.Vector3 localHitPoint;

  /// The distance from the ray's origin to the hit point.
  final double distance;

  /// The surface normal at the hit point.
  final vm.Vector3 normal;

  /// Additional data appropriate to the object that was hit (e.g. triangle index).
  final dynamic hitData;

  FskHitDetails({
    required this.hitObject,
    required this.hitPoint,
    required this.localHitPoint,
    required this.distance,
    required this.normal,
    this.hitData,
  });
}

/// A utility class that provides static methods for ray-casting against meshes.
class MeshHitTester {
  /// Private constructor to prevent instantiation of this utility class.
  MeshHitTester._();

  /// Performs a ray-mesh intersection test against an [FskMesh].
  static List<FskHitDetails> intersectFskMesh(FskMesh mesh, vm.Ray ray,
      {FskHitTestMode mode = FskHitTestMode.closest, double epsilon = 1e-6}) {
    if (mesh.vertices == null) return [];
    return _intersectBuffer(
      mesh,
      mesh.vertices!,
      FskVertexBuffer.componentCount,
      null,
      ray,
      mode: mode,
      epsilon: epsilon,
    );
  }

  /// Performs a ray-mesh intersection test against an [FskIndexedMesh].
  static List<FskHitDetails> intersectFskIndexedMesh(
      FskIndexedMesh mesh, vm.Ray ray,
      {FskHitTestMode mode = FskHitTestMode.closest, double epsilon = 1e-6}) {
    if (mesh.vertices == null || mesh.indices == null) return [];
    return _intersectBuffer(
      mesh,
      mesh.vertices!,
      FskVertexBuffer.componentCount,
      mesh.indices!,
      ray,
      mode: mode,
      epsilon: epsilon,
    );
  }

  /// Internal helper to intersect a vertex buffer (optionally indexed).
  static List<FskHitDetails> _intersectBuffer(
    FskSceneObject hitObject,
    Float32List vertices,
    int stride,
    TypedData? indices,
    vm.Ray ray, {
    FskHitTestMode mode = FskHitTestMode.closest,
    double epsilon = 1e-6,
  }) {
    final List<FskHitDetails> hits = [];
    FskHitDetails? closestHit;

    final int count = indices != null
        ? (indices is Uint16List ? indices.length : (indices as Uint32List).length)
        : (vertices.length ~/ stride);

    for (int i = 0; i < count; i += 3) {
      final int i0, i1, i2;
      if (indices != null) {
        if (indices is Uint16List) {
          i0 = indices[i];
          i1 = indices[i + 1];
          i2 = indices[i + 2];
        } else {
          indices as Uint32List;
          i0 = indices[i];
          i1 = indices[i + 1];
          i2 = indices[i + 2];
        }
      } else {
        i0 = i;
        i1 = i + 1;
        i2 = i + 2;
      }

      final v0 = _getVertex(vertices, i0, stride);
      final v1 = _getVertex(vertices, i1, stride);
      final v2 = _getVertex(vertices, i2, stride);

      final hitPoint = _intersectRayTriangle(v0, v1, v2, ray, epsilon: epsilon);
      if (hitPoint != null) {
        final distance = ray.origin.distanceTo(hitPoint);
        final edge1 = v1 - v0;
        final edge2 = v2 - v0;
        final normal = edge1.cross(edge2)..normalize();

        final details = FskHitDetails(
          hitObject: hitObject,
          hitPoint: hitPoint,
          localHitPoint: hitPoint,
          distance: distance,
          normal: normal,
          hitData: i ~/ 3,
        );

        if (mode == FskHitTestMode.first) {
          return [details];
        }

        if (mode == FskHitTestMode.closest) {
          if (closestHit == null || distance < closestHit.distance) {
            closestHit = details;
          }
        } else {
          hits.add(details);
        }
      }
    }

    if (mode == FskHitTestMode.closest) {
      return closestHit != null ? [closestHit] : [];
    }

    if (mode == FskHitTestMode.all) {
      hits.sort((a, b) => a.distance.compareTo(b.distance));
    }

    return hits;
  }

  static vm.Vector3 _getVertex(Float32List vertices, int index, int stride) {
    final int base = index * stride;
    return vm.Vector3(vertices[base], vertices[base + 1], vertices[base + 2]);
  }

  static vm.Vector3? _intersectRayTriangle(
      vm.Vector3 p0, vm.Vector3 v1, vm.Vector3 v2, vm.Ray ray,
      {double epsilon = 1e-6}) {
    final edge1 = v1 - p0;
    final edge2 = v2 - p0;

    final h = ray.direction.cross(edge2);
    final a = edge1.dot(h);

    if (a > -epsilon && a < epsilon) return null;

    final f = 1.0 / a;
    final s = ray.origin - p0;
    final u = f * s.dot(h);

    if (u < 0.0 || u > 1.0) return null;

    final q = s.cross(edge1);
    final v = f * ray.direction.dot(q);

    if (v < 0.0 || u + v > 1.0) return null;

    final t = f * edge2.dot(q);

    if (t > epsilon) {
      return ray.origin + ray.direction * t;
    }
    return null;
  }
}
