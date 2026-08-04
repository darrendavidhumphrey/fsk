import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';

class FskMeshRenderer extends FskMeshRendererBase {
  @override
  void drawFskSubMesh(gpu.RenderPass renderPass, FskSubMesh subMesh) {
    vbo.bind(renderPass, offsetInVertices: subMesh.offset);
    renderPass.draw(subMesh.count);
  }
}
