import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

enum SceneModifierStatus {
  started,
  ignored,
  consumed,
  finished,
}

/// Camera modifiers are used by FskSceneNavigationDelegates to provide granular functionality like rotating, panning, scaling, etc.
abstract class SceneModifier {
  SceneModifierStatus onPointerDown(PointerDownEvent event) => SceneModifierStatus.ignored;
  SceneModifierStatus onPointerMove(PointerMoveEvent event) => SceneModifierStatus.ignored;
  SceneModifierStatus onPointerHover(PointerHoverEvent event) => SceneModifierStatus.ignored;
  SceneModifierStatus onPointerUp(PointerUpEvent event) => SceneModifierStatus.ignored;
  SceneModifierStatus onPointerCancel(PointerCancelEvent event) => SceneModifierStatus.ignored;
  SceneModifierStatus onPointerSignal(PointerSignalEvent event) => SceneModifierStatus.ignored;
  SceneModifierStatus onPointerEnter(PointerEnterEvent event) => SceneModifierStatus.ignored;
  SceneModifierStatus onPointerExit(PointerExitEvent event) => SceneModifierStatus.ignored;
  SceneModifierStatus onScaleStart(ScaleStartDetails details) => SceneModifierStatus.ignored;
  SceneModifierStatus onScaleUpdate(ScaleUpdateDetails details) => SceneModifierStatus.ignored;
  SceneModifierStatus onScaleEnd(ScaleEndDetails details) => SceneModifierStatus.ignored;
  SceneModifierStatus onKeyEvent(KeyEvent event) => SceneModifierStatus.ignored;
}
