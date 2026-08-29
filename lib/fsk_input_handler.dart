import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:fsk/ui/navigation_delegates/scene_navigation_delegate.dart';
import 'package:fsk/ui/navigation_delegates/scene_interaction_behavior.dart';

/// An interface for objects that can handle raw pointer and keyboard input events
/// within the FSK rendering engine.
///
/// Methods return `true` if the event was consumed and should not propagate further,
/// or `false` if it should be passed to the next handler/layer.
abstract class FskInputHandler {
  bool onPointerDown(PointerDownEvent event);
  bool onPointerMove(PointerMoveEvent event);
  bool onPointerHover(PointerHoverEvent event);
  bool onPointerUp(PointerUpEvent event);
  bool onPointerCancel(PointerCancelEvent event);
  bool onPointerSignal(PointerSignalEvent event);
  bool onPointerEnter(PointerEnterEvent event);
  bool onPointerExit(PointerExitEvent event);
  bool onScaleStart(ScaleStartDetails details);
  bool onScaleUpdate(ScaleUpdateDetails details);
  bool onScaleEnd(ScaleEndDetails details);
  KeyEventResult onKeyEvent(KeyEvent event);
}

/// A mixin that implements [FskInputHandler] by passing events to [SceneInteractionBehavior]s.
///
/// Classes using this mixin must provide a list of [behaviors].
mixin FskCameraBehaviorInputMixin implements FskInputHandler {
  List<SceneInteractionBehavior> get behaviors;

  bool _handleEvent(SceneInteractionBehaviorStatus Function(SceneInteractionBehavior) call) {
    bool anyHandled = false;
    for (final behavior in behaviors.reversed) {
      final status = call(behavior);
      if (status != SceneInteractionBehaviorStatus.ignored) {
        anyHandled = true;
      }
    }
    return anyHandled;
  }

  @override
  bool onPointerDown(PointerDownEvent event) => _handleEvent((m) => m.onPointerDown(event));
  @override
  bool onPointerMove(PointerMoveEvent event) => _handleEvent((m) => m.onPointerMove(event));
  @override
  bool onPointerHover(PointerHoverEvent event) => _handleEvent((m) => m.onPointerHover(event));
  @override
  bool onPointerUp(PointerUpEvent event) => _handleEvent((m) => m.onPointerUp(event));
  @override
  bool onPointerCancel(PointerCancelEvent event) => _handleEvent((m) => m.onPointerCancel(event));
  @override
  bool onPointerSignal(PointerSignalEvent event) => _handleEvent((m) => m.onPointerSignal(event));
  @override
  bool onPointerEnter(PointerEnterEvent event) => _handleEvent((m) => m.onPointerEnter(event));
  @override
  bool onPointerExit(PointerExitEvent event) => _handleEvent((m) => m.onPointerExit(event));
  @override
  bool onScaleStart(ScaleStartDetails details) => _handleEvent((m) => m.onScaleStart(details));
  @override
  bool onScaleUpdate(ScaleUpdateDetails details) => _handleEvent((m) => m.onScaleUpdate(details));
  @override
  bool onScaleEnd(ScaleEndDetails details) => _handleEvent((m) => m.onScaleEnd(details));

  @override
  KeyEventResult onKeyEvent(KeyEvent event) {
    bool anyHandled = false;
    for (final behavior in behaviors.reversed) {
      final status = behavior.onKeyEvent(event);
      if (status != SceneInteractionBehaviorStatus.ignored) {
        anyHandled = true;
      }
    }
    return anyHandled ? KeyEventResult.handled : KeyEventResult.ignored;
  }
}

/// A mixin that provides default empty implementations for all [FskInputHandler] methods.
mixin FskInputHandlerDefaultMixin implements FskInputHandler {
  @override
  bool onPointerDown(PointerDownEvent event) => false;
  @override
  bool onPointerMove(PointerMoveEvent event) => false;
  @override
  bool onPointerHover(PointerHoverEvent event) => false;
  @override
  bool onPointerUp(PointerUpEvent event) => false;
  @override
  bool onPointerCancel(PointerCancelEvent event) => false;
  @override
  bool onPointerSignal(PointerSignalEvent event) => false;
  @override
  bool onPointerEnter(PointerEnterEvent event) => false;
  @override
  bool onPointerExit(PointerExitEvent event) => false;
  @override
  bool onScaleStart(ScaleStartDetails details) => false;
  @override
  bool onScaleUpdate(ScaleUpdateDetails details) => false;
  @override
  bool onScaleEnd(ScaleEndDetails details) => false;
  @override
  KeyEventResult onKeyEvent(KeyEvent event) => KeyEventResult.ignored;
}

/// A mixin that dispatches input events directly to an associated [FskSceneNavigationDelegate].
mixin FskSceneInputDispatcherMixin implements FskInputHandler {
  /// Classes using this mixin must provide a navigation delegate.
  FskSceneNavigationDelegate? get navigationDelegate;

  @override
  bool onPointerDown(PointerDownEvent event) =>
      navigationDelegate?.onPointerDown(event) ?? false;
  @override
  bool onPointerMove(PointerMoveEvent event) =>
      navigationDelegate?.onPointerMove(event) ?? false;
  @override
  bool onPointerHover(PointerHoverEvent event) =>
      navigationDelegate?.onPointerHover(event) ?? false;
  @override
  bool onPointerUp(PointerUpEvent event) =>
      navigationDelegate?.onPointerUp(event) ?? false;
  @override
  bool onPointerCancel(PointerCancelEvent event) =>
      navigationDelegate?.onPointerCancel(event) ?? false;
  @override
  bool onPointerSignal(PointerSignalEvent event) =>
      navigationDelegate?.onPointerSignal(event) ?? false;
  @override
  bool onPointerEnter(PointerEnterEvent event) =>
      navigationDelegate?.onPointerEnter(event) ?? false;
  @override
  bool onPointerExit(PointerExitEvent event) =>
      navigationDelegate?.onPointerExit(event) ?? false;
  @override
  bool onScaleStart(ScaleStartDetails details) =>
      navigationDelegate?.onScaleStart(details) ?? false;
  @override
  bool onScaleUpdate(ScaleUpdateDetails details) =>
      navigationDelegate?.onScaleUpdate(details) ?? false;
  @override
  bool onScaleEnd(ScaleEndDetails details) =>
      navigationDelegate?.onScaleEnd(details) ?? false;
  @override
  KeyEventResult onKeyEvent(KeyEvent event) =>
      navigationDelegate?.onKeyEvent(event) ?? KeyEventResult.ignored;
}
