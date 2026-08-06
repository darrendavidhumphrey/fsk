import 'package:fsk/fsk.dart';

/// Lightweight specialized group node for Wavefront OBJ models that provides direct access
/// to the primary mesh.
class FskObjModel extends FskGroup {
  /// The primary mesh of the OBJ model.
  final FskIndexedMesh mesh;

  FskObjModel(super.id, super.parentScene,this.mesh);
}
