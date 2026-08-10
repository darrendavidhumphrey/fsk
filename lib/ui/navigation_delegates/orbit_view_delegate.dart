import 'dart:math';
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/gestures.dart' hide Matrix4;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:fsk/fsk.dart';

/// A mixin that provides input handling logic for an orbit-style camera.
/// This mixin expects to be applied to a [FskSceneNavigationDelegate].
mixin OrbitInputMixin on FskSceneNavigationDelegate {
  // Camera state managed by the mixin
  double yaw = 0;
  double pitch = 0;
  double distance = 300;

  // State variables for drag-based rotation.
  Offset _dragStart = Offset.zero;
  double _yawStart = 0;
  double _pitchStart = 0;

  // State variables for pinch zoom.
  double _baseDistance = 0;
  final Set<int> _pointers = {};

  /// Programmatically sets the camera rotation.
  void setOrbitRotation(double newYaw, double newPitch) {
    yaw = clampAngle0To360(newYaw);
    pitch = clampAngle0To360(newPitch);
    setNeedsUpdate(true);
  }

  /// Sets the distance of the camera from the orbit center.
  void setViewDistance(double newDistance) {
    distance = newDistance;
    setNeedsUpdate(true);
  }

  @override
  bool onPointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    _dragStart = event.localPosition;
    _yawStart = yaw;
    _pitchStart = pitch;
    setNeedsUpdate(true);
    return true;
  }

  @override
  bool onPointerUp(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    _dragStart = Offset.zero;
    setNeedsUpdate(true);
    return true;
  }

  @override
  bool onPointerCancel(PointerCancelEvent event) {
    // Treat cancel as a pointer up event to reset state.
    return onPointerUp(PointerUpEvent(
      position: event.position,
      pointer: event.pointer,
    ));
  }

  @override
  bool onPointerMove(PointerMoveEvent event) {
    if (_dragStart == Offset.zero || _pointers.length > 1) return false;

    final deltaX = _dragStart.dx - event.localPosition.dx;
    final deltaY = event.localPosition.dy - _dragStart.dy;

    // Scale sensitivity by viewport size to make rotation feel consistent
    // regardless of widget size.
    final double yawSensitivity = 1 / viewRect.width;
    final double pitchSensitivity = 1 / viewRect.height;
    final double deltaYaw = deltaX * yawSensitivity * pi;
    final double deltaPitch = deltaY * pitchSensitivity * pi;

    final newYaw = _yawStart + vm.degrees(deltaYaw);
    final newPitch = _pitchStart + vm.degrees(deltaPitch);

    setOrbitRotation(newYaw, newPitch);
    return true;
  }

  @override
  bool onPointerSignal(PointerSignalEvent event) {
    const double minRadius = 3;
    if (event is! PointerScrollEvent) return false;

    PointerScrollEvent scrollEvent = event;

    // Use a logarithmic scale for zooming to make it feel more natural.
    double deltaRadius = -log(distance) / log(2);

    if (scrollEvent.scrollDelta.dy < 0) {
      deltaRadius = -deltaRadius;
    }

    double newRadius = distance + deltaRadius;

    if (newRadius < minRadius) {
      newRadius = minRadius;
    }
    setViewDistance(newRadius);
    return true;
  }

  @override
  bool onScaleStart(ScaleStartDetails details) {
    _baseDistance = distance;
    return true;
  }

  @override
  bool onScaleUpdate(ScaleUpdateDetails details) {
    if (_pointers.length < 2 || details.scale == 1.0) return false;

    const double minRadius = 3;
    // Scale the distance inversely proportional to the gesture scale.
    double newDistance = _baseDistance / details.scale;

    if (newDistance < minRadius) {
      newDistance = minRadius;
    }

    setViewDistance(newDistance);
    return true;
  }

  @override
  bool onScaleEnd(ScaleEndDetails details) => true;

  @override
  KeyEventResult onKeyEvent(KeyEvent event) {
    // TODO: Implement keyboard controls for orbit, pan, or zoom.
    return KeyEventResult.ignored;
  }
}

/// A navigation delegate that implements a classic 3D orbit camera.
///
/// This class handles user input to rotate (orbit) around a central point,
/// and zoom (dolly) the camera towards and away from that point.
class OrbitViewDelegate extends FskSceneNavigationDelegate with OrbitInputMixin {

  OrbitViewDelegate({super.viewRect, super.boxFit});

  final double verticalFieldOfView = vm.radians(60);

  /// A plane at z=0 used for calculating logical coordinates from a pick ray.
  final vm.Plane _projectPlane = makePlaneFromVertices(
    vm.Vector3.zero(),
    vm.Vector3(1, 0, 0),
    vm.Vector3(0, 1, 0),
  )!;

  /// Creates the view matrix based on the current yaw, pitch, and distance.
  @override
  vm.Matrix4 createViewMatrix() {
    vm.Vector3 up = vm.Vector3(0, 1, 0);
    vm.Vector3 orbitCenter = getOrbitCenter();

    // Use the library's makeViewMatrix for a correct look-at matrix.
    vm.Matrix4 v = vm.makeViewMatrix(getEyeLocation(), orbitCenter, up);

    // Apply rotations around the orbit center.
    v.translateByVector3(orbitCenter);
    v.rotateZ(vm.radians(180));
    v.rotateY(vm.radians(yaw));
    v.rotateX(vm.radians(pitch));
    v.translateByVector3(-orbitCenter);
    return v;
  }

  /// Calculates the camera's position in 3D space.
  vm.Vector3 getEyeLocation() {
    return vm.Vector3(0, 0, -distance);
  }

  /// The point in space that the camera orbits around.
  vm.Vector3 getOrbitCenter() {
    return vm.Vector3(0, 0, 0);
  }

  /// Converts a 2D screen position into a 3D coordinate on the logical Z=0 plane.
  vm.Vector3? getLogicalCoordinates(Offset mousePosition) {
    vm.Ray ray = computePickRay(
      mousePosition,
      viewRect.size,
      getProjectionMatrix(),
      getViewMatrix(),
      ndcNear: 0.0,
      ndcFar: 1.0,
    );
    return intersectRayWithPlane(ray, _projectPlane);
  }

  /// Gets the world-space picking ray for a given screen position.
  vm.Ray getWorldRay(Offset mousePosition) {
    vm.Ray ray = computePickRay(
      mousePosition,
      viewRect.size,
      getProjectionMatrix(),
      getViewMatrix(),
      ndcNear: 0.0,
      ndcFar: 1.0,
    );
    return ray;
  }

  /// Creates the perspective projection matrix.
  @override
  vm.Matrix4 createProjectionMatrix() {
    final double aspectRatio = viewRect.width / viewRect.height;

    vm.Matrix4 proj = vm.Matrix4.identity();
    vm.setPerspectiveMatrix(
      proj,
      verticalFieldOfView,
      aspectRatio,
      1.0,
      10000.0,
    );

    // flutter_gpu (Impeller) expects Z in [0, 1] (Vulkan style).
    // The vector_math matrix produces Z in [-1, 1] (OpenGL style).
    // We remap: Z_new = 0.5 * Z_old + 0.5
    final vm.Matrix4 remap = vm.Matrix4.identity();
    remap.setEntry(2, 2, 0.5);
    remap.setEntry(2, 3, 0.5);

    return remap * proj;
  }
}
