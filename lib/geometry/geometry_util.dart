import 'dart:typed_data';
import 'dart:ui';
import 'package:vector_math/vector_math.dart';

/// Creates a [Plane] from three non-collinear points.
///
/// Returns `null` if the points are collinear (i.e., they lie on a single line)
/// and cannot define a unique plane.
Plane? makePlaneFromVertices(Vector3 p1, Vector3 p2, Vector3 p3) {
  Vector3 v1 = p2 - p1;
  Vector3 v2 = p3 - p1;

  Vector3 normal = v1.cross(v2);

  if (normal.length2 == 0) {
    return null; // Points are collinear
  }
  normal.normalize();

  // For the plane equation Ax + By + Cz + d = 0, the constant d = -n.dot(p)
  // where p is any point on the plane.
  double d = -normal.dot(p1);

  return Plane.normalconstant(normal, d);
}

/// Calculates the intersection of a [ray] with a [plane].
Vector3? intersectRayWithPlane(Ray ray, Plane plane) {
  // A plane can be defined by a normal and a point on the plane.
  // The plane constant d is -normal.dot(pointOnPlane).
  // So, a point on the plane is normal * -constant.
  final pointOnPlane = plane.normal * -plane.constant;
  return intersectRayPlaneFromPointAndNormal(ray, pointOnPlane, plane.normal);
}

/// Calculates the intersection of a [ray] with a plane defined by a [planeOrigin]
/// point and a [planeNormal].
Vector3? intersectRayPlaneFromPointAndNormal(
    Ray ray, Vector3 planeOrigin, Vector3 planeNormal) {
  final double denom = planeNormal.dot(ray.direction);

  if (denom.abs() < 1e-6) {
    return null; // Ray is parallel to the plane.
  }

  final double t = (planeOrigin - ray.origin).dot(planeNormal) / denom;

  if (t >= 0) {
    return ray.origin + (ray.direction * t);
  }

  return null; // Intersection is behind the ray origin.
}

/// Transforms a point from Normalized Device Coordinates (NDC) to world coordinates.
Vector3 unProject(Vector4 ndcVector, Matrix4 inverseCombinedMatrix) {
  final Vector4 homogeneousCoordinates = inverseCombinedMatrix.transform(ndcVector);

  // After transformation, we divide by w to get the final 3D coordinates.
  if (homogeneousCoordinates.w.abs() < 1e-9) {
    return Vector3.zero(); // Avoid division by zero.
  }

  final double invW = 1.0 / homogeneousCoordinates.w;
  return Vector3(
    homogeneousCoordinates.x * invW,
    homogeneousCoordinates.y * invW,
    homogeneousCoordinates.z * invW,
  );
}

/// Computes a picking ray from a 2D screen coordinate (e.g., mouse position).
///
/// Takes a [mousePosition] in screen space (origin top-left) and transforms it
/// into a [Ray] in 3D world space.
Ray computePickRay(
    Offset mousePosition, Size viewportSize, Matrix4 projection, Matrix4 view) {
  double winX = mousePosition.dx;
  double winY = mousePosition.dy;

  final Matrix4 combinedMatrix = projection * view;
  final Matrix4 inverseCombinedMatrix = Matrix4.copy(combinedMatrix)..invert();

  // Convert screen coordinates to Normalized Device Coordinates (NDC) [-1, 1].
  // Note: Y is flipped because screen coords are top-down, NDC is bottom-up.
  final double ndcX = (winX * 2.0) / viewportSize.width - 1.0;
  final double ndcY = 1.0 - (winY * 2.0) / viewportSize.height;

  // Define the start and end points of the ray in NDC space.
  final Vector4 ndcVectorNear = Vector4(ndcX, ndcY, -1, 1.0);
  final Vector4 ndcVectorFar = Vector4(ndcX, ndcY, 1, 1.0);

  // Un-project these points back into world space.
  final Vector3 nearResult = unProject(ndcVectorNear, inverseCombinedMatrix);
  final Vector3 farResult = unProject(ndcVectorFar, inverseCombinedMatrix);

  Vector3 direction = (farResult - nearResult)..normalize();
  return Ray.originDirection(nearResult, direction);
}

/// Transforms a [ray] by the given [matrix].
Ray transformRay(Ray ray, Matrix4 matrix) {
  final Vector3 localOrigin = matrix.transform3(Vector3.copy(ray.origin));
  final Vector3 localDirection = matrix.rotate3(Vector3.copy(ray.direction))..normalize();
  return Ray.originDirection(localOrigin, localDirection);
}

/// Computes the axis-aligned bounding box for a set of [vertices] with a given [stride].
/// Assumes position data is at the beginning of each vertex (offsets 0, 1, 2).
Aabb3 computeAabb(Float32List vertices, int stride) {
  if (vertices.isEmpty) return Aabb3();

  final Vector3 minV = Vector3.all(double.infinity);
  final Vector3 maxV = Vector3.all(double.negativeInfinity);

  for (int i = 0; i < vertices.length; i += stride) {
    final double x = vertices[i];
    final double y = vertices[i + 1];
    final double z = vertices[i + 2];

    if (x < minV.x) minV.x = x;
    if (y < minV.y) minV.y = y;
    if (z < minV.z) minV.z = z;

    if (x > maxV.x) maxV.x = x;
    if (y > maxV.y) maxV.y = y;
    if (z > maxV.z) maxV.z = z;
  }

  return Aabb3.minMax(minV, maxV);
}
