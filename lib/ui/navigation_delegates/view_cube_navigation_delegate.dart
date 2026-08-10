import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:fsk/fsk.dart';

/// A mixin that provides interactive highlighting, clicking, and rotation tracking
/// for a View Cube implementation.
mixin ViewCubeInputMixin on OrbitViewDelegate {
  FskRenderableObject? _highlightedObject;
  vm.Vector3? _originalKd;

  /// The color used to highlight the cube segments on hover.
  Color highlightColor = Colors.lightBlue;

  // State for distinguishing click from drag
  Offset? _pointerDownPos;
  static const double _kClickThreshold = 5.0;

  /// Callback interface for when a cube segment is clicked.
  void onCubeClicked(String id) ;

  /// Callback interface for when the cube is rotated.
  void onCubeRotated(double yaw, double pitch);

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
        if (currentKd is vm.Vector3) {
          _originalKd = vm.Vector3.copy(currentKd);
        } else if (currentKd is Color) {
          _originalKd = vm.Vector3(currentKd.r, currentKd.g, currentKd.b);
        } else {
          _originalKd = vm.Vector3(1, 1, 1);
        }

        u.kd = vm.Vector3(highlightColor.r, highlightColor.g, highlightColor.b);
      }
    } else {
      _originalKd = null;
    }
  }

  @override
  bool onPointerDown(PointerDownEvent event) {
    // Perform hit test to see if we should consume the input
    vm.Ray mouseRay = getWorldRay(event.localPosition);
    List<FskHitDetails> hits =
        scene.hitTest(mouseRay, mode: FskHitTestMode.closest);

    if (hits.isEmpty) {
      return false; // Let it pass through to layers/scene underneath
    }

    _pointerDownPos = event.localPosition;
    return super.onPointerDown(event);
  }

  @override
  bool onPointerUp(PointerUpEvent event) {
    bool handled = false;
    if (_pointerDownPos != null) {
      final double distance = (event.localPosition - _pointerDownPos!).distance;
      if (distance < _kClickThreshold) {
        // Perform hit test for the click
        vm.Ray mouseRay = getWorldRay(event.localPosition);
        List<FskHitDetails> hits =
            scene.hitTest(mouseRay, mode: FskHitTestMode.closest);

        if (hits.isNotEmpty) {
          onCubeClicked(hits[0].hitObject.id);
          handled = true;
        }
      }
      _pointerDownPos = null;
    }
    return super.onPointerUp(event) || handled;
  }

  @override
  bool onPointerMove(PointerMoveEvent event) {
    final double oldYaw = yaw;
    final double oldPitch = pitch;
    bool handled = super.onPointerMove(event);
    if (oldYaw != yaw || oldPitch != pitch) {
      onCubeRotated(yaw, pitch);
    }
    return handled;
  }

  @override
  bool onPointerHover(PointerHoverEvent event) {
    vm.Ray mouseRay = getWorldRay(event.localPosition);
    List<FskHitDetails> hits =
        scene.hitTest(mouseRay, mode: FskHitTestMode.closest);

    if (hits.isNotEmpty) {
      final hitObj = hits[0].hitObject;
      if (hitObj is FskRenderableObject) {
        _updateHighlight(hitObj);
        super.onPointerHover(event);
        return true; // We handled the hover highlight
      }
    }

    _updateHighlight(null);
    return super.onPointerHover(event);
  }

  @override
  bool onPointerExit(PointerExitEvent event) {
    _updateHighlight(null);
    return super.onPointerExit(event);
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

  @override
  void onCubeClicked(String id) {}

  /// Callback interface for when the cube is rotated.
  @override
  void onCubeRotated(double yaw, double pitch) {}
}
