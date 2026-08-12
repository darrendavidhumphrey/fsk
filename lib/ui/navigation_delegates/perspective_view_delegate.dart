import 'package:vector_math/vector_math.dart' as vm;
import 'package:fsk/ui/navigation_delegates/scene_navigation_delegate.dart';

/// A base class for navigation delegates that use a perspective projection.
///
/// This class provides common properties for perspective viewing, such as
/// field of view and clipping planes, and implements the [createProjectionMatrix]
/// method for a standard 3D perspective.
abstract class PerspectiveViewDelegate extends FskSceneNavigationDelegate {
  double _fovYDegrees;
  double _zNear;
  double _zFar;

  PerspectiveViewDelegate({
    super.viewRect,
    super.boxFit,
    this._fovYDegrees = 60.0,
    this._zNear = 1.0,
    this._zFar = 10000.0,
  });

  /// The vertical field of view in degrees.
  double get fovYDegrees => _fovYDegrees;
  set fovYDegrees(double value) {
    if (_fovYDegrees == value) return;
    _fovYDegrees = value;
    setNeedsUpdate(true);
  }

  /// The distance to the near clipping plane.
  double get zNear => _zNear;
  set zNear(double value) {
    if (_zNear == value) return;
    _zNear = value;
    setNeedsUpdate(true);
  }

  /// The distance to the far clipping plane.
  double get zFar => _zFar;
  set zFar(double value) {
    if (_zFar == value) return;
    _zFar = value;
    setNeedsUpdate(true);
  }

  /// Creates a perspective projection matrix.
  ///
  /// This implementation builds a matrix compatible with modern graphics APIs
  /// (like Vulkan, Metal, or Impeller) where the Z depth range is [0.0, 1.0]
  /// and the Y axis is inverted to match Flutter's top-left origin.
  @override
  vm.Matrix4 createProjectionMatrix() {
    final double aspectRatio = viewRect.width / viewRect.height;

    vm.Matrix4 proj = vm.Matrix4.identity();
    vm.setPerspectiveMatrix(
      proj,
      vm.radians(_fovYDegrees),
      aspectRatio,
      _zNear,
      _zFar,
    );

    // flutter_gpu (Impeller) expects Z in [0, 1] (Vulkan style).
    // The vector_math matrix produces Z in [-1, 1] (OpenGL style).
    // We remap: Z_new = 0.5 * Z_old + 0.5

    bool test = true ;
    if (test) {
      final vm.Matrix4 remap = vm.Matrix4.identity();

      remap.setEntry(2, 2, 0.5);
      remap.setEntry(2, 3, 0.5);

      return remap * proj;
    }
  }
}
