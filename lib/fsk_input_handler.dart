import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'ui/navigation_delegates/scene_navigation_delegate.dart';

/// An interface for objects that can handle raw pointer and keyboard input events
/// within the FSK rendering engine.
abstract class FskInputHandler {
  void onPointerDown(PointerDownEvent event);
  void onPointerMove(PointerMoveEvent event);
  void onPointerHover(PointerHoverEvent event);
  void onPointerUp(PointerUpEvent event);
  void onPointerCancel(PointerCancelEvent event);
  void onPointerSignal(PointerSignalEvent event);
  void onPointerEnter(PointerEnterEvent event);
  void onPointerExit(PointerExitEvent event);
  void onScaleStart(ScaleStartDetails details);
  void onScaleUpdate(ScaleUpdateDetails details);
  void onScaleEnd(ScaleEndDetails details);
  KeyEventResult onKeyEvent(KeyEvent event);
}

/// A mixin that provides default empty implementations for all [FskInputHandler] methods.
mixin FskInputHandlerDefaultMixin implements FskInputHandler {
  @override
  void onPointerDown(PointerDownEvent event) {}
  @override
  void onPointerMove(PointerMoveEvent event) {}
  @override
  void onPointerHover(PointerHoverEvent event) {}
  @override
  void onPointerUp(PointerUpEvent event) {}
  @override
  void onPointerCancel(PointerCancelEvent event) {}
  @override
  void onPointerSignal(PointerSignalEvent event) {}
  @override
  void onPointerEnter(PointerEnterEvent event) {}
  @override
  void onPointerExit(PointerExitEvent event) {}
  @override
  void onScaleStart(ScaleStartDetails details) {}
  @override
  void onScaleUpdate(ScaleUpdateDetails details) {}
  @override
  void onScaleEnd(ScaleEndDetails details) {}
  @override
  KeyEventResult onKeyEvent(KeyEvent event) => KeyEventResult.ignored;
}

/// A mixin that dispatches input events directly to an associated [FskSceneNavigationDelegate].
mixin FskSceneInputDispatcherMixin implements FskInputHandler {
  /// Classes using this mixin must provide access to a navigation delegate.
  FskSceneNavigationDelegate? get navigationDelegate;

  @override
  void onPointerDown(PointerDownEvent event) =>
      navigationDelegate?.onPointerDown(event);
  @override
  void onPointerMove(PointerMoveEvent event) =>
      navigationDelegate?.onPointerMove(event);
  @override
  void onPointerHover(PointerHoverEvent event) =>
      navigationDelegate?.onPointerHover(event);
  @override
  void onPointerUp(PointerUpEvent event) =>
      navigationDelegate?.onPointerUp(event);
  @override
  void onPointerCancel(PointerCancelEvent event) =>
      navigationDelegate?.onPointerCancel(event);
  @override
  void onPointerSignal(PointerSignalEvent event) =>
      navigationDelegate?.onPointerSignal(event);
  @override
  void onPointerEnter(PointerEnterEvent event) =>
      navigationDelegate?.onPointerEnter(event);
  @override
  void onPointerExit(PointerExitEvent event) =>
      navigationDelegate?.onPointerExit(event);
  @override
  void onScaleStart(ScaleStartDetails details) =>
      navigationDelegate?.onScaleStart(details);
  @override
  void onScaleUpdate(ScaleUpdateDetails details) =>
      navigationDelegate?.onScaleUpdate(details);
  @override
  void onScaleEnd(ScaleEndDetails details) =>
      navigationDelegate?.onScaleEnd(details);
  @override
  KeyEventResult onKeyEvent(KeyEvent event) =>
      navigationDelegate?.onKeyEvent(event) ?? KeyEventResult.ignored;
}
