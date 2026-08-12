import 'package:flutter/material.dart' hide Matrix4;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:fsk/fsk.dart';
import 'scene_interaction_behavior.dart';

enum FskBoxFit {
  none,
  fitWidth,
  fitHeight,
  fill,
  bestFit,
}

abstract class FskSceneNavigationDelegate with ChangeNotifier, FskCameraBehaviorInputMixin implements FskInputHandler {
  late FskSceneBase scene;
  late vm.Matrix4 _projectionMatrix;
  late vm.Matrix4 _viewMatrix;

  final Map<String, SceneInteractionBehavior> _behaviors = {};
  final List<SceneInteractionBehavior> _behaviorOrder = [];

  @override
  List<SceneInteractionBehavior> get behaviors => List.unmodifiable(_behaviorOrder);

  void addBehavior(String name, SceneInteractionBehavior behavior) {
    if (_behaviors.containsKey(name)) {
      removeBehavior(name);
    }
    _behaviors[name] = behavior;
    _behaviorOrder.add(behavior);
  }

  void removeBehavior(String name) {
    final behavior = _behaviors.remove(name);
    if (behavior != null) {
      _behaviorOrder.remove(behavior);
    }
  }

  /// A plane at z=0 used for calculating logical coordinates from a pick ray.
  final vm.Plane _projectPlane = makePlaneFromVertices(
    vm.Vector3.zero(),
    vm.Vector3(1, 0, 0),
    vm.Vector3(0, 1, 0),
  )!;

  FskSceneNavigationDelegate({this._viewRect = defaultViewRect, this._boxFit = FskBoxFit.none}) {
    _projectionMatrix = vm.Matrix4.identity();
    _viewMatrix = vm.Matrix4.identity();
  }

  bool _needsUpdate = true;
  bool get needsUpdate => _needsUpdate;

  void setNeedsUpdate(bool value) {
    _needsUpdate = value;
    if (_needsUpdate) notifyListeners();
  }

  FskBoxFit _boxFit;
  FskBoxFit get boxFit => _boxFit;
  set boxFit(FskBoxFit value) {
    _boxFit = value;
    setNeedsUpdate(true);
  }

  static const Rect defaultViewRect = Rect.fromLTWH(0, 0, 250, 250);
  Rect _viewRect;
  Rect get viewRect => _viewRect;

  void setViewRect(Rect value) {
    _viewRect = value;
    setNeedsUpdate(true);
  }

  /// Calculates the camera's position in 3D space.
  vm.Vector3 getEyeLocation() {
    return vm.Vector3(0, 0, 0);
  }

  void setViewMatrix(vm.Matrix4 matrix) => matrix.copyInto(_viewMatrix);
  void setProjectionMatrix(vm.Matrix4 matrix) => matrix.copyInto(_projectionMatrix);

  vm.Matrix4 getProjectionMatrix() {
    if (needsUpdate) updateSceneMatrices();
    return _projectionMatrix;
  }

  vm.Matrix4 getViewMatrix() {
    if (needsUpdate) updateSceneMatrices();
    return _viewMatrix;
  }

  vm.Matrix4 createViewMatrix();
  vm.Matrix4 createProjectionMatrix();

  void updateSceneMatrices({bool force = false}) {
    if (needsUpdate || force) {
      setViewMatrix(createViewMatrix());
      setProjectionMatrix(createProjectionMatrix());
      setNeedsUpdate(false);
    }
    scene.mvMatrix.setFrom(getViewMatrix());
    scene.pMatrix.setFrom(getProjectionMatrix());
  }

  void setScene(FskSceneBase scene) {
    this.scene = scene;
    setNeedsUpdate(true);
  }

  /// Creates a matrix that scales and translates content of [contentSize] to fit
  /// the current view.
  /// This version anchors (0,0) of the content to the viewport origin.
  vm.Matrix4 createBoxFitMatrix(Size contentSize) {
    double scaleX = 1.0;
    double scaleY = 1.0;

    final viewWidth = _viewRect.width;
    final viewHeight = _viewRect.height;

    switch (boxFit) {
      case FskBoxFit.none:
        break;
      case FskBoxFit.fitWidth:
        scaleX = viewWidth / contentSize.width;
        scaleY = scaleX;
        break;
      case FskBoxFit.fitHeight:
        scaleY = viewHeight / contentSize.height;
        scaleX = scaleY;
        break;
      case FskBoxFit.fill:
        scaleX = viewWidth / contentSize.width;
        scaleY = viewHeight / contentSize.height;
        break;
      case FskBoxFit.bestFit:
        final sX = viewWidth / contentSize.width;
        final sY = viewHeight / contentSize.height;
        scaleX = sX < sY ? sX : sY;
        scaleY = scaleX;
        break;
    }

    return vm.Matrix4.identity()
      ..translateByVector3(vm.Vector3(_viewRect.left, _viewRect.top, 0.0))
      ..scaleByVector3(vm.Vector3(scaleX, scaleY, 1.0));
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
}
