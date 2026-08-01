import 'dart:typed_data';
import 'package:fsk/fsk.dart';

import 'fsk_indexed_mesh_renderer.dart';

class FskIndexedMesh extends FskRenderableObject with FskTransformableMixin {
  final FskTransformable transform = FskTransformable();

  /// Geometry data owned by the Mesh
  Float32List? vertices;
  Uint16List? indices;

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

  /// Uploads the owned geometry data to the renderer's GPU buffers
  void uploadToGpu() {
    if (vertices != null) {
      _renderer.vbo.uploadData(vertices!);
    }
    if (indices != null) {
      _renderer.ibo.uploadData(indices!);
    }
  }

  @override
  void rebuildPipelineIfNeeded() {
    _renderer.rebuildPipeline();
  }
}
