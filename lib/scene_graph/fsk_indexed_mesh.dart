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

  @override
  void updateUniforms(BaseUniforms uniforms) {
    super.updateUniforms(uniforms);

    final pbrModel = findAncestor<FskPbrModel>();
    if (pbrModel != null) {
      if (uniforms is PbrUniforms) {
        uniforms.lightPos = pbrModel.lightPosition;
        uniforms.debugMode = 0.0;
      } else if (uniforms is LightingUniforms) {
        uniforms.lightPos = pbrModel.lightPosition;
      }
    }
  }

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
    _cachedAabb = computeAabb(vertices!, FskVertexBuffer.componentCount);
    return _cachedAabb!;
  }

  /// The number of triangles in this mesh.
  int get triangleCount {
    final idx = indices;
    if (idx == null) return 0;
    return (idx.lengthInBytes ~/ idx.elementSizeInBytes) ~/ 3;
  }

  /// Returns the triangle at the specified [index].
  vm.Triangle getTriangle(int index) {
    if (vertices == null) throw StateError("Mesh has no vertices");
    if (indices == null) throw StateError("Mesh has no indices");

    final int i0, i1, i2;
    if (indices is Uint16List) {
      final idx = indices as Uint16List;
      i0 = idx[index * 3];
      i1 = idx[index * 3 + 1];
      i2 = idx[index * 3 + 2];
    } else if (indices is Uint32List) {
      final idx = indices as Uint32List;
      i0 = idx[index * 3];
      i1 = idx[index * 3 + 1];
      i2 = idx[index * 3 + 2];
    } else {
      throw StateError("Unsupported index format");
    }

    vm.Vector3 p0 = _getVertex(i0);
    vm.Vector3 p1 = _getVertex(i1);
    vm.Vector3 p2 = _getVertex(i2);

    return vm.Triangle.points(p0, p1, p2);
  }

  vm.Vector3 _getVertex(int index) {
    final int base = index * FskVertexBuffer.componentCount;
    return vm.Vector3(vertices![base], vertices![base + 1], vertices![base + 2]);
  }

  @override
  List<FskHitDetails> doHitTest(vm.Ray ray,
      {FskHitTestMode mode = FskHitTestMode.closest}) {
    return MeshHitTester.intersectFskIndexedMesh(this, ray, mode: mode);
  }
}
