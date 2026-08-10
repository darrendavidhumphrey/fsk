import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../fsk.dart';

/// A mixin that dispatches input events to the scene's [layers].
mixin FskSceneLayerDispatcherMixin on FskSceneBase {
  final List<ScreenSpaceOverlay> layers = [];

  /// Map of pointer IDs to the overlay that currently "owns" them.
  /// If the value is null, the main scene owns the pointer.
  final Map<int, ScreenSpaceOverlay?> _pointerCaptures = {};

  Size get logicalSize => Size(viewportSize.width / FSK.devicePixelRatio,
      viewportSize.height / FSK.devicePixelRatio);

  @override
  bool onPointerDown(PointerDownEvent event) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(event.localPosition, logicalSize)) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        final transformedEvent = event.transformed(
            Matrix4.translationValues(-origin.dx, -origin.dy, 0) *
                (event.transform ?? Matrix4.identity()));

        if (layer.onPointerDown(transformedEvent)) {
          _pointerCaptures[event.pointer] = layer;
          return true;
        }
      }
    }
    _pointerCaptures[event.pointer] = null;
    return super.onPointerDown(event);
  }

  @override
  bool onPointerMove(PointerMoveEvent event) {
    if (_pointerCaptures.containsKey(event.pointer)) {
      final layer = _pointerCaptures[event.pointer];
      if (layer != null) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        return layer.onPointerMove(event.transformed(
            Matrix4.translationValues(-origin.dx, -origin.dy, 0) *
                (event.transform ?? Matrix4.identity())));
      }
    }
    return super.onPointerMove(event);
  }

  @override
  bool onPointerUp(PointerUpEvent event) {
    if (_pointerCaptures.containsKey(event.pointer)) {
      final layer = _pointerCaptures[event.pointer];
      _pointerCaptures.remove(event.pointer);
      if (layer != null) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        return layer.onPointerUp(event.transformed(
            Matrix4.translationValues(-origin.dx, -origin.dy, 0) *
                (event.transform ?? Matrix4.identity())));
      }
    }
    return super.onPointerUp(event);
  }

  @override
  bool onPointerCancel(PointerCancelEvent event) {
    if (_pointerCaptures.containsKey(event.pointer)) {
      final layer = _pointerCaptures[event.pointer];
      _pointerCaptures.remove(event.pointer);
      if (layer != null) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        return layer.onPointerCancel(event.transformed(
            Matrix4.translationValues(-origin.dx, -origin.dy, 0) *
                (event.transform ?? Matrix4.identity())));
      }
    }
    return super.onPointerCancel(event);
  }

  @override
  bool onPointerSignal(PointerSignalEvent event) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(event.localPosition, logicalSize)) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        final transformedEvent = event.transformed(
            Matrix4.translationValues(-origin.dx, -origin.dy, 0) *
                (event.transform ?? Matrix4.identity())) as PointerSignalEvent;
        if (layer.onPointerSignal(transformedEvent)) return true;
      }
    }
    return super.onPointerSignal(event);
  }

  @override
  bool onPointerHover(PointerHoverEvent event) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(event.localPosition, logicalSize)) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        final transformedEvent = event.transformed(
            Matrix4.translationValues(-origin.dx, -origin.dy, 0) *
                (event.transform ?? Matrix4.identity()));
        if (layer.onPointerHover(transformedEvent)) return true;
      }
    }
    return super.onPointerHover(event);
  }

  @override
  bool onPointerEnter(PointerEnterEvent event) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(event.localPosition, logicalSize)) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        final transformedEvent = event.transformed(
            Matrix4.translationValues(-origin.dx, -origin.dy, 0) *
                (event.transform ?? Matrix4.identity()));
        if (layer.onPointerEnter(transformedEvent)) return true;
      }
    }
    return super.onPointerEnter(event);
  }

  @override
  bool onPointerExit(PointerExitEvent event) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(event.localPosition, logicalSize)) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        final transformedEvent = event.transformed(
            Matrix4.translationValues(-origin.dx, -origin.dy, 0) *
                (event.transform ?? Matrix4.identity()));
        if (layer.onPointerExit(transformedEvent)) return true;
      }
    }
    return super.onPointerExit(event);
  }

  @override
  bool onScaleStart(ScaleStartDetails details) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(details.localFocalPoint, logicalSize)) {
        final transformedDetails = ScaleStartDetails(
          focalPoint: details.focalPoint,
          localFocalPoint:
              layer.screenToViewport(details.localFocalPoint, logicalSize),
          pointerCount: details.pointerCount,
        );
        if (layer.onScaleStart(transformedDetails)) return true;
      }
    }
    return super.onScaleStart(details);
  }

  @override
  bool onScaleUpdate(ScaleUpdateDetails details) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(details.localFocalPoint, logicalSize)) {
        final transformedDetails = ScaleUpdateDetails(
          focalPoint: details.focalPoint,
          localFocalPoint:
              layer.screenToViewport(details.localFocalPoint, logicalSize),
          scale: details.scale,
          horizontalScale: details.horizontalScale,
          verticalScale: details.verticalScale,
          rotation: details.rotation,
          pointerCount: details.pointerCount,
          focalPointDelta: details.focalPointDelta,
        );
        if (layer.onScaleUpdate(transformedDetails)) return true;
      }
    }
    return super.onScaleUpdate(details);
  }

  @override
  bool onScaleEnd(ScaleEndDetails details) {
    bool handled = false;
    for (var layer in layers) {
      if (layer.onScaleEnd(details)) handled = true;
    }
    return super.onScaleEnd(details) || handled;
  }
}
