import 'dart:typed_data';
import 'package:fsk/fsk.dart';
import 'package:fsk/scene_graph/fsk_depth_state.dart';
import 'package:vector_math/vector_math.dart' as vm;

class FskIndexedMesh extends FskRenderableObject with FskTransformableMixin, FskDepthStateMixin {
  final FskTransformable transform = FskTransformable();

  /// Geometry data owned by the Mesh
  Float32List? vertices;
  TypedData? indices;

  vm.Aabb3? _cachedAabb;

  /// Object that renders the indexed mesh
  final FskIndexedMeshRenderer _renderer = FskIndexedMeshRenderer();

  /////////////////////////////////////////////////////////////////////////////
  // Constructor
  /////////////////////////////////////////////////////////////////////////////
  FskIndexedMesh(
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
    return MeshHitTester.intersectFskIndexedMesh(this, ray, mode: mode);
  }
}
