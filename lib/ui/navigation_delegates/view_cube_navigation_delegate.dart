import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:vector_math/vector_math.dart' hide Colors;
import 'package:fsk/fsk.dart';

/// A mixin that provides interactive highlighting, clicking, and rotation tracking
/// for a View Cube implementation.
mixin ViewCubeInputMixin on OrbitViewDelegate {
  FskRenderableObject? _highlightedObject;
  Vector3? _originalKd;

  /// The color used to highlight the cube segments on hover.
  Color highlightColor = Colors.lightBlue;

  // State for distinguishing click from drag
  Offset? _pointerDownPos;
  static const double _kClickThreshold = 5.0;

  /// Callback interface for when a cube segment is clicked.
  void onCubeClicked(String id) {}

  /// Callback interface for when the cube is rotated.
  void onCubeRotated(double yaw, double pitch) {}

  void _updateHighlight(FskRenderableObject? newTarget) {
    if (_highlightedObject == newTarget) return;

    // 1. Restore previous object
    if (_highlightedObject != null && _originalKd != null) {
      final u = _highlightedObject!.uniforms;
      if (u is LightingUniforms) {
        u.kd = _originalKd!;
      }
    }

    // 2. Highlight new object
    _highlightedObject = newTarget;
    if (_highlightedObject != null) {
      final u = _highlightedObject!.uniforms;
      if (u is LightingUniforms) {
        // Capture the original color before modifying it
        final dynamic currentKd = u.valuesMap['Kd'];
        if (currentKd is Vector3) {
          _originalKd = Vector3.copy(currentKd);
        } else if (currentKd is Color) {
          _originalKd = Vector3(currentKd.r, currentKd.g, currentKd.b);
        } else {
          _originalKd = Vector3(1, 1, 1);
        }

        u.kd = Vector3(highlightColor.r, highlightColor.g, highlightColor.b);
      }
    } else {
      _originalKd = null;
    }
  }

  @override
  void onPointerDown(PointerDownEvent event) {
    _pointerDownPos = event.localPosition;
    super.onPointerDown(event);
  }

  @override
  void onPointerUp(PointerUpEvent event) {
    if (_pointerDownPos != null) {
      final double distance = (event.localPosition - _pointerDownPos!).distance;
      if (distance < _kClickThreshold) {
        // Perform hit test for the click
        Ray mouseRay = getWorldRay(event.localPosition);
        List<FskHitDetails> hits =
            scene.hitTest(mouseRay, mode: FskHitTestMode.closest);

        if (hits.isNotEmpty) {
          onCubeClicked(hits[0].hitObject.id);
        }
      }
      _pointerDownPos = null;
    }
    super.onPointerUp(event);
  }

  @override
  void onPointerMove(PointerMoveEvent event) {
    final double oldYaw = yaw;
    final double oldPitch = pitch;
    super.onPointerMove(event);
    if (oldYaw != yaw || oldPitch != pitch) {
      onCubeRotated(yaw, pitch);
    }
  }

  @override
  void onPointerHover(PointerHoverEvent event) {
    Ray mouseRay = getWorldRay(event.localPosition);
    List<FskHitDetails> hits =
        scene.hitTest(mouseRay, mode: FskHitTestMode.closest);

    if (hits.isNotEmpty) {
      final hitObj = hits[0].hitObject;
      if (hitObj is FskRenderableObject) {
        _updateHighlight(hitObj);
      } else {
        _updateHighlight(null);
      }
    } else {
      _updateHighlight(null);
    }

    super.onPointerHover(event);
  }

  @override
  void onPointerExit(PointerExitEvent event) {
    _updateHighlight(null);
    super.onPointerExit(event);
  }
}

class ViewCubeNavigationDelegate extends OrbitViewDelegate
    with ViewCubeInputMixin {
  ViewCubeNavigationDelegate({
    super.viewRect,
    super.boxFit,
    Color highlightColor = Colors.lightBlue,
  }) {
    this.highlightColor = highlightColor;
  }
}
