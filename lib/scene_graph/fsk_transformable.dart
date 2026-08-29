import 'fsk_scene_object.dart';
import 'package:vector_math/vector_math.dart' as vm;

class FskTransformable {
  final vm.Vector3 _anchor = vm.Vector3.zero();
  final vm.Vector3 _position = vm.Vector3.zero();
  final vm.Vector3 _rotation = vm.Vector3.zero();
  final vm.Vector3 _scale = vm.Vector3.all(1.0);
  final vm.Matrix4 _transform = vm.Matrix4.identity();

  bool _dirty = true;
  bool _isScaled = false;
  bool _isRotated = false;
  bool _isTranslated = false;
  bool _isAnchorSet = false;

  bool isTransformed() => _isScaled || _isRotated || _isTranslated || _isAnchorSet;

  void _updateTransform() {
    _transform.setIdentity();

    // ORIGINAL STABLE TRS SEQUENCE
    if (_isTranslated) _transform.translateByVector3(_position);
    if (_isRotated) {
      _transform.rotateZ(_rotation.z);
      _transform.rotateY(_rotation.y);
      _transform.rotateX(_rotation.x);
    }
    if (_isScaled) _transform.scaleByVector3(_scale);
    if (_isAnchorSet) _transform.translateByVector3(_anchor);

    _dirty = false;
  }

  FskTransformable();

  vm.Vector3 get anchor => _anchor;
  vm.Vector3 get position => _position;
  vm.Vector3 get rotation => _rotation;
  vm.Vector3 get scale => _scale;

  set anchor(vm.Vector3 value) {
    _anchor.setFrom(value);
    _isAnchorSet = (_anchor.x != 0 || _anchor.y != 0 || _anchor.z != 0);
    _dirty = true;
  }
  set position(vm.Vector3 value) {
    _position.setFrom(value);
    _isTranslated = (_position.x != 0 || _position.y != 0 || _position.z != 0);
    _dirty = true;
  }
  set rotation(vm.Vector3 value) {
    _rotation.setFrom(value);
    _isRotated = (_rotation.x != 0 || _rotation.y != 0 || _rotation.z != 0);
    _dirty = true;
  }
  set scale(vm.Vector3 value) {
    _scale.setFrom(value);
    _isScaled = (_scale.x != 1.0 || _scale.y != 1.0 || _scale.z != 1.0);
    _dirty = true;
  }

  vm.Matrix4 getTransform() {
    if (_dirty) _updateTransform();
    return _transform;
  }
}

mixin FskTransformableMixin on FskRenderableObject {
  vm.Vector3 get anchor => transformable.anchor;
  vm.Vector3 get position => transformable.position;
  vm.Vector3 get rotation => transformable.rotation;
  vm.Vector3 get scale => transformable.scale;

  set anchor(vm.Vector3 v) => transformable.anchor = v;
  set position(vm.Vector3 v) => transformable.position = v;
  set rotation(vm.Vector3 v) => transformable.rotation = v;
  set scale(vm.Vector3 v) => transformable.scale = v;
}
