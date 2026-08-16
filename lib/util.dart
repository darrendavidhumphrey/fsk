import 'dart:math';
import 'dart:ui';
import 'package:vector_math/vector_math.dart' as vm;

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
extension Dist3D on vm.Vector3 {
  /// Calculates the shortest distance from this point to a 3D line segment [a]-[b].
  double distanceToLineSegment3D(vm.Vector3 a, vm.Vector3 b) {
    vm.Vector3 segmentVector = b - a;
    vm.Vector3 pointToSegmentStart = this - a;

    // Project this point onto the line defined by the segment.
    // t is the normalized position of the closest point on the infinite line.
    double t = pointToSegmentStart.dot(segmentVector) / segmentVector.length2;

    // If t is between 0 and 1, the closest point is on the segment.
    // Otherwise, the closest point is one of the endpoints.
    t = t.clamp(0.0, 1.0);

    vm.Vector3 closestPointOnSegment = a + segmentVector * t;

    return distanceTo(closestPointOnSegment);
  }
}

/// Utility extension for [Quad] objects.
extension QuadNormal on vm.Quad {
  /// Computes the normalized surface normal of the quad.
  vm.Vector3 getSurfaceNormal() {
    vm.Vector3 normal = (point1 - point0).cross(point2 - point0);
    normal.normalize();
    return normal;
  }
}

/// Utility extensions for [Quaternion] operations.
extension QuaternionExtensions on vm.Quaternion {
  /// Calculates the dot product between this quaternion and another.
  double dotProduct(vm.Quaternion q2) {
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
  vm.Quaternion negated() {
    return vm.Quaternion(-x, -y, -z, -w);
  }
}

/// Performs Spherical Linear Interpolation (slerp) between two quaternions.
///
/// This function is safe and does not modify the input quaternions [q1] and [q2].
/// [t] is the interpolation factor, clamped between 0.0 and 1.0.
vm.Quaternion slerp(vm.Quaternion q1, vm.Quaternion q2, double t) {
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
    return vm.Quaternion(x, y, z, w).normalized();
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
  return vm.Quaternion(x, y, z, w);
}

/// Computes normalized 2D texture coordinates (UVs) for a triangle's vertices.
///
/// The coordinates are calculated relative to a bounding box defined by the
/// origin [x],[y] and dimensions [w],[h].
List<vm.Vector2> computeTexCoords(
  vm.Vector3 p0,
  vm.Vector3 p1,
  vm.Vector3 p2,
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
    vm.Vector2((p0.x - x) / width, (p0.y - y) / height),
    vm.Vector2((p1.x - x) / width, (p1.y - y) / height),
    vm.Vector2((p2.x - x) / width, (p2.y - y) / height),
  ];
}

/// Extracts the camera's local right, up, and forward axes from its [viewMatrix].
({vm.Vector3 right, vm.Vector3 up, vm.Vector3 forward}) getCameraAxes(
  vm.Matrix4 viewMatrix,
) {
  final vm.Matrix4 inverseViewMatrix = viewMatrix.clone()..invert();

  final vm.Vector3 right = vm.Vector3(
    inverseViewMatrix.entry(0, 0),
    inverseViewMatrix.entry(1, 0),
    inverseViewMatrix.entry(2, 0),
  )..normalize();
  final vm.Vector3 up = vm.Vector3(
    inverseViewMatrix.entry(0, 1),
    inverseViewMatrix.entry(1, 1),
    inverseViewMatrix.entry(2, 1),
  )..normalize();
  final vm.Vector3 forward = vm.Vector3(
    inverseViewMatrix.entry(0, 2),
    inverseViewMatrix.entry(1, 2),
    inverseViewMatrix.entry(2, 2),
  )..normalize();

  return (right: right, up: up, forward: forward);
}

/// Parses a #RRGGBBAA hex string into a flutter Color(r, g, b, a).
/// Returns default color  on failure or if null.
Color parseHexColor(String? hex,{required Color defaultColor}) {
  if (hex == null || !hex.startsWith('#') || hex.length != 9) {
    return defaultColor;
  }

  try {
    final String cleanHex = hex.substring(
      1,
    ); // Drops the '#' character to leave RRGGBBAA
    final String rrggbb = cleanHex.substring(0, 6);
    final String aa = cleanHex.substring(6, 8);

    // Re-orders bytes from RRGGBBAA to Flutter's expected AARRGGBB format
    return Color(int.parse('0x$aa$rrggbb'));
  } catch (_) {
    Logging.logError('Error parsing hex color: $hex', source: 'parseHexColor');
    return defaultColor; // Fallback on parsing exceptions
  }
}

/// Parses a space or comma-separated string into a [Vector2].
/// Returns [Vector2.zero] on failure.
vm.Vector2 parseVector2(String value) {
  final parts = value
      .split(RegExp(r'[,\s]+'))
      .where((s) => s.isNotEmpty)
      .map((p) => double.tryParse(p.trim()))
      .toList();
  if (parts.length >= 2 && parts[0] != null && parts[1] != null) {
    return vm.Vector2(parts[0]!, parts[1]!);
  }
  return vm.Vector2.zero();
}

/// Parses a space or comma-separated string into a [Vector3].
/// Returns [Vector3.zero] on failure.
vm.Vector3 parseVector3(String value) {
  final parts = value
      .split(RegExp(r'[,\s]+'))
      .where((s) => s.isNotEmpty)
      .map((p) => double.tryParse(p.trim()))
      .toList();
  if (parts.length >= 3 &&
      parts[0] != null &&
      parts[1] != null &&
      parts[2] != null) {
    return vm.Vector3(parts[0]!, parts[1]!, parts[2]!);
  }
  return vm.Vector3.zero();
}

/// Parses a space or comma-separated string into a [Vector4].
/// Returns [Vector4.zero] on failure.
vm.Vector4 parseVector4(String value) {
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
    return vm.Vector4(parts[0]!, parts[1]!, parts[2]!, parts[3]!);
  }
  return vm.Vector4.zero();
}

vm.Vector4 colorToVector(Color color) {
  // Use red, green, blue, alpha properties which are always 0-255, 
  // then normalize to 0.0-1.0. This is safe across Flutter versions.
  return vm.Vector4(
    color.red / 255.0,
    color.green / 255.0,
    color.blue / 255.0,
    color.alpha / 255.0,
  );
}
