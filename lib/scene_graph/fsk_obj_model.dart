import 'package:fsk/fsk.dart';

/// Lightweight specialized group node for Wavefront OBJ models that provides direct access
/// to the primary mesh once loaded.
class FskObjModel extends FskExternalModel {
  FskIndexedMesh? _mesh;

  /// The primary mesh of the OBJ model.
  /// Throws a [StateError] if accessed before the model is loaded successfully.
  FskIndexedMesh get mesh {
    if (_mesh == null) {
      throw StateError('Attempted to access FskObjModel.mesh before it was loaded or after a load failure.');
    }
    return _mesh!;
  }

  set mesh(FskIndexedMesh value) {
    _mesh = value;
  }

  FskObjModel(super.id, super.parentScene);
}
