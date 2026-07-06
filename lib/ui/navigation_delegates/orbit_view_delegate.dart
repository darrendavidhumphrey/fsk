import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:fsg/fsk.dart';

/// A navigation delegate that implements a classic 3D orbit camera.
///
/// This class handles user input to rotate (orbit) around a central point,
/// and zoom (dolly) the camera towards and away from that point.
class OrbitViewDelegate extends SceneNavigationDelegate {

  OrbitViewDelegate();
  static const double _initialYaw = 0;
  static const double _initialPitch = 0;

  final double verticalFieldOfView = radians(60);

  double _yaw = _initialYaw;
  double get yaw => _yaw;

  double _pitch = _initialPitch;
  double get pitch => _pitch;

  double _distance = 300;
  double get distance => _distance;

  // State variables for drag-based rotation.
  Offset _dragStart = Offset.zero;
  double _yawStart = 0;
  double _pitchStart = 0;

/// A plane at z=0 used for calculating logical coordinates from a pick ray.
  final Plane _projectPlane = makePlaneFromVertices(
    Vector3.zero(),
    Vector3(1, 0, 0),
    Vector3(0, 1, 0),
  )!;

  @override
  void onPointerDown(PointerDownEvent event) {
    _dragStart = event.localPosition;
    _yawStart = yaw;
    _pitchStart = pitch;
    setNeedsUpdate(true);
  }

  @override
  void onPointerUp(PointerUpEvent event) {
    _dragStart = Offset.zero;
    setNeedsUpdate(true);
  }

  @override
  void onPointerCancel(PointerCancelEvent event) {
    // Treat cancel as a pointer up event to reset state.
    onPointerUp(PointerUpEvent(position: event.position));
  }

  @override
  void onTapDown(TapDownDetails event) {
    onPointerDown(PointerDownEvent(position: event.localPosition));
  }

  @override
  void onPointerMove(PointerMoveEvent event) {
    if (_dragStart == Offset.zero) return;

    final deltaX = _dragStart.dx - event.localPosition.dx;
    final deltaY = _dragStart.dy - event.localPosition.dy;

    // Scale sensitivity by viewport size to make rotation feel consistent
    // regardless of widget size.
    final double yawSensitivity = 1 / scene.viewportSize.width;
    final double pitchSensitivity = 1 / scene.viewportSize.height;
    final double deltaYaw = deltaX * yawSensitivity * pi;
    final double deltaPitch = deltaY * pitchSensitivity * pi;

    final newYaw = _yawStart + degrees(deltaYaw);
    final newPitch = _pitchStart + degrees(deltaPitch);

    _yaw = clampAngle0To360(newYaw);
    _pitch = clampAngle0To360(newPitch);
    setNeedsUpdate(true);
  }

  @override
  void onPointerSignal(PointerSignalEvent event) {
    const double minRadius = 3;
    double viewRadius = distance;

    if (event is! PointerScrollEvent) return;

    PointerScrollEvent scrollEvent = event;

    // Use a logarithmic scale for zooming to make it feel more natural.
    double deltaRadius = -log(distance) / log(2);

    if (scrollEvent.scrollDelta.dy < 0) {
      deltaRadius = -deltaRadius;
    }

    viewRadius += deltaRadius;

    if (viewRadius < minRadius) {
      viewRadius = minRadius;
    }
    setViewDistance(viewRadius);
    setNeedsUpdate(true);
  }

  /// Sets the distance of the camera from the orbit center.
  void setViewDistance(double distance) {
    _distance = distance;
  }

  /// Creates the view matrix based on the current yaw, pitch, and distance.
  @override
  Matrix4 createViewMatrix() {
    Vector3 up = Vector3(0, 1, 0);
    Vector3 orbitCenter = getOrbitCenter();

    // Use the library's makeViewMatrix for a correct look-at matrix.
    Matrix4 v = makeViewMatrix(getEyeLocation(), orbitCenter, up);

    // Apply rotations around the orbit center.
    v.translateByVector3(orbitCenter);
    v.rotateZ(radians(180));
    v.rotateY(radians(yaw));
    v.rotateX(radians(pitch));
    v.translateByVector3(-orbitCenter);
    return v;
  }

  /// Calculates the camera's position in 3D space.
  Vector3 getEyeLocation() {
    return Vector3(0, 0, -distance);
  }

  /// The point in space that the camera orbits around.
  Vector3 getOrbitCenter() {
    return Vector3(0, 0, 0);
  }

  /// Converts a 2D screen position into a 3D coordinate on the logical Z=0 plane.
  Vector3? getLogicalCoordinates(Offset mousePosition) {
    Ray ray = computePickRay(
      mousePosition,
      scene.viewportSize,
      getProjectionMatrix(),
      getViewMatrix(),
    );
    return intersectRayWithPlane(ray, _projectPlane);
  }

  /// Gets the world-space picking ray for a given screen position.
  Ray getWorldRay(Offset mousePosition) {
    Ray ray = computePickRay(
      mousePosition,
      scene.viewportSize,
      getProjectionMatrix(),
      getViewMatrix(),
    );
    return ray;
  }

  /// Creates the perspective projection matrix.
  @override
  Matrix4 createProjectionMatrix() {
    final double aspectRatio = scene.viewportSize.width / scene.viewportSize.height;

    Matrix4 proj = Matrix4.identity();
    setPerspectiveMatrix(
      proj,
      verticalFieldOfView,
      aspectRatio,
      0.1,
      5000000,
    );

    // Ensure Y Axis is the same regardless of platform
    FSK.normalizeUpAxis(proj);
    return proj;
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event) {
    // TODO: Implement keyboard controls for orbit, pan, or zoom.
    return KeyEventResult.ignored;
  }
}
