import 'dart:typed_data';
import 'package:fsk/fsk.dart';
import 'package:fsk/scene_graph/fsk_depth_state.dart';
import 'package:vector_math/vector_math.dart' as vm;

class FskMesh extends FskRenderableObject with FskTransformableMixin, FskDepthStateMixin {
  final FskTransformable transform = FskTransformable();

  /// Geometry data owned by the Mesh
  Float32List? vertices;

  vm.Aabb3? _cachedAabb;

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

  @override
  vm.Aabb3 getAabb() {
    if (_cachedAabb != null) return _cachedAabb!;
    if (vertices == null) {
      return vm.Aabb3.minMax(
        vm.Vector3.all(double.infinity),
        vm.Vector3.all(double.negativeInfinity),
      );
    }
    _cachedAabb = computeAabb(vertices!, 12);
    return _cachedAabb!;
  }

  @override
  List<FskHitDetails> doHitTest(vm.Ray ray,
      {FskHitTestMode mode = FskHitTestMode.closest}) {
    return MeshHitTester.intersectFskMesh(this, ray, mode: mode);
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
