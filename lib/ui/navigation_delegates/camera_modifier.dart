import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

enum CameraModifierStatus {
  started,
  ignored,
  consumed,
  finished,
}

/// Camera modifiers are used by FskSceneNavigationDelegates to provide granular functionality like rotating, panning, scaling, etc.
abstract class CameraModifier {
  CameraModifierStatus onPointerDown(PointerDownEvent event) => CameraModifierStatus.ignored;
  CameraModifierStatus onPointerMove(PointerMoveEvent event) => CameraModifierStatus.ignored;
  CameraModifierStatus onPointerHover(PointerHoverEvent event) => CameraModifierStatus.ignored;
  CameraModifierStatus onPointerUp(PointerUpEvent event) => CameraModifierStatus.ignored;
  CameraModifierStatus onPointerCancel(PointerCancelEvent event) => CameraModifierStatus.ignored;
  CameraModifierStatus onPointerSignal(PointerSignalEvent event) => CameraModifierStatus.ignored;
  CameraModifierStatus onPointerEnter(PointerEnterEvent event) => CameraModifierStatus.ignored;
  CameraModifierStatus onPointerExit(PointerExitEvent event) => CameraModifierStatus.ignored;
  CameraModifierStatus onScaleStart(ScaleStartDetails details) => CameraModifierStatus.ignored;
  CameraModifierStatus onScaleUpdate(ScaleUpdateDetails details) => CameraModifierStatus.ignored;
  CameraModifierStatus onScaleEnd(ScaleEndDetails details) => CameraModifierStatus.ignored;
  CameraModifierStatus onKeyEvent(KeyEvent event) => CameraModifierStatus.ignored;
}
