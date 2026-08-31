import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:fsk/fsk.dart';

class OrbitOnHitRotationBehavior extends OrbitRotationBehavior {
  OrbitOnHitRotationBehavior(super.delegate);

  @override
  SceneInteractionBehaviorStatus onPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons == delegate.rotationMouseButton) {

      vm.Ray mouseRay = delegate.getWorldRay(event.localPosition);

      List<FskHitDetails> hits = delegate.scene.hitTest(
        mouseRay,
        mode: FskHitTestMode.closest,
      );

      if (hits.isEmpty) {
        return SceneInteractionBehaviorStatus.ignored;
      }
    }
    return super.onPointerDown(event);
  }

  @override
  SceneInteractionBehaviorStatus onPointerMove(PointerMoveEvent event) {
    final status = super.onPointerMove(event);
    if (status == SceneInteractionBehaviorStatus.consumed) {
       // Notify the delegate that the rotation was updated via interaction
       (delegate as ViewCubeNavigationDelegate).onCubeRotated(delegate.yaw, delegate.pitch);
    }
    return status;
  }
}

/// A behavior that provides interactive highlighting, clicking, and rotation tracking
/// for a View Cube implementation.
class ViewCubeHighlightBehavior extends SceneInteractionBehavior with LoggableClass {
  final ViewCubeNavigationDelegate delegate;

  FskRenderableObject? _highlightedObject;
  vm.Vector3? _originalKd;

  /// The color used to highlight the cube segments on hover.
  Color highlightColor;

  // State for distinguishing click from drag
  Offset? _pointerDownPos;
  static const double _kClickThreshold = 5.0;

  ViewCubeHighlightBehavior(
    this.delegate, {
    this.highlightColor = Colors.lightBlue,
  });

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
  SceneInteractionBehaviorStatus onPointerSignal(PointerSignalEvent event) {
    vm.Ray mouseRay = delegate.getWorldRay(event.localPosition);
    List<FskHitDetails> hits = delegate.scene.hitTest(
      mouseRay,
      mode: FskHitTestMode.closest,
    );

    if (hits.isEmpty) {
      return SceneInteractionBehaviorStatus.ignored;
    }

    return SceneInteractionBehaviorStatus.consumed;
  }

  @override
  SceneInteractionBehaviorStatus onPointerDown(PointerDownEvent event) {
    // Perform hit test to see if we should consume the input
    vm.Ray mouseRay = delegate.getWorldRay(event.localPosition);
    List<FskHitDetails> hits = delegate.scene.hitTest(
      mouseRay,
      mode: FskHitTestMode.closest,
    );

    if (hits.isEmpty) {
      return SceneInteractionBehaviorStatus.ignored;
    }

    _pointerDownPos = event.localPosition;
    // We return 'started' so that the event is marked as handled,
    // but the next behaviors (like OrbitRotation) can also see it.
    return SceneInteractionBehaviorStatus.started;
  }

  @override
  SceneInteractionBehaviorStatus onPointerUp(PointerUpEvent event) {
    bool handled = false;
    if (_pointerDownPos != null) {
      final double distance = (event.localPosition - _pointerDownPos!).distance;
      if (distance < _kClickThreshold) {
        // Perform hit test for the click
        vm.Ray mouseRay = delegate.getWorldRay(event.localPosition);
        List<FskHitDetails> hits = delegate.scene.hitTest(
          mouseRay,
          mode: FskHitTestMode.closest,
        );

        if (hits.isNotEmpty) {
          delegate.onCubeClicked(hits[0].hitObject.id);
          handled = true;
        }
      }
      _pointerDownPos = null;
    }
    return handled
        ? SceneInteractionBehaviorStatus.finished
        : SceneInteractionBehaviorStatus.ignored;
  }

  @override
  SceneInteractionBehaviorStatus onPointerMove(PointerMoveEvent event) {
    return SceneInteractionBehaviorStatus.ignored;
  }

  @override
  SceneInteractionBehaviorStatus onPointerHover(PointerHoverEvent event) {
    vm.Ray mouseRay = delegate.getWorldRay(event.localPosition);
    List<FskHitDetails> hits = delegate.scene.hitTest(
      mouseRay,
      mode: FskHitTestMode.closest,
    );

    if (hits.isNotEmpty) {
      final hitObj = hits[0].hitObject;
      if (hitObj is FskRenderableObject) {
        _updateHighlight(hitObj);
        return SceneInteractionBehaviorStatus.consumed;
      }
    }

    _updateHighlight(null);
    return SceneInteractionBehaviorStatus.ignored;
  }

  @override
  SceneInteractionBehaviorStatus onPointerExit(PointerExitEvent event) {
    _updateHighlight(null);
    return SceneInteractionBehaviorStatus.consumed;
  }
}

/// A navigation delegate that implements a classic 3D orbit camera with a View Cube.
class ViewCubeNavigationDelegate extends OrbitViewDelegateBase {
  ViewCubeNavigationDelegate({
    super.viewRect,
    super.boxFit,
    super.fovYDegrees,
    super.zNear,
    super.zFar,
    super.rotationMouseButton,
    super.panMouseButton,
    Color highlightColor = Colors.lightBlue,
  }) {
    // The ViewCubeHighlightBehavior should be added to handle its own events.
    addBehavior(
      'view_cube',
      ViewCubeHighlightBehavior(this, highlightColor: highlightColor),
    );
    addBehavior('orbit_rotation', OrbitOnHitRotationBehavior(this));
  }

  /// Callback interface for when a cube segment is clicked.
  void onCubeClicked(String id) {}

  /// Callback interface for when the cube is rotated.
  void onCubeRotated(double yaw, double pitch) {}
}
