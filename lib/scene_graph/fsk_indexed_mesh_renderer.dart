import 'package:flutter_gpu/gpu.dart' as gpu;
import 'fsk_mesh_renderer_base.dart';
import 'fsk_submesh.dart';
import '../gpu/fsk_index_buffer.dart';

class FskIndexedMeshRenderer extends FskMeshRendererBase {
  final FskIndexBuffer _ibo = FskIndexBuffer();

  FskIndexBuffer get ibo => _ibo;

  FskIndexedMeshRenderer();

  @override
  void dispose() {
    _ibo.dispose();
    super.dispose();
  }

  @override
  void drawFskSubMesh(gpu.RenderPass renderPass, FskSubMesh subMesh) {
    _ibo.bind(renderPass, offsetInIndices: subMesh.firstIndex);
    _ibo.drawTrianglesIndexed(renderPass, count: subMesh.indexCount);
  }
}
