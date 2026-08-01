import 'package:fsk/fsk.dart';


class FskIndexedMesh extends FskRenderableObject with FskTransformableMixin {
  final FskTransformable transform = FskTransformable();

  /// Object that renders the indexed mesh
  final FskIndexedMeshRenderer _renderer = FskIndexedMeshRenderer();

  /////////////////////////////////////////////////////////////////////////////
  // Constructor
  /////////////////////////////////////////////////////////////////////////////
  FskIndexedMesh(
    super.id,
    super.parentScene,
  ) {
    setRenderer(_renderer);
  }

  @override
  FskIndexedMeshRenderer get renderer => _renderer;

  @override
  void rebuildPipelineIfNeeded() {
    _renderer.rebuildPipeline();
  }
}
