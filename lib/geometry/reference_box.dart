import 'dart:ui';
import 'package:vector_math/vector_math.dart' as vm;
import 'geometry_util.dart';
import 'polyline.dart';
import 'edge.dart';
/// Represents an immutable, oriented bounding box in 3D space.
///
/// An instance can be created with potentially degenerate vectors (e.g., zero-length
/// or collinear), in which case it will be marked as invalid. Methods that rely
/// on a valid plane, like `rayIntersect`, will fail gracefully.
class ReferenceBox {
  /// The origin point of the box in 3D space.
  final vm.Vector3 origin;

  /// A vector representing the direction and magnitude of the box's local X-axis.
  final vm.Vector3 xVector;

  /// A vector representing the direction and magnitude of the box's local Y-axis.
  final vm.Vector3 yVector;

  /// A vector representing the direction and magnitude of the box's local Z-axis.
  final vm.Vector3 zVector;

  /// The plane on which the box is defined. Can be null if the box is invalid.
  late final vm.Plane? plane;

  /// The normalized direction of the box's local X-axis.
  late final vm.Vector3 xAxis;

  /// The normalized direction of the box's local Y-axis.
  late final vm.Vector3 yAxis;

  /// The normalized direction of the box's local Z-axis.
  late final vm.Vector3 zAxis;

  /// The four corners of the box's base, cached for performance.
  late final vm.Quad cachedQuad;

  /// A flag indicating whether the box has a valid, non-degenerate plane.
  late final bool _isValid;
  bool get isValid => _isValid;

  /// The normal vector of the box's plane.
  ///
  /// Returns the calculated normal if the plane is valid, otherwise returns a
  /// default `Vector3(0, 0, 1)`.
  vm.Vector3 get normal => plane?.normal ?? vm.Vector3(0, 0, 1);

  /// Creates a ReferenceBox from an origin and three basis vectors.
  ///
  /// All derived properties (axes, plane, quad) are calculated once upon
  /// construction.
  ReferenceBox(this.origin, this.xVector, this.yVector, this.zVector) {
    _initialize();
  }

  /// Creates a [ReferenceBox] centered at [center] with the given [size].
  factory ReferenceBox.fromCenterSize(vm.Vector3 center, Size size, {double depth = 0.0}) {
    final double halfWidth = size.width / 2.0;
    final double halfHeight = size.height / 2.0;
    final double halfDepth = depth / 2.0;

    final origin = vm.Vector3(
      center.x - halfWidth,
      center.y - halfHeight,
      center.z - halfDepth,
    );
    final xVector = vm.Vector3(size.width, 0, 0);
    final yVector = vm.Vector3(0, size.height, 0);
    final zVector = vm.Vector3(0, 0, depth);

    return ReferenceBox(origin, xVector, yVector, zVector);
  }

  /// Creates a degenerate ReferenceBox at the origin, which will be marked as invalid.
  ReferenceBox.zero()
      : origin = vm.Vector3.zero(),
        xVector = vm.Vector3.zero(),
        yVector = vm.Vector3.zero(),
        zVector = vm.Vector3.zero() {
    _initialize();
  }

  /// Creates a new box that is assumed to be co-planar with another.
  ///
  /// This is an efficient constructor that avoids recalculating the plane and axes.
  ReferenceBox.coplanarWithNewVectors(
    ReferenceBox other,
    this.origin,
    this.xVector,
    this.yVector,
    this.zVector,
  ) {
    plane = other.plane;
    xAxis = other.xAxis;
    yAxis = other.yAxis;
    zAxis = other.zAxis;
    cachedQuad = _calculateQuad();
    _isValid = other.isValid; // Inherit validity
  }

  /// Internal helper to compute derived properties and validate the box.
  void _initialize() {
    final normalizedX = xVector.normalized();
    final normalizedY = yVector.normalized();
    final normalizedZ = zVector.normalized();

    // Check for zero-length or non-finite vectors.
    if (normalizedX.isInfinite ||
        normalizedX.isNaN ||
        normalizedY.isInfinite ||
        normalizedY.isNaN ||
        normalizedZ.isInfinite ||
        normalizedZ.isNaN) {
      xAxis = vm.Vector3.zero();
      yAxis = vm.Vector3.zero();
      zAxis = vm.Vector3.zero();
      plane = vm.Plane.components(0, 0, 1, 0); // Assign a default plane.
      _isValid = false; // Mark this instance as invalid.
    } else {
      xAxis = normalizedX;
      yAxis = normalizedY;
      zAxis = normalizedZ;
      // This will be null if points are collinear.
      plane = makePlaneFromVertices(origin, origin + xVector, origin + yVector);
      _isValid = (plane != null);
    }
    cachedQuad = _calculateQuad();
  }

  /// Helper to calculate the quad corners based on the primary vectors.
  vm.Quad _calculateQuad() {
    final p0 = origin;
    final p1 = p0 + xVector;
    final p2 = p1 + yVector;
    final p3 = p0 + yVector;
    return vm.Quad.points(p0, p1, p2, p3);
  }

  /// Returns a new planar [ReferenceBox] offset and scaled from this one's plane.
  ReferenceBox makeBoxFromOffsets2D(vm.Vector2 startOffset, vm.Vector2 endOffset) {
    final newOrigin =
        origin + (xAxis * startOffset.x) + (yAxis * startOffset.y);
    final newXVector = xAxis * (endOffset.x - startOffset.x);
    final newYVector = yAxis * (endOffset.y - startOffset.y);
    //final newZVector = newXVector.cross(newYVector);
    final newZVector = vm.Vector3(0, 0, 1);
    return ReferenceBox(newOrigin, newXVector, newYVector, newZVector);
  }

  /// Returns a new [ReferenceBox] offset from this one using 2D coordinates.
  ReferenceBox subBoxFromOffsets(
      vm.Vector2 startOffset2D, vm.Vector2 endOffset2D, vm.Vector3 zVector) {
    final corners = calcCornersFrom2DVectors(
      origin,
      startOffset2D,
      endOffset2D,
      xAxis,
      yAxis,
    );
    final newXVector = xAxis * (endOffset2D.x - startOffset2D.x);
    final newYVector = yAxis * (endOffset2D.y - startOffset2D.y);
    return ReferenceBox(corners[0], newXVector, newYVector, zVector);
  }

  /// Helper to calculate 3D corner positions from 2D offsets in the box's local space.
  static List<vm.Vector3> calcCornersFrom2DVectors(
    vm.Vector3 origin3D,
    vm.Vector2 startOffset2D,
    vm.Vector2 endOffset2D,
    vm.Vector3 xAxis,
    vm.Vector3 yAxis,
  ) {
    return [
      origin3D + (xAxis * startOffset2D.x) + (yAxis * startOffset2D.y),
      origin3D + (xAxis * endOffset2D.x) + (yAxis * startOffset2D.y),
      origin3D + (xAxis * endOffset2D.x) + (yAxis * endOffset2D.y),
      origin3D + (xAxis * startOffset2D.x) + (yAxis * endOffset2D.y),
    ];
  }

  /// Calculates a [Quad] from 2D offsets in the box's local space.
  vm.Quad calcQuadFrom2DVectors(vm.Vector2 startOffset2D, vm.Vector2 endOffset2D) {
    final corners = calcCornersFrom2DVectors(
      origin,
      startOffset2D,
      endOffset2D,
      xAxis,
      yAxis,
    );
    return vm.Quad.points(corners[0], corners[1], corners[2], corners[3]);
  }

  /// Creates a [Polyline] from 2D offsets in the box's local space.
  Polyline polylineFrom2DVectors(vm.Vector2 startOffset2D, vm.Vector2 endOffset2D) {
    final corners = calcCornersFrom2DVectors(
      origin,
      startOffset2D,
      endOffset2D,
      xAxis,
      yAxis,
    );
    return Polyline.fromVector3(corners);
  }

  /// Converts the base of this reference box into a [Polyline].
  Polyline toPolyline() {
    return Polyline.fromVector3([
      cachedQuad.point0,
      cachedQuad.point1,
      cachedQuad.point2,
      cachedQuad.point3,
    ]);
  }

  /// Returns all 8 corners of the oriented bounding box.
  List<vm.Vector3> getCorners() {
    return [
      origin,                       // 0: Origin (0,0,0)
      origin + xVector,             // 1: +X
      origin + xVector + yVector,   // 2: +X+Y
      origin + yVector,             // 3: +Y
      origin + zVector,             // 4: +Z
      origin + xVector + zVector,   // 5: +X+Z
      origin + xVector + yVector + zVector, // 6: +X+Y+Z
      origin + yVector + zVector,   // 7: +Y+Z
    ];
  }

  /// Transforms a 2D point from the box's local XY plane into 3D world space.
  vm.Vector3 transformPointToReferencePlane(vm.Vector2 v) {
    return origin + (xAxis * v.x) + (yAxis * v.y);
  }

  /// Calculates the local coordinates of a 3D [point] relative to the box's origin and axes.
  vm.Vector3 calcLocalCoordinates(vm.Vector3 point) {
    final vm.Vector3 offset = point - origin;
    return vm.Vector3(
      offset.dot(xAxis),
      offset.dot(yAxis),
      offset.dot(zAxis),
    );
  }

  /// Calculates the intersection point of a [pickRay] with the plane of this box.
  ///
  /// Returns the intersection point if the box is valid and the ray intersects
  /// the box's quad, otherwise returns `null`.
  vm.Vector3? rayIntersect(vm.Ray pickRay) {
    if (!isValid) {
      return null;
    }
    final p = plane!;
    final double denominator = p.normal.dot(pickRay.direction);

    if (denominator.abs() < 1e-6) {
      return null;
    }

    final double t = -(p.normal.dot(pickRay.origin) - p.constant) / denominator;

    if (t < 0) {
      return null;
    }

    final intersectionPoint = pickRay.origin + pickRay.direction * t;

    if (toPolyline().containsPoint(intersectionPoint)) {
      return intersectionPoint;
    }

    return null;
  }

  /// Returns all 12 edge segments of the oriented bounding box.
  List<Edge> getAllEdges() {
    final c = getCorners();
    return [
      // Bottom face
      Edge(c[0], c[1]), Edge(c[1], c[2]), Edge(c[2], c[3]), Edge(c[3], c[0]),
      // Top face
      Edge(c[4], c[5]), Edge(c[5], c[6]), Edge(c[6], c[7]), Edge(c[7], c[4]),
      // Vertical seams
      Edge(c[0], c[4]), Edge(c[1], c[5]), Edge(c[2], c[6]), Edge(c[3], c[7]),
    ];
  }

  @override
  String toString() {
    return "Origin: $origin X: $xVector Y: $yVector Z: $zVector axes: [$xAxis $yAxis $zAxis ${isValid ? normal : 'invalid'}]";
  }
}
