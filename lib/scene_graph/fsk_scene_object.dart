import 'package:fsk/shaders/base_uniforms.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;

import '../fsk_scene.dart';
import '../gpu/gpu_pipeline_key.dart';

abstract class FskSceneObject {

  final FskScene parentScene;

  FskSceneObject(this.parentScene);
  void draw(gpu.RenderPass renderPass, Matrix4 pMatrix, Matrix4 mvMatrix);
  void rebuildIfNeeded();
}

abstract class FskRenderableObject extends FskSceneObject {
  BaseUniforms? uniforms;
  PipelineKey? pipelineKey;

  FskRenderableObject(super.parentScene);
}