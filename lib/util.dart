import 'dart:math';
import 'dart:ui';
import 'package:vector_math/vector_math_64.dart';

import 'logging.dart';

/// Wraps an angle to be in the range [0, 360).
double clampAngle0To360(double angle) {
  if (!angle.isFinite) {
    return 0.0;
  }

  final clamped = angle % 360.0;

  // Fixes rare floating-point rounding anomalies (e.g., resulting in exactly 360.0)
  return clamped >= 360.0 ? 0.0 : clamped;
}

/// Utility extensions for 3D vector operations.
extension Dist3D on Vector3 {
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

/// Extracts the camera's local right, up, and forward axes from its [viewMatrix].
({Vector3 right, Vector3 up, Vector3 forward}) getCameraAxes(
  Matrix4 viewMatrix,
) {
  final Matrix4 inverseViewMatrix = viewMatrix.clone()..invert();

  final Vector3 right = Vector3(
    inverseViewMatrix.entry(0, 0),
    inverseViewMatrix.entry(1, 0),
    inverseViewMatrix.entry(2, 0),
  )..normalize();
  final Vector3 up = Vector3(
    inverseViewMatrix.entry(0, 1),
    inverseViewMatrix.entry(1, 1),
    inverseViewMatrix.entry(2, 1),
  )..normalize();
  final Vector3 forward = Vector3(
    inverseViewMatrix.entry(0, 2),
    inverseViewMatrix.entry(1, 2),
    inverseViewMatrix.entry(2, 2),
  )..normalize();

  return (right: right, up: up, forward: forward);
}

/// Parses a #RRGGBBAA hex string into a flutter Color(r, g, b, a).
/// Returns solid white  on failure or if null.
Color parseHexColor(String? hex) {
  if (hex == null || !hex.startsWith('#') || hex.length != 9) {
    return const Color(0xFFFFFFFF); // Default to solid white
  }

  try {
    final String cleanHex = hex.substring(
      1,
    ); // Drops the '#' character to leave RRGGBBAA
    final String rrgg = cleanHex.substring(0, 6);
    final String aa = cleanHex.substring(6, 8);

    // Re-orders bytes from RRGGBBAA to Flutter's expected AARRGGBB format
    return Color(int.parse('0x$aa$rrgg'));
  } catch (_) {
    Logging.logError('Error parsing hex color: $hex', source: 'parseHexColor');
    return const Color(0xFFFFFFFF); // Fallback on parsing exceptions
  }
}

/// Parses a space or comma-separated string into a [Vector2].
/// Returns [Vector2.zero] on failure.
Vector2 parseVector2(String value) {
  final parts = value
      .split(RegExp(r'[,\s]+'))
      .where((s) => s.isNotEmpty)
      .map((p) => double.tryParse(p.trim()))
      .toList();
  if (parts.length >= 2 && parts[0] != null && parts[1] != null) {
    return Vector2(parts[0]!, parts[1]!);
  }
  return Vector2.zero();
}

/// Parses a space or comma-separated string into a [Vector3].
/// Returns [Vector3.zero] on failure.
Vector3 parseVector3(String value) {
  final parts = value
      .split(RegExp(r'[,\s]+'))
      .where((s) => s.isNotEmpty)
      .map((p) => double.tryParse(p.trim()))
      .toList();
  if (parts.length >= 3 &&
      parts[0] != null &&
      parts[1] != null &&
      parts[2] != null) {
    return Vector3(parts[0]!, parts[1]!, parts[2]!);
  }
  return Vector3.zero();
}

/// Parses a space or comma-separated string into a [Vector4].
/// Returns [Vector4.zero] on failure.
Vector4 parseVector4(String value) {
  final parts = value
      .split(RegExp(r'[,\s]+'))
      .where((s) => s.isNotEmpty)
      .map((p) => double.tryParse(p.trim()))
      .toList();
  if (parts.length >= 4 &&
      parts[0] != null &&
      parts[1] != null &&
      parts[2] != null &&
      parts[3] != null) {
    return Vector4(parts[0]!, parts[1]!, parts[2]!, parts[3]!);
  }
  return Vector4.zero();
}

Vector4 colorToVector(Color color) {
  return Vector4(color.r, color.g, color.b, color.a);
}
