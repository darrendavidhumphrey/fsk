import 'dart:typed_data';
import 'package:fsk/fsk.dart';
import 'package:fsk/scene_graph/fsk_depth_state.dart';

class FskMesh extends FskRenderableObject with FskTransformableMixin, FskDepthStateMixin {
  final FskTransformable transform = FskTransformable();

  /// Geometry data owned by the Mesh
  Float32List? vertices;

  /// Object that renders the mesh
  final FskMeshRenderer _renderer = FskMeshRenderer();

  /////////////////////////////////////////////////////////////////////////////
  // Constructor
  /////////////////////////////////////////////////////////////////////////////
  FskMesh(
    super.id,
    super.parentScene, {
    FskShaderMaterial? shaderMaterial,
  }) {
    setRenderer(_renderer);

    if (shaderMaterial != null) {
      this.shaderMaterial = shaderMaterial;
    }
  }

  @override
  FskMeshRenderer get renderer => _renderer;

  /// Uploads the owned geometry data to the renderer's GPU buffers
  void uploadToGpu() {
    if (vertices != null) {
      _renderer.vbo.uploadData(vertices!);
    }
  }

  @override
  void rebuildPipelineIfNeeded() {
    _renderer.rebuildPipeline();
  }

  void dump() {
    print('FskMesh Dump (id: $id):');
    if (vertices == null) {
      print('  Vertices: NULL');
    } else {
      print('  Vertices: ${vertices!.length} floats (${vertices!.length ~/ 12} vertices)');
    }

    print('  SubMeshes: ${_renderer.subMeshes.length}');
    for (int i = 0; i < _renderer.subMeshes.length; i++) {
      final sm = _renderer.subMeshes[i];
      print('    SM$i: count=${sm.count}, offset=${sm.offset}, material=${sm.materialName}');
    }
  }
}
