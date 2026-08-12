import 'package:vector_math/vector_math.dart' as vm;
import 'perspective_view_delegate.dart';

/// A navigation delegate that implements a static view.
class StaticViewDelegate extends PerspectiveViewDelegate {
  StaticViewDelegate({
    super.viewRect,
    super.boxFit,
    super.fovYDegrees,
    super.zNear,
    super.zFar,
  });

  // The rotation of the view, in degrees
  vm.Vector3 _rotation = vm.Vector3(45, 0, 0);
  vm.Vector3 _orbitCenter = vm.Vector3(0, 0, 0);
  vm.Vector3 _eyeLocation = vm.Vector3(0, 0, -500);

  set rotation(vm.Vector3 value) {
    if (_rotation == value) return;
    _rotation = value;
    setNeedsUpdate(true);
  }

  set orbitCenter(vm.Vector3 value) {
    if (_orbitCenter == value) return;
    _orbitCenter = value;
    setNeedsUpdate(true);
  }

  set eyeLocation(vm.Vector3 value) {
    if (_eyeLocation == value) return;
    _eyeLocation = value;
    setNeedsUpdate(true);
  }

  // --- Getters ---
  vm.Vector3 get rotation => _rotation;
  vm.Vector3 get orbitCenter => _orbitCenter;
  vm.Vector3 get eyeLocation => _eyeLocation;

  @override
  vm.Vector3 getEyeLocation() {
    return _eyeLocation;
  }

  @override
  vm.Matrix4 createViewMatrix() {
    vm.Vector3 up = vm.Vector3(0, 1, 0);

    // Follow the conventions of OrbitViewDelegate:
    // 1. Use makeViewMatrix for the base camera transform.
    vm.Matrix4 view = vm.makeViewMatrix(getEyeLocation(), orbitCenter, up);

    // 2. Apply rotations around the orbit center in the same order as OrbitView.
    view.translateByVector3(orbitCenter);
    
    // Apply Euler rotations.
    view.rotateY(vm.radians(_rotation.y));
    view.rotateX(vm.radians(_rotation.x));
    view.rotateZ(vm.radians(_rotation.z));
    
    view.translateByVector3(-orbitCenter);

    return view;
  }
}
