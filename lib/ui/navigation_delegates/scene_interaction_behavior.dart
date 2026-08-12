import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

enum SceneInteractionBehaviorStatus {
  started,
  ignored,
  consumed,
  finished,
}

/// Interaction behaviors are used by FskSceneNavigationDelegates to provide granular functionality 
/// like rotating, panning, scaling, highlighting, etc.
abstract class SceneInteractionBehavior {
  SceneInteractionBehaviorStatus onPointerDown(PointerDownEvent event) => SceneInteractionBehaviorStatus.ignored;
  SceneInteractionBehaviorStatus onPointerMove(PointerMoveEvent event) => SceneInteractionBehaviorStatus.ignored;
  SceneInteractionBehaviorStatus onPointerHover(PointerHoverEvent event) => SceneInteractionBehaviorStatus.ignored;
  SceneInteractionBehaviorStatus onPointerUp(PointerUpEvent event) => SceneInteractionBehaviorStatus.ignored;
  SceneInteractionBehaviorStatus onPointerCancel(PointerCancelEvent event) => SceneInteractionBehaviorStatus.ignored;
  SceneInteractionBehaviorStatus onPointerSignal(PointerSignalEvent event) => SceneInteractionBehaviorStatus.ignored;
  SceneInteractionBehaviorStatus onPointerEnter(PointerEnterEvent event) => SceneInteractionBehaviorStatus.ignored;
  SceneInteractionBehaviorStatus onPointerExit(PointerExitEvent event) => SceneInteractionBehaviorStatus.ignored;
  SceneInteractionBehaviorStatus onScaleStart(ScaleStartDetails details) => SceneInteractionBehaviorStatus.ignored;
  SceneInteractionBehaviorStatus onScaleUpdate(ScaleUpdateDetails details) => SceneInteractionBehaviorStatus.ignored;
  SceneInteractionBehaviorStatus onScaleEnd(ScaleEndDetails details) => SceneInteractionBehaviorStatus.ignored;
  SceneInteractionBehaviorStatus onKeyEvent(KeyEvent event) => SceneInteractionBehaviorStatus.ignored;
}
