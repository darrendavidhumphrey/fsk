import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';

class FskMeshRenderer extends FskMeshRendererBase {
  gpu.CullMode _cullMode = gpu.CullMode.backFace;

  @override
  gpu.CullMode get cullMode => _cullMode;

  set cullMode(gpu.CullMode value) {
    if (_cullMode == value) return;
    _cullMode = value;
    pipeLineNeedsRebuild = true;
    notifyListeners();
  }

  @override
  void drawFskSubMesh(gpu.RenderPass renderPass, FskSubMesh subMesh) {
    vbo.bind(renderPass, offsetInVertices: subMesh.offset);
    renderPass.draw(subMesh.count);
  }
}
