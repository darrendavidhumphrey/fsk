import 'dart:ui';

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
    Matrix4 proj = Matrix4.identity();

    // 🟢 TOP-DOWN PROJECTION: 
    // logical top (0) maps to NDC -1.0 (Top)
    // logical bottom (720) maps to NDC 1.0 (Bottom)
    // This creates a standard screen coordinate system where larger Y moves things DOWN.
    setOrthographicMatrix(
        proj,
        _viewRect.left,
        _viewRect.right,
        _viewRect.top,    
        _viewRect.bottom, 
        _zNear,
        _zFar);

    return proj;
  }
}
