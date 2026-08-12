import 'dart:math';
import 'package:flutter/gestures.dart' hide Matrix4;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:fsk/fsk.dart';
import 'camera_modifier.dart';

/// A modifier that handles drag-based rotation for the orbit camera.
class OrbitRotationModifier extends CameraModifier {
  final OrbitViewDelegate delegate;
  
  Offset _dragStart = Offset.zero;
  double _yawStart = 0;
  double _pitchStart = 0;

  OrbitRotationModifier(this.delegate);

  @override
  CameraModifierStatus onPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse && event.buttons == delegate.rotationMouseButton) {
      delegate.pointers.add(event.pointer);
      _dragStart = event.localPosition;
      _yawStart = delegate.yaw;
      _pitchStart = delegate.pitch;
      delegate.setNeedsUpdate(true);
      return CameraModifierStatus.started;
    }
    return CameraModifierStatus.ignored;
  }

  @override
  CameraModifierStatus onPointerMove(PointerMoveEvent event) {
    if (_dragStart == Offset.zero || delegate.pointers.length > 1) return CameraModifierStatus.ignored;

    final deltaX = _dragStart.dx - event.localPosition.dx;
    final deltaY = event.localPosition.dy - _dragStart.dy;

    // Scale sensitivity by viewport size to make rotation feel consistent
    // regardless of widget size.
    final double yawSensitivity = 1 / delegate.viewRect.width;
    final double pitchSensitivity = 1 / delegate.viewRect.height;
    final double deltaYaw = deltaX * yawSensitivity * pi;
    final double deltaPitch = deltaY * pitchSensitivity * pi;

    final newYaw = _yawStart + vm.degrees(deltaYaw);
    final newPitch = _pitchStart + vm.degrees(deltaPitch);

    delegate.setOrbitRotation(newYaw, newPitch);
    return CameraModifierStatus.consumed;
  }

  @override
  CameraModifierStatus onPointerUp(PointerUpEvent event) {
    if (delegate.pointers.contains(event.pointer)) {
      delegate.pointers.remove(event.pointer);
      _dragStart = Offset.zero;
      delegate.setNeedsUpdate(true);
      return CameraModifierStatus.finished;
    }
    return CameraModifierStatus.ignored;
  }

  @override
  CameraModifierStatus onPointerCancel(PointerCancelEvent event) {
    return onPointerUp(PointerUpEvent(
      position: event.position,
      pointer: event.pointer,
    ));
  }
}

/// A modifier that handles zoom (dolly) for the orbit camera via scroll or pinch gestures.
class OrbitZoomModifier extends CameraModifier {
  final OrbitViewDelegate delegate;
  double _baseDistance = 0;

  OrbitZoomModifier(this.delegate);

  @override
  CameraModifierStatus onPointerSignal(PointerSignalEvent event) {
    const double minRadius = 3;
    if (event is! PointerScrollEvent) return CameraModifierStatus.ignored;

    PointerScrollEvent scrollEvent = event;

    // Use a logarithmic scale for zooming to make it feel more natural.
    double deltaRadius = -log(delegate.distance) / log(2);

    if (scrollEvent.scrollDelta.dy < 0) {
      deltaRadius = -deltaRadius;
    }

    double newRadius = delegate.distance + deltaRadius;

    if (newRadius < minRadius) {
      newRadius = minRadius;
    }
    delegate.setViewDistance(newRadius);
    return CameraModifierStatus.consumed;
  }

  @override
  CameraModifierStatus onScaleStart(ScaleStartDetails details) {
    _baseDistance = delegate.distance;
    return CameraModifierStatus.started;
  }

  @override
  CameraModifierStatus onScaleUpdate(ScaleUpdateDetails details) {
    if (delegate.pointers.length < 2 || details.scale == 1.0) return CameraModifierStatus.ignored;

    const double minRadius = 3;
    // Scale the distance inversely proportional to the gesture scale.
    double newDistance = _baseDistance / details.scale;

    if (newDistance < minRadius) {
      newDistance = minRadius;
    }

    delegate.setViewDistance(newDistance);
    return CameraModifierStatus.consumed;
  }

  @override
  CameraModifierStatus onScaleEnd(ScaleEndDetails details) => CameraModifierStatus.finished;
}

/// A navigation delegate that implements a classic 3D orbit camera.
///
/// This class handles user input to rotate (orbit) around a central point,
/// and zoom (dolly) the camera towards and away from that point.
class OrbitViewDelegate extends PerspectiveViewDelegate {
  // Camera state
  double yaw = 0;
  double pitch = 0;
  double distance = 300;

  // Which button is used to rotate the camera?
  int rotationMouseButton = kPrimaryButton;

  // Which button is used to pan the camera?
  int panMouseButton = kTertiaryButton;

  // Tracks active pointers for gesture coordination.
  final Set<int> pointers = {};

  OrbitViewDelegate({
    super.viewRect,
    super.boxFit,
    super.fovYDegrees,
    super.zNear,
    super.zFar,
    int? rotationMouseButton,
    int? panMouseButton,
  }){
    this.rotationMouseButton = rotationMouseButton ?? kPrimaryButton;
    this.panMouseButton = panMouseButton ?? kTertiaryButton;

    // Add default modifiers for rotation and zoom.
    addModifier('orbit_rotation', OrbitRotationModifier(this));
    addModifier('orbit_zoom', OrbitZoomModifier(this));
  }

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

  /// Returns the camera's position in 3D space.
  @override
  vm.Vector3 getEyeLocation() {
    return vm.Vector3(0, 0, -distance);
  }

  /// The point in space that the camera orbits around.
  vm.Vector3 getOrbitCenter() {
    return vm.Vector3(0, 0, 0);
  }
}
