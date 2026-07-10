import 'package:fsk/ui/navigation_delegates/scene_navigation_delegate.dart';
import 'package:vector_math/vector_math_64.dart';
import '../../fsk_singleton.dart';

/// A navigation delegate that implements a static view
class StaticViewDelegate extends FskSceneNavigationDelegate {
  StaticViewDelegate();

  // The rotation of the view, in degrees
  Vector3 _rotation = Vector3(45,0,180);
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
    Vector3 up = Vector3(0, 1, 0);

    Matrix4 m = makeViewMatrix(_eyeLocation, _orbitCenter, up);
    m.translateByVector3(_orbitCenter);
    m.rotateZ(radians(_rotation.z));
    m.rotateY(radians(_rotation.y));
    m.rotateX(radians(_rotation.x));
    m.translateByVector3(-_orbitCenter);
   return m;
  }

  @override
  Matrix4 createProjectionMatrix() {
    final double aspectRatio =
        scene.viewportSize.width / scene.viewportSize.height;

    Matrix4 proj = Matrix4.identity();
    setPerspectiveMatrix(proj, radians(_fovYDegrees), aspectRatio, zNear, zFar);

    // Ensure Y Axis is the same regardless of platform
    FSK.normalizeUpAxis(proj);

    return proj;
  }
}
