import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:vector_math/vector_math.dart';
import 'package:fsk/fsk.dart';


class ViewCubeNavigationDelegate extends OrbitViewDelegate {
  ViewCubeNavigationDelegate({super.viewRect, super.boxFit});

  FskRenderableObject? _highlightedObject;
  Vector3? _originalKd;

  static final Vector3 _kHighlightColor = Vector3(0.4, 0.7, 1.0); // Light Blue

  // State for distinguishing click from drag
  Offset? _pointerDownPos;
  static const double _kClickThreshold = 5.0;

  /// Callback interface for when a cube segment is clicked.
  /// Derived classes can override this to handle navigation or other actions.
  void onCubeClicked(String id) {
    print('ViewCubeNavigationDelegate: Clicked on "$id"');
  }

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
        // We use a dynamic access to the value map to get the CURRENT value
        final dynamic currentKd = u.valuesMap['Kd'];
        if (currentKd is Vector3) {
          _originalKd = Vector3.copy(currentKd);
        } else if (currentKd is Color) {
          _originalKd = Vector3(currentKd.r, currentKd.g, currentKd.b);
        } else {
          _originalKd = Vector3(1, 1, 1);
        }

        u.kd = _kHighlightColor;
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
