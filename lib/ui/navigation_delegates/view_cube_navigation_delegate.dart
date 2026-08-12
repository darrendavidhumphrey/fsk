import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:fsk/fsk.dart';

/// A modifier that provides interactive highlighting, clicking, and rotation tracking
/// for a View Cube implementation.
class ViewCubeModifier extends SceneModifier {
  final ViewCubeNavigationDelegate delegate;

  FskRenderableObject? _highlightedObject;
  vm.Vector3? _originalKd;

  /// The color used to highlight the cube segments on hover.
  Color highlightColor;

  // State for distinguishing click from drag
  Offset? _pointerDownPos;
  static const double _kClickThreshold = 5.0;

  ViewCubeModifier(this.delegate, {this.highlightColor = Colors.lightBlue});

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
  SceneModifierStatus onPointerSignal(PointerSignalEvent event) {
    vm.Ray mouseRay = delegate.getWorldRay(event.localPosition);
    List<FskHitDetails> hits = delegate.scene.hitTest(mouseRay, mode: FskHitTestMode.closest);

    if (hits.isEmpty) {
      return SceneModifierStatus.ignored;
    }

    return SceneModifierStatus.consumed;
  }

  @override
  SceneModifierStatus onPointerDown(PointerDownEvent event) {
    // Perform hit test to see if we should consume the input
    vm.Ray mouseRay = delegate.getWorldRay(event.localPosition);
    List<FskHitDetails> hits = delegate.scene.hitTest(mouseRay, mode: FskHitTestMode.closest);

    if (hits.isEmpty) {
      return SceneModifierStatus.ignored;
    }

    _pointerDownPos = event.localPosition;
    // We return 'started' so that the event is marked as handled, 
    // but the next modifiers (like OrbitRotation) can also see it.
    return SceneModifierStatus.started;
  }

  @override
  SceneModifierStatus onPointerUp(PointerUpEvent event) {
    bool handled = false;
    if (_pointerDownPos != null) {
      final double distance = (event.localPosition - _pointerDownPos!).distance;
      if (distance < _kClickThreshold) {
        // Perform hit test for the click
        vm.Ray mouseRay = delegate.getWorldRay(event.localPosition);
        List<FskHitDetails> hits = delegate.scene.hitTest(mouseRay, mode: FskHitTestMode.closest);

        if (hits.isNotEmpty) {
          delegate.onCubeClicked(hits[0].hitObject.id);
          handled = true;
        }
      }
      _pointerDownPos = null;
    }
    return handled ? SceneModifierStatus.finished : SceneModifierStatus.ignored;
  }

  @override
  SceneModifierStatus onPointerMove(PointerMoveEvent event) {
    final double oldYaw = delegate.yaw;
    final double oldPitch = delegate.pitch;
    
    // ViewCubeModifier doesn't actually perform the rotation itself, 
    // it just tracks it. We return ignored so OrbitRotationModifier handles it,
    // but we can't easily detect if it *will* change unless we are after it.
    // However, the mixin called super.onPointerMove(event) and then checked the diff.
    // In the SceneModifier pattern, if this modifier is added *after* OrbitRotationModifier,
    // it can see the changes.
    
    if (oldYaw != delegate.yaw || oldPitch != delegate.pitch) {
      delegate.onCubeRotated(delegate.yaw, delegate.pitch);
      return SceneModifierStatus.consumed;
    }
    return SceneModifierStatus.ignored;
  }

  @override
  SceneModifierStatus onPointerHover(PointerHoverEvent event) {
    vm.Ray mouseRay = delegate.getWorldRay(event.localPosition);
    List<FskHitDetails> hits = delegate.scene.hitTest(mouseRay, mode: FskHitTestMode.closest);

    if (hits.isNotEmpty) {
      final hitObj = hits[0].hitObject;
      if (hitObj is FskRenderableObject) {
        _updateHighlight(hitObj);
        return SceneModifierStatus.consumed;
      }
    }

    _updateHighlight(null);
    return SceneModifierStatus.ignored;
  }

  @override
  SceneModifierStatus onPointerExit(PointerExitEvent event) {
    _updateHighlight(null);
    return SceneModifierStatus.consumed;
  }
}

/// A navigation delegate that implements a classic 3D orbit camera with a View Cube.
class ViewCubeNavigationDelegate extends OrbitViewDelegate {
  
  ViewCubeNavigationDelegate({
    super.viewRect,
    super.boxFit,
    Color highlightColor = Colors.lightBlue,
  }) {
    // The ViewCubeModifier should be added to handle its own events.
    // We add it to the delegate's modifiers.
    // Note: To track rotation changes correctly, this should probably be added 
    // after or before OrbitRotationModifier depending on how we want to catch the change.
    // If it's after, it sees the new values.
    addModifier('view_cube', ViewCubeModifier(this, highlightColor: highlightColor));
  }

  /// Callback interface for when a cube segment is clicked.
  void onCubeClicked(String id) {}

  /// Callback interface for when the cube is rotated.
  void onCubeRotated(double yaw, double pitch) {}
}
