import 'package:flutter/gestures.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:vector_math/vector_math.dart';
import '../../fsk_scene.dart';

enum FskBoxFit {
  none,
  fitWidth,
  fitHeight,
  fill,
  bestFit,
}

abstract class FskSceneNavigationDelegate with ChangeNotifier {
  late FskScene scene;
  late Matrix4 _projectionMatrix;
  late Matrix4 _viewMatrix;

  FskSceneNavigationDelegate({this._viewRect = defaultViewRect, this._boxFit = FskBoxFit.none}) {
    _projectionMatrix = Matrix4.identity();
    _viewMatrix = Matrix4.identity();
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

  void setViewMatrix(Matrix4 matrix) => matrix.copyInto(_viewMatrix);
  void setProjectionMatrix(Matrix4 matrix) => matrix.copyInto(_projectionMatrix);

  Matrix4 getProjectionMatrix() {
    if (needsUpdate) updateSceneMatrices();
    return _projectionMatrix;
  }

  Matrix4 getViewMatrix() {
    if (needsUpdate) updateSceneMatrices();
    return _viewMatrix;
  }

  Matrix4 createViewMatrix();
  Matrix4 createProjectionMatrix();

  void updateSceneMatrices({bool force = false}) {
    if (needsUpdate || force) {
      setViewMatrix(createViewMatrix());
      setProjectionMatrix(createProjectionMatrix());
      setNeedsUpdate(false);
    }
    scene.mvMatrixStack.current = getViewMatrix();
    scene.pMatrix = getProjectionMatrix();
  }

  void setScene(FskScene scene) {
    this.scene = scene;
    setNeedsUpdate(true);
  }

  // Input Handlers
  void onTapDown(TapDownDetails event) {}
  void onPointerDown(PointerDownEvent event) {}
  void onPointerMove(PointerMoveEvent event) {}
  void onPointerUp(PointerUpEvent event) {}
  void onPointerCancel(PointerCancelEvent event) {}
  void onPointerSignal(PointerSignalEvent event) {}
  void onScaleStart(ScaleStartDetails details) {}
  void onScaleUpdate(ScaleUpdateDetails details) {}
  void onScaleEnd(ScaleEndDetails details) {}
  KeyEventResult onKeyEvent(KeyEvent event) => KeyEventResult.ignored;

  /// Creates a matrix that scales and translates content of [contentSize] to fit
  /// the current view.
  /// This version anchors (0,0) of the content to the viewport origin.
  Matrix4 createBoxFitMatrix(Size contentSize) {
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

    return Matrix4.identity()
      ..translateByVector3(Vector3(_viewRect.left, _viewRect.top, 0.0))
      ..scaleByVector3(Vector3(scaleX, scaleY, 1.0));
  }
}
