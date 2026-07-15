import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';
import '../../fsk_scene.dart';

/// Some SceneNavigationDelegates need to subscribe to the screen size by implementing
/// this interface.
abstract interface class ScreenRectSubscriber {
  void setViewRect(Rect value);
}

/// An abstract interface for classes that handle user input to navigate a [FskScene].
///
/// This decouples the interaction logic (like orbiting, panning, or zooming)
/// from the rendering widget itself. It defines a contract for a set of event
/// handlers that a widget like [RenderToTexture] can call in response to user input.
abstract class FskSceneNavigationDelegate {
  /// The scene that this delegate controls.
  late FskScene scene;
  late Matrix4 _projectionMatrix;
  late Matrix4 _viewMatrix;

  FskSceneNavigationDelegate() {
     _projectionMatrix = Matrix4.identity();
     _viewMatrix = Matrix4.identity();
  }
  bool _needsUpdate = true;
  bool get needsUpdate => _needsUpdate;

  void setNeedsUpdate(bool value) {
    _needsUpdate = value;
    if (_needsUpdate) {
      scene.requestRepaint();
    }
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

  void updateSceneMatrices() {
    if (scene.isInitialized) {
      if (needsUpdate) {
        Matrix4 view = createViewMatrix();
        setViewMatrix(view);

        Matrix4 proj = createProjectionMatrix();
        setProjectionMatrix(proj);
        setNeedsUpdate(false);
      }

      scene.mvMatrixStack.current = getViewMatrix();
      scene.pMatrix = getProjectionMatrix();
      scene.requestRepaint();
    }
    scene.requestRepaint();
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
}
