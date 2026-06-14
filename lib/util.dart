import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:vector_math/vector_math_64.dart';

/// Wraps an angle to be in the range [0, 360).
double clampAngle0To360(double angle) {
  if (!angle.isFinite) {
    return 0.0;
  }

  final clamped = angle % 360.0;

  // Fixes rare floating-point rounding anomalies (e.g., resulting in exactly 360.0)
  return clamped >= 360.0 ? 0.0 : clamped;
}

/// Utility extensions for creating Vector views on buffers.
extension VectorView on Vector3 {
  /// Creates a [Vector3] view of a [buffer] at a given [offset].
  static Vector3 view(Float32List buffer, int offset) {
    return Vector3.fromBuffer(buffer.buffer, offset);
  }
}

/// Utility extensions for 3D vector operations.
extension Dist2D on Vector3 {
  /// Calculates the shortest distance from this point to a 3D line segment [a]-[b].
  double distanceToLineSegment3D(Vector3 a, Vector3 b) {
    Vector3 segmentVector = b - a;
    Vector3 pointToSegmentStart = this - a;

    // Project this point onto the line defined by the segment.
    // t is the normalized position of the closest point on the infinite line.
    double t = pointToSegmentStart.dot(segmentVector) / segmentVector.length2;

    // If t is between 0 and 1, the closest point is on the segment.
    // Otherwise, the closest point is one of the endpoints.
    t = t.clamp(0.0, 1.0);

    Vector3 closestPointOnSegment = a + segmentVector * t;

    return distanceTo(closestPointOnSegment);
  }
}

/// Utility extension for [Quad] objects.
extension QuadNormal on Quad {
  /// Computes the normalized surface normal of the quad.
  Vector3 getSurfaceNormal() {
    Vector3 normal = (point1 - point0).cross(point2 - point0);
    normal.normalize();
    return normal;
  }
}

/// Utility extension for human-readable [Vector3] formatting.
extension VectorToString on Vector3 {
  String niceString() {
    return "(x: ${x.toStringAsFixed(2)} y: ${y.toStringAsFixed(2)} z: ${z.toStringAsFixed(2)})";
  }
}

/// Utility extension for human-readable [Quad] formatting.
extension QuadToString on Quad {
  String niceString() {
    String pointsStr = "Quad =";
    pointsStr += "${point0.niceString()} ";
    pointsStr += "${point1.niceString()} ";
    pointsStr += "${point2.niceString()} ";
    pointsStr += point3.niceString();
    return pointsStr;
  }
}

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

/// Checks for value equality between two [Quad] objects.
bool quadsAreEqual(Quad q1, Quad q2) {
  return (q1.point0 == q2.point0 &&
      q1.point1 == q2.point1 &&
      q1.point2 == q2.point2 &&
      q1.point3 == q2.point3);
}

/// Utility extensions for [Quaternion] operations.
extension QuaternionExtensions on Quaternion {
  /// Calculates the dot product between this quaternion and another.
  double dotProduct(Quaternion q2) {
    return x * q2.x + y * q2.y + z * q2.z + w * q2.w;
  }

  /// Negates this quaternion in place.
  void negate() {
    x = -x;
    y = -y;
    z = -z;
    w = -w;
  }

  /// Returns a new quaternion that is the negated version of this one.
  Quaternion negated() {
    return Quaternion(-x, -y, -z, -w);
  }
}

/// Performs Spherical Linear Interpolation (slerp) between two quaternions.
///
/// This function is safe and does not modify the input quaternions [q1] and [q2].
/// [t] is the interpolation factor, clamped between 0.0 and 1.0.
Quaternion slerp(Quaternion q1, Quaternion q2, double t) {
  // Work on copies to avoid modifying the original quaternions.
  var q1Copy = q1.normalized();
  var q2Copy = q2.normalized();

  double dot = q1Copy.dotProduct(q2Copy);

  // If the dot product is negative, the quaternions are in opposite hemispheres.
  // Negating one of them allows for interpolation along the shorter path.
  if (dot < 0.0) {
    q2Copy = q2Copy.negated();
    dot = -dot;
  }

  // If the quaternions are very close, use linear interpolation (LERP) for
  // performance and to avoid floating-point inaccuracies.
  const double dotThreshold = 0.9995;
  if (dot > dotThreshold) {
    final x = q1Copy.x * (1 - t) + q2Copy.x * t;
    final y = q1Copy.y * (1 - t) + q2Copy.y * t;
    final z = q1Copy.z * (1 - t) + q2Copy.z * t;
    final w = q1Copy.w * (1 - t) + q2Copy.w * t;
    return Quaternion(x, y, z, w).normalized();
  }

  // Standard slerp calculation.
  // The angle between the quaternions.
  double theta_0 = acos(dot);
  // The angle for the interpolation.
  double theta = theta_0 * t;
  double sinTheta = sin(theta);
  double sinTheta0 = sin(theta_0);

  // Calculate the scaling factors for the two quaternions.
  double s0 = cos(theta) - dot * sinTheta / sinTheta0;
  double s1 = sinTheta / sinTheta0;

  // Perform the interpolation.
  final x = (q1Copy.x * s0) + (q2Copy.x * s1);
  final y = (q1Copy.y * s0) + (q2Copy.y * s1);
  final z = (q1Copy.z * s0) + (q2Copy.z * s1);
  final w = (q1Copy.w * s0) + (q2Copy.w * s1);
  return Quaternion(x, y, z, w);
}

/// Utility extension for ray-triangle intersection tests.
extension TriangleHit on Triangle {
  /// Performs a ray-triangle intersection test using the Möller–Trumbore algorithm.
  /// Returns the intersection point as a [Vector3], or `null` if there is no intersection.
  Vector3? rayTriangleIntersect(Vector3 rayOrigin, Vector3 rayDirection,
      {double epsilon = 0.000001}) {
    final edge1 = point1 - point0;
    final edge2 = point2 - point0;
    final h = rayDirection.cross(edge2);
    final a = edge1.dot(h);

    if (a > -epsilon && a < epsilon) {
      return null; // Ray is parallel to the triangle.
    }

    final f = 1.0 / a;
    final s = rayOrigin - point0;
    final u = f * s.dot(h);

    if (u < 0.0 || u > 1.0) {
      return null; // Intersection point is outside the triangle.
    }

    final q = s.cross(edge1);
    final v = f * rayDirection.dot(q);

    if (v < 0.0 || u + v > 1.0) {
      return null; // Intersection point is outside the triangle.
    }

    final t = f * edge2.dot(q);

    if (t > epsilon) {
      // Ray intersects the triangle
      return rayOrigin + rayDirection * t;
    } else {
      // A negative t means the intersection is behind the ray origin.
      return null;
    }
  }
}

/// Finds the intersection of a 2D line segment [p1]-[p2] with a vertical line.
Vector3? getIntersectionWithVerticalLine(
  Vector3 p1,
  Vector3 p2,
  double verticalLineX,
) {
  double t = (verticalLineX - p1.x) / (p2.x - p1.x);

  // Check if the intersection point lies on the line segment.
  if (t >= -1e-6 && t <= 1 + 1e-6) {
    double intersectionY = p1.y + t * (p2.y - p1.y);
    return Vector3(verticalLineX, intersectionY, 0);
  }
  return null;
}

/// Finds the intersection of a 2D line segment [p1]-[p2] with a horizontal line.
Vector3? getIntersectionWithHorizontalLine(
  Vector3 p1,
  Vector3 p2,
  double horizontalLineY,
) {
  double t = (horizontalLineY - p1.y) / (p2.y - p1.y);

  // Check if the intersection point lies on the line segment.
  if (t >= -1e-6 && t <= 1 + 1e-6) {
    double intersectionX = p1.x + t * (p2.x - p1.x);
    return Vector3(intersectionX, horizontalLineY, 0);
  }
  return null;
}

/// Computes normalized 2D texture coordinates (UVs) for a triangle's vertices.
///
/// The coordinates are calculated relative to a bounding box defined by the
/// origin [x],[y] and dimensions [w],[h].
List<Vector2> computeTexCoords(
  Vector3 p0,
  Vector3 p1,
  Vector3 p2,
  double x,
  double y,
  double w,
  double h,
) {
  // This appears to be a bug or a hack. It arbitrarily offsets the texture
  // coordinates if the bounding box origin is at zero.
  if (x == 0) {
    x = 0.5;
  }
  if (y == 0) {
    y = 0.5;
  }

  // Prevent division by zero if the bounding box has no area.
  final double width = w > 1e-6 ? w : 1.0;
  final double height = h > 1e-6 ? h : 1.0;

  return [
    Vector2((p0.x - x) / width, (p0.y - y) / height),
    Vector2((p1.x - x) / width, (p1.y - y) / height),
    Vector2((p2.x - x) / width, (p2.y - y) / height),
  ];
}

/// Transforms a point from Normalized Device Coordinates (NDC) to world coordinates.
Vector3 unProject(Vector4 ndcVector, Matrix4 inverseCombinedMatrix) {
  final Vector4 homogeneousCoords = inverseCombinedMatrix.transform(ndcVector);

  // After transformation, we divide by w to get the final 3D coordinates.
  if (homogeneousCoords.w.abs() < 1e-9) {
    return Vector3.zero(); // Avoid division by zero.
  }

  final double invW = 1.0 / homogeneousCoords.w;
  return Vector3(
    homogeneousCoords.x * invW,
    homogeneousCoords.y * invW,
    homogeneousCoords.z * invW,
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
  final double ndcX = (winX * 2.0) / viewportSize.width - 1.0;
  // This is correct, because origin is lower left, not top left!
  final double ndcY = (winY * 2.0) / viewportSize.height - 1.0;

  // Define the start and end points of the ray in NDC space.
  final Vector4 ndcVectorNear = Vector4(ndcX, ndcY, -1, 1.0);
  final Vector4 ndcVectorFar = Vector4(ndcX, ndcY, 1, 1.0);

  // Un-project these points back into world space.
  final Vector3 nearResult = unProject(ndcVectorNear, inverseCombinedMatrix);
  final Vector3 farResult = unProject(ndcVectorFar, inverseCombinedMatrix);

  Vector3 direction = (farResult - nearResult)..normalize();
  return Ray.originDirection(nearResult, direction);
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

/// Extracts the camera's local right, up, and forward axes from its [viewMatrix].
({Vector3 right, Vector3 up, Vector3 forward}) getCameraAxes(Matrix4 viewMatrix) {
  final Matrix4 inverseViewMatrix = viewMatrix.clone()..invert();

  final Vector3 right = Vector3(inverseViewMatrix.entry(0, 0),
      inverseViewMatrix.entry(1, 0), inverseViewMatrix.entry(2, 0))
    ..normalize();
  final Vector3 up = Vector3(inverseViewMatrix.entry(0, 1),
      inverseViewMatrix.entry(1, 1), inverseViewMatrix.entry(2, 1))
    ..normalize();
  final Vector3 forward = Vector3(inverseViewMatrix.entry(0, 2),
      inverseViewMatrix.entry(1, 2), inverseViewMatrix.entry(2, 2))
    ..normalize();

  return (right: right, up: up, forward: forward);
}

extension Float32ListVectorView on Float32List {
  /// Creates a non-allocating [Vector3] view into the list starting at
  /// the given float [offset].
  ///
  /// The offset is in floats, not bytes. For example, an offset of 3
  /// will view the second vector in a tightly packed list of vertices.
  Vector3 vector3View(int offset) {
    // Vector3.fromBuffer expects a byte offset. Since each float in a
    // Float32List is 4 bytes, we multiply the float offset by 4.
    return Vector3.fromBuffer(buffer, offset * 4);
  }
}