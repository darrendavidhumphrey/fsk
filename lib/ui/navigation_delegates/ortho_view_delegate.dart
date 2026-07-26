import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:fsk/ui/navigation_delegates/scene_navigation_delegate.dart';
import 'package:vector_math/vector_math.dart';

/// A navigation delegate that implements a static orthographic view
class OrthoViewDelegate extends FskSceneNavigationDelegate implements ScreenRectSubscriber {
  static const Rect defaultViewRect = Rect.fromLTWH(0, 0, 250, 250);
  OrthoViewDelegate({this._viewRect=defaultViewRect});

  Rect _viewRect;
  double _zNear = -1000;
  double _zFar = 1000;


  set zNear(double value) {
    if (_zNear == value) return;
    _zNear = value;
    setNeedsUpdate(true);
  }

  set zFar(double value) {
    if (_zFar == value) return;
    _zFar = value;
    setNeedsUpdate(true);
  }

  @override
  void setViewRect(Rect value) {
    _viewRect = value;
    setNeedsUpdate(true);
  }

  // --- Getters ---
  double get zNear => _zNear;
  double get zFar => _zFar;

  @override
  Matrix4 createViewMatrix() {
    // Fill the render area with the content
    var view = Matrix4.identity();
    return view;
  }

  @override
  Matrix4 createProjectionMatrix() {
    final Matrix4 proj = Matrix4.zero(); // Initialize a blank, flat matrix matrix array

    final double left = _viewRect.left;
    final double right = _viewRect.right;
    final double top = _viewRect.top;       // Flutter top is smaller value (0.0)
    final double bottom = _viewRect.bottom; // Flutter bottom is larger value (250.0)

    // Calculate boundary translations
    final double rml = right - left;
    final double bmt = bottom - top;
    final double fmn = _zFar - _zNear;

    if (rml == 0 || bmt == 0 || fmn == 0) return Matrix4.identity();

    // 🟢 THE FIX: Build an explicit Vulkan/Metal-aligned matrix layout.
    // This scales the X and Y screen bounds to [-1, 1] while cleanly scaling
    // the Z depth range from exactly [0.0 to 1.0].
    proj.setEntry(0, 0, 2.0 / rml);
    proj.setEntry(1, 1, 2.0 / bmt);
    proj.setEntry(2, 2, 1.0 / fmn); // Vulkan/Metal style depth scaling multiplier (1.0 instead of 2.0)
    proj.setEntry(3, 3, 1.0);

    // Set translation parameters
    proj.setEntry(0, 3, -(right + left) / rml);
    proj.setEntry(1, 3, -(bottom + top) / bmt);
    proj.setEntry(2, 3, -_zNear / fmn); // Vulkan/Metal style depth translation offset

    return proj;
  }
}
