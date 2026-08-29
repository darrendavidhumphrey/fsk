import 'fsk_external_model.dart';
import 'fsk_mesh.dart';

/// Lightweight specialized group node for STL models that provides direct access
/// to the primary mesh once loaded.
class FskStlModel extends FskExternalModel {
  FskMesh? _mesh;

  /// The primary mesh of the STL model.
  /// Throws a [StateError] if accessed before the model is loaded successfully.
  FskMesh get mesh {
    if (_mesh == null) {
      throw StateError('Attempted to access FskStlModel.mesh before it was loaded or after a load failure.');
    }
    return _mesh!;
  }

  set mesh(FskMesh value) {
    _mesh = value;
  }

  FskStlModel(super.id, super.parentScene);
}
