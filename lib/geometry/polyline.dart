import 'dart:typed_data';
import 'dart:math';
import 'geometry_util.dart';
import 'package:vector_math/vector_math_64.dart';

/// An immutable class representing a 3D polyline (a connected sequence of line segments).
///
/// This class assumes the vertices form a closed, co-planar polygon. Its methods,
/// such as `containsPoint`, are based on this assumption.
class Polyline {
  /// The raw vertex data, stored as a flat list of coordinates (x, y, z, ...).
  final Float32List _vertices;

  /// The number of vertices in the polyline.
  int get length => _vertices.length ~/ 3;

  /// The plane on which the polyline is defined.
  /// This is calculated once at construction time.
  late final Plane plane;

  /// A flag indicating whether the calculated plane is valid.
  /// A plane is invalid if the polyline has fewer than 3 vertices or if its
  /// first three vertices are collinear.
  late final bool planeIsValid;

  /// The normal vector of the polyline's plane. Returns null if the plane is invalid.
  Vector3? get normal => planeIsValid ? plane.normal : null;

  /// A read-only view of the raw vertex data.
  Float32List get vertices => _vertices;

  /// Internal constructor for creating a Polyline from a vertex list.
  /// This is the single point where the plane is calculated.
  Polyline._internal(this._vertices) {
    _calculatePlane();
  }

  ///Constructor for creating a Polyline from a Float32List of 3 component vertices
  /// This is the single point where the plane is calculated.
  Polyline.fromFloat32List(this._vertices) {
    _calculatePlane();
  }

  /// Creates a Polyline from a list of 2D points, assuming they lie on the XY plane (z=0).
  Polyline.fromVector2(List<Vector2> points)
      : this._internal(Float32List.fromList(
          points.expand((v) => [v.x, v.y, 0.0]).toList(growable: false),
        ));

  /// Creates a Polyline from a list of 3D points.
  Polyline.fromVector3(List<Vector3> points)
      : this._internal(Float32List.fromList(
          points.expand((v) => [v.x, v.y, v.z]).toList(growable: false),
        ));

  /// Creates a new polyline by copying another.
  Polyline.fromPolyline(Polyline other)
      : this._internal(Float32List.fromList(other._vertices));

  /// Creates a new polyline by copying a subset of vertices from another polyline
  /// based on a list of valid indices.
  Polyline.fromIndices(Polyline other, List<int> validIndices)
      : this._internal(Float32List.fromList(validIndices.expand((index) {
          final srcIndex = index * 3;
          return [
            other._vertices[srcIndex],
            other._vertices[srcIndex + 1],
            other._vertices[srcIndex + 2],
          ];
        }).toList(growable: false)));

  /// Gets the vertex at the specified [index] as a [Vector2], ignoring the z-coordinate.
  Vector2 getVector2(int index) {
    final int j = index * 3;
    return Vector2(_vertices[j], _vertices[j + 1]);
  }

  /// Gets the vertex at the specified [index] as a [Vector3].
  Vector3 getVector3(int index) {
    final int j = index * 3;
    return Vector3(_vertices[j], _vertices[j + 1], _vertices[j + 2]);
  }

  /// Calculates the plane of the polyline from its first three vertices.
  /// This method is called once during construction.
  void _calculatePlane() {
    if (length < 3) {
      plane = Plane.components(0, 0, 1, 0); // Default plane
      planeIsValid = false;
      return;
    }

    Plane? p = makePlaneFromVertices(
      getVector3(0),
      getVector3(1),
      getVector3(2),
    );
    if (p != null) {
      plane = p;
      planeIsValid = true;
    } else {
      plane = Plane.components(0, 0, 1, 0);
      planeIsValid = false;
    }
  }

  /// Checks if a given 3D [point] is inside the area defined by the closed polyline.
  ///
  /// This method first checks if the point lies on the polyline's plane. If it does,
  /// it uses the cross-product method to determine if the point lies on the same
  /// side of all edges.
  bool containsPoint(Vector3 point) {
    if (!planeIsValid) {
      return false;
    }

    // First, check if the point is on the plane of the polyline.
    if (plane.distanceToVector3(point).abs() > 1e-6) {
      return false;
    }

    double? referenceDotProductSign;

    for (int i = 0; i < length; i++) {
      final Vector3 p1 = getVector3(i);
      final Vector3 p2 = getVector3((i + 1) % length); // Wrap around

      final Vector3 edge = p2 - p1;
      final Vector3 pointToEdgeStart = point - p1;

      final Vector3 crossProductResult = edge.cross(pointToEdgeStart);
      final double dotProductWithNormal = crossProductResult.dot(plane.normal);

      // If the point is collinear with the edge, skip to the next edge.
      if (dotProductWithNormal.abs() < 1e-6) {
        continue;
      }

      final double currentSign = dotProductWithNormal.sign;

      // If the sign is different from previous edges, the point is outside.
      if (referenceDotProductSign == null) {
        referenceDotProductSign = currentSign;
      } else if (referenceDotProductSign != currentSign) {
        return false;
      }
    }

    // If the point is on the same side of all edges, it is inside.
    return true;
  }

  /// Returns a list of vertex indices that are not degenerate.
  ///
  /// A vertex is considered degenerate if it is too close to the next vertex
  /// in the sequence.
  List<int> getValidVertexIndices() {
    List<int> result = [];
    double minDistance = 0.0001;

    for (int i = 0; i < length; i++) {
      Vector3 p1 = getVector3(i);
      Vector3 p2 = getVector3((i + 1) % length);
      double distance = p1.distanceTo(p2);
      if (distance >= minDistance) {
        result.add(i);
      }
    }
    return result;
  }

  /// Returns a new, transformed [Polyline] by applying a 2D transformation
  /// in 3D space, defined by an origin and basis vectors.
  Polyline transform(Vector3 origin3D, Vector3 xAxis, Vector3 yAxis) {
    final newVertices = Float32List(length * 3);
    for (int i = 0, j = 0; i < length; i++, j += 3) {
      Vector3 v = getVector3(i);
      v = origin3D + (xAxis * v.x) + (yAxis * v.y);
      newVertices[j] = v.x;
      newVertices[j + 1] = v.y;
      newVertices[j + 2] = v.z;
    }
    return Polyline._internal(newVertices);
  }

  /// Calculates the intersection point of a [pickRay] with the plane of this polyline.
  ///
  /// Returns the intersection point if it is within the bounds of the polyline,
  /// otherwise returns `null`.
  Vector3? rayIntersect(Ray pickRay) {
    if (!planeIsValid) {
      return null;
    }

    final Vector3? intersectionPoint = intersectRayWithPlane(pickRay, plane);

    if (intersectionPoint != null && containsPoint(intersectionPoint)) {
      return intersectionPoint;
    }

    return null;
  }

  /// Calculates the 2D bounding box of the polyline on the XY plane.
  /// Returns a record containing the minimum and maximum corner points.
  ({Vector2 min, Vector2 max}) getBounds2D() {
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < length; i++) {
      Vector2 v = getVector2(i);
      minX = min(minX, v.x);
      minY = min(minY, v.y);
      maxX = max(maxX, v.x);
      maxY = max(maxY, v.y);
    }

    return (min: Vector2(minX, minY), max: Vector2(maxX, maxY));
  }

  /// Checks for value equality. Two [Polyline] instances are considered equal
  /// if their vertex lists are identical.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Polyline) return false;
    if (_vertices.length != other._vertices.length) return false;

    for (int i = 0; i < _vertices.length; i++) {
      if (_vertices[i] != other._vertices[i]) return false;
    }
    return true;
  }

  /// Provides a hash code consistent with value equality.
  @override
  int get hashCode => Object.hashAll(_vertices);
}
