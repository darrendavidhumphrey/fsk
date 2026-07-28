import 'dart:ui';
import 'package:fsk/ui/navigation_delegates/scene_navigation_delegate.dart';
import 'package:vector_math/vector_math.dart';

/// A navigation delegate that implements a static orthographic view
class OrthoViewDelegate extends FskSceneNavigationDelegate {

  OrthoViewDelegate({super.viewRect,super.boxFit});

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
    Matrix4 proj = Matrix4.identity();

    // 🟢 VULKAN-COMPATIBLE ORTHOGRAPHIC PROJECTION: 
    // This manual construction preserves the existing Y-axis mapping (Y-Down)
    // while fixing the Z-depth mapping to the [0.0, 1.0] range expected by Vulkan/Metal.
    // world near maps to 0.0, world far maps to 1.0.

    final double rml = viewRect.right - viewRect.left;
    final double rpl = viewRect.right + viewRect.left;
    final double tmb = viewRect.bottom - viewRect.top;
    final double tpb = viewRect.bottom + viewRect.top;
    final double fmn = _zFar - _zNear;

    proj.setValues(
      2.0 / rml, 0.0, 0.0, 0.0,
      0.0, 2.0 / tmb, 0.0, 0.0,
      0.0, 0.0, 1.0 / fmn, 0.0,
      -rpl / rml, -tpb / tmb, -_zNear / fmn, 1.0,
    );

    return proj;
  }
}
