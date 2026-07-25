import 'package:vector_math/vector_math.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;

abstract class FskSceneObject {

  void initShaderParams(Map<String, String> params);
  void applyShaderParams();


  void drawSetup(gpu.RenderPass renderPass, Matrix4 pMatrix, Matrix4 mvMatrix);
  void draw(gpu.RenderPass renderPass);
  void init();
  void rebuild();
  void dispose();
}

class FskRenderableObject extends FskSceneObject {

  gpu.Shader? _vertexShader;
  gpu.Shader? _fragmentShader;
  gpu.Shader get vertShader => _vertexShader!;
  gpu.Shader get fragShader => _fragmentShader!;


  void setShader(gpu.Shader? vert, gpu.Shader? frag) {
    _vertexShader = vert!;
    _fragmentShader = frag!;
  }


  @override
  void initShaderParams(Map<String, String> params) {

  }

  @override
  void applyShaderParams() {

  }

  @override
  void dispose() {
    // TODO: implement dispose
  }

  @override
  void draw(gpu.RenderPass renderPass) {
    // TODO: implement draw
  }

  @override
  void drawSetup(gpu.RenderPass renderPass,Matrix4 pMatrix, Matrix4 mvMatrix) {
    // TODO: implement drawSetup
  }

  @override
  void init() {
    // TODO: implement init
  }

  @override
  void rebuild() {
    // TODO: implement rebuild
  }

}
