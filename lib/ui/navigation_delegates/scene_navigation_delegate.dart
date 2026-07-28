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

/// An abstract interface for classes that handle user input to navigate a [FskScene].
///
/// This decouples the interaction logic (like orbiting, panning, or zooming)
/// from the rendering widget itself. It defines a contract for a set of event
/// handlers that a widget like [RenderToTexture] can call in response to user input.
abstract class FskSceneNavigationDelegate with ChangeNotifier {
  /// The scene that this delegate controls.
  late FskScene scene;
  late Matrix4 _projectionMatrix;
  late Matrix4 _viewMatrix;

  FskSceneNavigationDelegate({this._viewRect = defaultViewRect, this._boxFit = FskBoxFit.none}) {
    _projectionMatrix = Matrix4.identity();
    _viewMatrix = Matrix4.identity();
  }

  /////////////////////////////////////////////////////////////////////////////
  // Needs Update
  /////////////////////////////////////////////////////////////////////////////
  bool _needsUpdate = true;
  bool get needsUpdate => _needsUpdate;

  void setNeedsUpdate(bool value) {
    _needsUpdate = value;
    if (_needsUpdate) {
      if (_needsUpdate) {
        notifyListeners(); // Alert the listening Widget
      }
    }
  }

  /////////////////////////////////////////////////////////////////////////////
  // BoxFit
  /////////////////////////////////////////////////////////////////////////////
  FskBoxFit _boxFit;
  FskBoxFit get boxFit => _boxFit;
  set boxFit(FskBoxFit value) {
    _boxFit = value;
    setNeedsUpdate(true);
  }

  /////////////////////////////////////////////////////////////////////////////
  // ViewRect
  /////////////////////////////////////////////////////////////////////////////
  static const Rect defaultViewRect = Rect.fromLTWH(0, 0, 250, 250);
  Rect _viewRect;
  Rect get viewRect => _viewRect;

  void setViewRect(Rect value) {
    _viewRect = value;
    setNeedsUpdate(true);
  }

  void setViewMatrix(Matrix4 matrix) {
    matrix.copyInto(_viewMatrix);
  }

  void setProjectionMatrix(Matrix4 matrix) {
    matrix.copyInto(_projectionMatrix);
  }

  Matrix4 getProjectionMatrix() {
    if (needsUpdate) {
      updateSceneMatrices();
    }
    return _projectionMatrix;
  }

  Matrix4 getViewMatrix() {
    if (needsUpdate) {
      updateSceneMatrices();
    }
    return _viewMatrix;
  }

  // Virtual methods to be implemented by derived classes
  Matrix4 createViewMatrix();
  Matrix4 createProjectionMatrix();

  void updateSceneMatrices({bool force = false}) {
    if (needsUpdate || force) {
      Matrix4 view = createViewMatrix();
      setViewMatrix(view);

      Matrix4 proj = createProjectionMatrix();
      setProjectionMatrix(proj);
      setNeedsUpdate(false);
    }

    scene.mvMatrixStack.current = getViewMatrix();
    scene.pMatrix = getProjectionMatrix();
  }

  /// Sets the scene that this delegate will control. This is typically called
  /// by the owner widget when the delegate is initialized or when the scene changes.
  void setScene(FskScene scene) {
    this.scene = scene;
    setNeedsUpdate(true);
  }

  /// Called when a tap down event occurs. Useful for discrete actions like
  /// object selection or setting a focus point.
  void onTapDown(TapDownDetails event) {}

  /// Called when a pointer makes contact with the screen. This is typically
  /// the start of a continuous gesture like a drag or pan.
  void onPointerDown(PointerDownEvent event) {}

  /// Called when a pointer that is in contact with the screen has moved.
  /// This is used to update continuous gestures.
  void onPointerMove(PointerMoveEvent event) {}

  /// Called when a pointer that is in contact with the screen is no longer
  /// in contact. This signals the end of a continuous gesture.
  void onPointerUp(PointerUpEvent event) {}

  /// Called when the input from a pointer is no longer directed at this widget,
  /// for example, if the system cancels the gesture.
  void onPointerCancel(PointerCancelEvent event) {}

  /// Called when a pointer signal event occurs (e.g., mouse wheel or trackpad scroll).
  /// This is typically used for zooming or dollying the camera.
  void onPointerSignal(PointerSignalEvent event) {}

  /// Called when a scale gesture starts.
  void onScaleStart(ScaleStartDetails details) {}

  /// Called when a scale gesture updates.
  void onScaleUpdate(ScaleUpdateDetails details) {}

  /// Called when a scale gesture ends.
  void onScaleEnd(ScaleEndDetails details) {}

  /// Handles a key event from a focused widget.
  ///
  /// Returns a [KeyEventResult] to indicate whether the event was handled.
  KeyEventResult onKeyEvent(KeyEvent event) {
    return KeyEventResult.ignored;
  }

  /// Child class should override if they need to clean up resources.
  void dispose() {}

  /// Creates a matrix that scales and translates content of [contentSize] to fit
  /// the current view according to the selected [boxFit] strategy.
  ///
  /// This assumes the content is centered at its own origin (0,0).
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
      ..translate(_viewRect.left + viewWidth / 2, _viewRect.top + viewHeight / 2, 0.0)
      ..scale(scaleX, scaleY, 1.0);
  }
}
