import 'package:fsk/shaders/base_uniforms.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;

import '../gpu/gpu_pipeline_key.dart';

abstract class FskSceneObject {
  void drawSetup(gpu.RenderPass renderPass, Matrix4 pMatrix, Matrix4 mvMatrix);
  void draw(gpu.RenderPass renderPass);
  void rebuild();
}

abstract class FskRenderableObject extends FskSceneObject {
  BaseUniforms? uniforms;
  PipelineKey? pipelineKey;
}