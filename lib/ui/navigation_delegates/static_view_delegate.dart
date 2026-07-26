import 'dart:math' as math;

import 'package:fsk/ui/navigation_delegates/scene_navigation_delegate.dart';
import 'package:vector_math/vector_math.dart';

/// A navigation delegate that implements a static view
class StaticViewDelegate extends FskSceneNavigationDelegate {
  StaticViewDelegate();

  // The rotation of the view, in degrees
  Vector3 _rotation = Vector3(45,0,0);
  Vector3 _orbitCenter = Vector3(0, 0, 0);
  Vector3 _eyeLocation = Vector3(0, 0, -500);

  double _fovYDegrees = 60;
  double _zNear = 0.1;
  double _zFar = 5000000;

  set rotation(Vector3 value) {
    if (_rotation == value) return;
    _rotation = value;
    setNeedsUpdate(true);
  }

  set orbitCenter(Vector3 value) {
    if (_orbitCenter == value) return;
    _orbitCenter = value;
    setNeedsUpdate(true);
  }

  set eyeLocation(Vector3 value) {
    if (_eyeLocation == value) return;
    _eyeLocation = value;
    setNeedsUpdate(true);
  }

  set fovYDegrees(double value) {
    if (_fovYDegrees == value) return;
    _fovYDegrees = value;
    setNeedsUpdate(true);
  }

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
  double get fovYDegrees => _fovYDegrees;
  double get zNear => _zNear;
  double get zFar => _zFar;
  Vector3 get rotation => _rotation;

  @override
  Matrix4 createViewMatrix() {
    final Matrix4 view = Matrix4.identity();

    // Scale the view matrix Y-axis by -1.0.
    // This flips the camera's orientation with the top-left projection matrix
    view.scaleByVector3(Vector3(1.0, -1.0, 1.0));

    // 1. Move the camera back along the Z-axis by the viewing distance
    // (Assuming _eyeLocation.z acts as your orbit radius distance)
    view.translateByVector3(Vector3(0.0, 0.0, -_eyeLocation.z));

    // 2. Apply camera orbital rotation angles
    view.rotateX(radians(_rotation.x));
    view.rotateY(radians(_rotation.y));
    view.rotateZ(radians(_rotation.z));

    // 3. Move the world origin to your focal point target
    view.translateByVector3(-_orbitCenter);

    return view;
  }

  @override
  Matrix4 createProjectionMatrix() {
    final double aspectRatio = scene.viewportSize.width / scene.viewportSize.height;
    final double fovYRadians = radians(_fovYDegrees);

    // 1. Calculate focal length components
    final double g = 1.0 / math.tan(fovYRadians / 2.0);
    final double depthRange = zFar - zNear;

    if (depthRange == 0 || aspectRatio == 0) return Matrix4.identity();

    final Matrix4 proj = Matrix4.zero();

    // 2. Build explicit Vulkan/Metal perspective mapping
    proj.setEntry(0, 0, g / aspectRatio);

    // Invert the Y-scale (-g) to align  with Flutter's top-left origin.
    // This stops geometry from rendering upside down and prevents backface culling bugs.
    proj.setEntry(1, 1, -g);

    // Map Z depth strictly to the modern [0.0, 1.0] range instead of OpenGL's [-1.0, 1.0].
    proj.setEntry(2, 2, zFar / depthRange);
    proj.setEntry(3, 2, 1.0); // W-divide flag for 3D depth perception perspective

    // 3. Set the translation mapping parameters
    proj.setEntry(2, 3, -(zFar * zNear) / depthRange);

    return proj;
  }
}
