import 'dart:math';
import 'package:flutter/gestures.dart' hide Matrix4;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:fsk/fsk.dart';

/// A behavior that handles drag-based rotation for the orbit camera.
class OrbitRotationBehavior extends SceneInteractionBehavior {
  final OrbitViewDelegateBase delegate;
  
  Offset dragStart = Offset.zero;
  double yawStart = 0;
  double pitchStart = 0;
  bool isDragging = false;

  OrbitRotationBehavior(this.delegate);

  @override
  SceneInteractionBehaviorStatus onPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse && event.buttons == delegate.rotationMouseButton) {
      isDragging = true;
      dragStart = event.localPosition;
      yawStart = delegate.yaw;
      pitchStart = delegate.pitch;
      delegate.setNeedsUpdate(true);
      return SceneInteractionBehaviorStatus.started;
    }
    return SceneInteractionBehaviorStatus.ignored;
  }

  @override
  SceneInteractionBehaviorStatus onPointerMove(PointerMoveEvent event) {
    if (dragStart == Offset.zero || !isDragging) return SceneInteractionBehaviorStatus.ignored;

    final deltaX = dragStart.dx - event.localPosition.dx;
    final deltaY = event.localPosition.dy - dragStart.dy;

    // Scale sensitivity by viewport size to make rotation feel consistent
    // regardless of widget size.
    final double yawSensitivity = 1 / delegate.viewRect.width;
    final double pitchSensitivity = 1 / delegate.viewRect.height;
    final double deltaYaw = deltaX * yawSensitivity * pi;
    final double deltaPitch = deltaY * pitchSensitivity * pi;

    final newYaw = yawStart - vm.degrees(deltaYaw);
    final newPitch = pitchStart + vm.degrees(deltaPitch);

    delegate.setOrbitRotation(newYaw, newPitch);
    return SceneInteractionBehaviorStatus.consumed;
  }

  @override
  SceneInteractionBehaviorStatus onPointerUp(PointerUpEvent event) {
    if (isDragging) {
      isDragging = false;
      dragStart = Offset.zero;
      delegate.setNeedsUpdate(true);
      return SceneInteractionBehaviorStatus.finished;
    }
    return SceneInteractionBehaviorStatus.ignored;
  }

  @override
  SceneInteractionBehaviorStatus onPointerCancel(PointerCancelEvent event) {
    return onPointerUp(PointerUpEvent(
      position: event.position,
      pointer: event.pointer,
    ));
  }
}

/// A behavior that handles zoom (dolly) for the orbit camera via scroll or pinch gestures.
class OrbitZoomBehavior extends SceneInteractionBehavior {
  final OrbitViewDelegateBase delegate;
  double _baseDistance = 0;
  bool _isScaling = false;

  OrbitZoomBehavior(this.delegate);

  @override
  SceneInteractionBehaviorStatus onPointerSignal(PointerSignalEvent event) {

    const double minRadius = 3;
    if (event is! PointerScrollEvent) return SceneInteractionBehaviorStatus.ignored;

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
    return SceneInteractionBehaviorStatus.consumed;
  }

  @override
  SceneInteractionBehaviorStatus onScaleStart(ScaleStartDetails details) {
    _baseDistance = delegate.distance;
    _isScaling = true;
    return SceneInteractionBehaviorStatus.started;
  }

  @override
  SceneInteractionBehaviorStatus onScaleUpdate(ScaleUpdateDetails details) {
    if (!_isScaling || details.scale == 1.0) return SceneInteractionBehaviorStatus.ignored;

    const double minRadius = 3;
    // Scale the distance inversely proportional to the gesture scale.
    double newDistance = _baseDistance / details.scale;

    if (newDistance < minRadius) {
      newDistance = minRadius;
    }

    delegate.setViewDistance(newDistance);
    return SceneInteractionBehaviorStatus.consumed;
  }

  @override
  SceneInteractionBehaviorStatus onScaleEnd(ScaleEndDetails details) {
    _isScaling = false;
    return SceneInteractionBehaviorStatus.finished;
  }
}

/// A navigation delegate that implements a classic 3D orbit camera.
///
/// This class handles user input to rotate (orbit) around a central point,
/// and zoom (dolly) the camera towards and away from that point.
class OrbitViewDelegateBase extends PerspectiveViewDelegate {
  // Camera state
  double yaw = 0;
  double pitch = 0;
  double distance = 300;
  vm.Vector3 orbitCenter = vm.Vector3.zero();

  // Which button is used to rotate the camera?
  int rotationMouseButton = kPrimaryButton;

  // Which button is used to pan the camera?
  int panMouseButton = kTertiaryButton;

  OrbitViewDelegateBase({
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
    // 1. Calculate eye position by rotating the distance vector
    final vm.Vector3 eye = vm.Vector3(0, 0, distance);
    final vm.Matrix4 rotation = vm.Matrix4.identity()
      ..rotateY(vm.radians(-yaw))
      ..rotateX(vm.radians(-pitch));
    
    final vm.Vector3 rotatedEye = rotation.transform3(eye);
    final vm.Vector3 finalEye = rotatedEye + orbitCenter;

    // 2. Look at the orbit center from the rotated position
    return vm.makeViewMatrix(finalEye, orbitCenter, vm.Vector3(0, 1, 0));
  }

  /// Returns the camera's position in 3D space.
  @override
  vm.Vector3 getEyeLocation() {
    final vm.Vector3 eye = vm.Vector3(0, 0, distance);
    final vm.Matrix4 rotation = vm.Matrix4.identity()
      ..rotateY(vm.radians(-yaw))
      ..rotateX(vm.radians(-pitch));
    return rotation.transform3(eye) + orbitCenter;
  }

  /// The point in space that the camera orbits around.
  vm.Vector3 getOrbitCenter() {
    return orbitCenter;
  }
}

class OrbitViewDelegate extends OrbitViewDelegateBase {
  OrbitViewDelegate({super.viewRect,
      super.boxFit,
      super.fovYDegrees,
      super.zNear,
      super.zFar,
      super.rotationMouseButton,
      super.panMouseButton})  {
    // Add default behaviors for rotation and zoom.
    addBehavior('orbit_rotation', OrbitRotationBehavior(this));
    addBehavior('orbit_zoom', OrbitZoomBehavior(this));
  }
}