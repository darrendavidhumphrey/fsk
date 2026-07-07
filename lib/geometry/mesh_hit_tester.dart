import 'triangle_mesh.dart';
import 'package:vector_math/vector_math_64.dart';

/// A data class containing detailed information about a ray-mesh intersection.
class TriangleMeshHitDetails {
  /// The mesh that was hit.
  final TriangleMesh mesh;

  /// The exact point of intersection in 3D space.
  final Vector3 hitPoint;

  /// The index of the triangle within the mesh that was hit.
  final int triangleIndex;

  /// The distance from the ray's origin to the hit point.
  final double distance;

  /// The surface normal of the triangle that was hit.
  /// This is calculated on creation from the hit mesh and triangle index.
  late final Vector3 normal;

  /// Creates an object holding the details of a ray-mesh intersection.
  TriangleMeshHitDetails(
      this.mesh, this.hitPoint, this.triangleIndex, this.distance) {
    normal = mesh.getNormal(triangleIndex);
  }
}

/// A utility class that provides static methods for ray-casting against a [TriangleMesh].
class MeshHitTester {
  /// Private constructor to prevent instantiation of this utility class.
  MeshHitTester._();

  /// Performs a ray-mesh intersection test.
  ///
  /// Returns [TriangleMeshHitDetails] if an intersection occurs, otherwise `null`.
  /// This test first performs a cheap check against the mesh's overall bounding
  /// box. If the ray misses the box, the test exits early. Otherwise, it proceeds
  /// to check every triangle in the mesh to find the closest intersection point.
  static TriangleMeshHitDetails? intersect(TriangleMesh mesh, Ray ray,
      {double epsilon = 1e-6}) {
    // First, perform a cheap check against the overall bounding box.
    double? intersection = ray.intersectsWithAabb3(mesh.getBounds());
    if (intersection == null || intersection < 0) {
      return null;
    }

    double? closestDistance;
    int? closestTriangleIndex;

    // If the ray hits the box, check each triangle for the closest intersection.
    for (int i = 0; i < mesh.triangleCount; i++) {
      Vector3? hit = _rayTriangleIntersect(mesh, i, ray, epsilon: epsilon);
      if (hit != null) {
        final distance = ray.origin.distanceTo(hit);
        if (closestDistance == null || distance < closestDistance) {
          closestDistance = distance;
          closestTriangleIndex = i;
        }
      }
    }

    if (closestTriangleIndex != null) {
      final hitPoint = ray.origin + ray.direction * closestDistance!;
      return TriangleMeshHitDetails(
          mesh, hitPoint, closestTriangleIndex, closestDistance);
    }

    return null;
  }

  /// Performs a ray-triangle intersection using the Möller–Trumbore algorithm.
  ///
  /// This is a low-level, high-performance test for a single triangle.
  /// Returns the intersection point as a [Vector3], or `null` if there is no hit.
  static Vector3? _rayTriangleIntersect(
      TriangleMesh mesh, int triangleIndex, Ray ray,
      {double epsilon = 1e-6}) {
    final int vertexIndex = triangleIndex * 3;
    final point0 = mesh.getVertex(vertexIndex);
    final edge1 = mesh.getVertex(vertexIndex + 1) - point0;
    final edge2 = mesh.getVertex(vertexIndex + 2) - point0;

    // Begin calculating determinant - also used to calculate u parameter
    final h = ray.direction.cross(edge2);
    // if determinant is near zero, ray lies in plane of triangle
    final a = edge1.dot(h);

    if (a > -epsilon && a < epsilon) {
      return null; // Ray is parallel to the triangle.
    }

    final f = 1.0 / a;
    final s = ray.origin - point0;

    // Calculate u parameter and test bounds
    final u = f * s.dot(h);
    // The intersection lies outside of the triangle
    if (u < 0.0 || u > 1.0) {
      return null;
    }

    // Prepare to test v parameter
    final q = s.cross(edge1);
    // Calculate V parameter and test bounds
    final v = f * ray.direction.dot(q);

    // The intersection lies outside of the triangle
    if (v < 0.0 || u + v > 1.0) {
      return null;
    }

    // At this stage we can compute t to find out where the intersection point is on the line.
    final t = f * edge2.dot(q);

    if (t > epsilon) {
      // Ray intersection
      return ray.origin + ray.direction * t;
    } else {
      // This means that there is a line intersection but not a ray intersection.
      return null;
    }
  }
}
