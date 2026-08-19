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
  int get triangleCount =>
      (vertices?.length ?? 0) ~/ (FskVertexBuffer.componentCount * 3);

  /// Returns the triangle at the specified [index].
  vm.Triangle getTriangle(int index) {
    if (vertices == null) throw StateError("Mesh has no vertices");
    int offset = index * FskVertexBuffer.componentCount * 3;

    vm.Vector3 p0 = vm.Vector3(
      vertices![offset],
      vertices![offset + 1],
      vertices![offset + 2],
    );
    offset += FskVertexBuffer.componentCount;
    vm.Vector3 p1 = vm.Vector3(
      vertices![offset],
      vertices![offset + 1],
      vertices![offset + 2],
    );
    offset += FskVertexBuffer.componentCount;
    vm.Vector3 p2 = vm.Vector3(
      vertices![offset],
      vertices![offset + 1],
      vertices![offset + 2],
    );

    return vm.Triangle.points(p0, p1, p2);
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
