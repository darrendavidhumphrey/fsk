import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';

class FskIndexedMeshRenderer extends FskMeshRendererBase {
  final FskIndexBuffer _ibo = FskIndexBuffer();

  FskIndexBuffer get ibo => _ibo;

  FskIndexedMeshRenderer();

  @override
  void drawFskSubMesh(gpu.RenderPass renderPass, FskSubMesh subMesh) {
    _ibo.bind(renderPass, offsetInIndices: subMesh.firstIndex);
    _ibo.drawTrianglesIndexed(renderPass, count: subMesh.indexCount);
  }
}
