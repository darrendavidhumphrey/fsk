import 'dart:ui';

import 'package:fsk/shaders/base_uniforms.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;

import '../fsk_scene.dart';
import '../gpu/gpu_pipeline_key.dart';

abstract class FskSceneObject {

  final FskScene parentScene;

  FskSceneObject(this.parentScene);

  bool needsRebuild = true;
  void rebuildIfNeeded();
  void rebuildPipelineIfNeeded();

  // TODO: Get rid of the need for this, promote RefBox from bitmap text?
  Rect screenRect = Rect.zero;
}

abstract class FskRenderableObject extends FskSceneObject {
  FskRenderableObject(super.parentScene);

  void draw(gpu.RenderPass renderPass,gpu.HostBuffer transients, Matrix4 pMatrix, Matrix4 mvMatrix);
}
