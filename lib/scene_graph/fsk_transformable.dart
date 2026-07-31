import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart';

class FskTransformable with LoggableClass {
  /////////////////////////////////////////////////////////////////////////////
  // Private State
  /////////////////////////////////////////////////////////////////////////////

  final Vector3 _anchor = Vector3.zero();
  final Vector3 _position = Vector3.zero();
  final Vector3 _rotation = Vector3.zero();
  final Vector3 _scale = Vector3.all(1.0);
  final Matrix4 _transform = Matrix4.identity();

  bool _dirty = true;

  bool _isScaled = false;
  bool _isRotated = false;
  bool _isTranslated = false;
  bool _isAnchorSet = false;

  bool isTransformed() {
    return _isScaled || _isRotated || _isTranslated || _isAnchorSet;
  }

  void _updateTransform() {
    // Clear the matrix first
    _transform.setIdentity();

    // Step 3: Scale (Logically Last -> Coded First)

    if (_isScaled) {
      _transform.scaleByVector3(_scale);
    }

    // Step 2: Translate relative to the anchor (Coded Second)
    if (_isTranslated) {
      _transform.translateByVector3(_position);
    }

    // Step 1: Rotate around anchor point (Logically First -> Coded Last)
    // Move the anchor to the origin, rotate, then move it back.
    if (_isAnchorSet) {
      _transform.translateByVector3(_anchor);
    }

    if (_isRotated) {
      // 1c. Move origin back to anchor
      _transform.rotateZ(_rotation.z); // 1b. Apply your rotations
      _transform.rotateY(_rotation.y);
      _transform.rotateX(_rotation.x);
    }

    _dirty = false;
  }

  /////////////////////////////////////////////////////////////////////////////
  // Constructor
  /////////////////////////////////////////////////////////////////////////////
  FskTransformable();

  /////////////////////////////////////////////////////////////////////////////
  // Public Methods
  /////////////////////////////////////////////////////////////////////////////
  Vector3 get anchor => _anchor;
  Vector3 get position => _position;
  Vector3 get rotation => _rotation;
  Vector3 get scale => _scale;

  set anchor(Vector3 value) {
    _anchor.setFrom(value);
    _isAnchorSet = _anchor != Vector3.zero();
    _dirty = true;
  }

  set position(Vector3 value) {
    _position.setFrom(value);
    _isTranslated = _position != Vector3.zero();
    _dirty = true;
  }

  set rotation(Vector3 value) {
    _rotation.setFrom(value);
    _isRotated = _rotation != Vector3.zero();
    _dirty = true;
  }

  set scale(Vector3 value) {
    _scale.setFrom(value);
    logWarning("scaling not implemented yet");
    // TODO: scaling not implemented yet
    // Need to make scale matrix and add to shader something like
    // Math executes right-to-left: Raw position is scaled first
    // gl_Position = u_ScaleMatrix * vec4(aPos, 1.0);
    _isScaled = false;
    //_isScaled = _scale != Vector3.all(1.0);
    //_dirty = true;
  }

  Matrix4 getTransform() {
    if (_dirty) {
      _updateTransform();
    }
    return _transform;
  }
}

// Syntactic sugar for FskTransformable
mixin FskTransformableMixin on FskRenderableObject {
  Vector3 get anchor => transformable.anchor;
  Vector3 get position => transformable.position;
  Vector3 get rotation => transformable.rotation;
  Vector3 get scale => transformable.scale;

  set anchor(Vector3 value) {
    transformable.anchor = value;
  }

  set position(Vector3 value) {
    transformable.position = value;
  }

  set rotation(Vector3 value) {
    transformable.rotation = value;
  }

  set scale(Vector3 value) {
    transformable.scale = value;
  }
}
