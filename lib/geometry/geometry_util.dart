import 'dart:typed_data';
import 'dart:ui';
import 'package:vector_math/vector_math.dart' as vm;

/// Creates a [Plane] from three non-collinear points.
///
/// Returns `null` if the points are collinear (i.e., they lie on a single line)
/// and cannot define a unique plane.
vm.Plane? makePlaneFromVertices(vm.Vector3 p1, vm.Vector3 p2, vm.Vector3 p3) {
  vm.Vector3 v1 = p2 - p1;
  vm.Vector3 v2 = p3 - p1;

  vm.Vector3 normal = v1.cross(v2);

  if (normal.length2 == 0) {
    return null; // Points are collinear
  }
  normal.normalize();

  // For the plane equation Ax + By + Cz + d = 0, the constant d = -n.dot(p)
  // where p is any point on the plane.
  double d = -normal.dot(p1);

  return vm.Plane.normalconstant(normal, d);
}

/// Calculates the intersection of a [ray] with a [plane].
vm.Vector3? intersectRayWithPlane(vm.Ray ray, vm.Plane plane) {
  // A plane can be defined by a normal and a point on the plane.
  // The plane constant d is -normal.dot(pointOnPlane).
  // So, a point on the plane is normal * -constant.
  final pointOnPlane = plane.normal * -plane.constant;
  return intersectRayPlaneFromPointAndNormal(ray, pointOnPlane, plane.normal);
}

/// Calculates the intersection of a [ray] with a plane defined by a [planeOrigin]
/// point and a [planeNormal].
vm.Vector3? intersectRayPlaneFromPointAndNormal(
    vm.Ray ray, vm.Vector3 planeOrigin, vm.Vector3 planeNormal) {
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
vm.Vector3 unProject(vm.Vector4 ndcVector, vm.Matrix4 inverseCombinedMatrix) {
  final vm.Vector4 homogeneousCoordinates = inverseCombinedMatrix.transform(ndcVector);

  // After transformation, we divide by w to get the final 3D coordinates.
  if (homogeneousCoordinates.w.abs() < 1e-9) {
    return vm.Vector3.zero(); // Avoid division by zero.
  }

  final double invW = 1.0 / homogeneousCoordinates.w;
  return vm.Vector3(
    homogeneousCoordinates.x * invW,
    homogeneousCoordinates.y * invW,
    homogeneousCoordinates.z * invW,
  );
}

/// Computes a picking ray from a 2D screen coordinate (e.g., mouse position).
///
/// Takes a [mousePosition] in screen space (origin top-left) and transforms it
/// into a [Ray] in 3D world space.
vm.Ray computePickRay(
    Offset mousePosition, Size viewportSize, vm.Matrix4 projection, vm.Matrix4 view, {double ndcNear = -1.0, double ndcFar = 1.0}) {
  double winX = mousePosition.dx;
  double winY = mousePosition.dy;

  final vm.Matrix4 combinedMatrix = projection * view;
  final vm.Matrix4 inverseCombinedMatrix = vm.Matrix4.copy(combinedMatrix)..invert();

  // Convert screen coordinates to Normalized Device Coordinates (NDC) [-1, 1].
  final double ndcX = (winX * 2.0) / viewportSize.width - 1.0;
  final double ndcY = 1.0 - (winY * 2.0) / viewportSize.height;

  // Define the start and end points of the ray in NDC space.
  final vm.Vector4 ndcVectorNear = vm.Vector4(ndcX, ndcY, ndcNear, 1.0);
  final vm.Vector4 ndcVectorFar = vm.Vector4(ndcX, ndcY, ndcFar, 1.0);

  // Un-project these points back into world space.
  final vm.Vector3 nearResult = unProject(ndcVectorNear, inverseCombinedMatrix);
  final vm.Vector3 farResult = unProject(ndcVectorFar, inverseCombinedMatrix);

  vm.Vector3 direction = (farResult - nearResult)..normalize();
  return vm.Ray.originDirection(nearResult, direction);
}

/// Transforms a [ray] by the given [matrix].
vm.Ray transformRay(vm.Ray ray, vm.Matrix4 matrix) {
  final vm.Vector3 localOrigin = matrix.transform3(vm.Vector3.copy(ray.origin));
  final vm.Vector3 localDirection = matrix.rotate3(vm.Vector3.copy(ray.direction))..normalize();
  return vm.Ray.originDirection(localOrigin, localDirection);
}

/// Computes the axis-aligned bounding box for a set of [vertices] with a given [stride].
/// Assumes position data is at the beginning of each vertex (offsets 0, 1, 2).
vm.Aabb3 computeAabb(Float32List vertices, int stride) {
  if (vertices.isEmpty) return vm.Aabb3();

  final vm.Vector3 minV = vm.Vector3.all(double.infinity);
  final vm.Vector3 maxV = vm.Vector3.all(double.negativeInfinity);

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

  return vm.Aabb3.minMax(minV, maxV);
}
