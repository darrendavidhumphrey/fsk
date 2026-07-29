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
  void setNeedsRebuild() {
    needsRebuild = true;
  }


  /// Rebuilds the vertex buffer object if the text or font has changed.
  void rebuildGeometryIfNeeded() {
    // Guard against unnecessary, expensive rebuilds.
    if (!needsRebuild) return;
    doRebuild();
    needsRebuild = false;
  }

  /// Actually does the work of rebuilding the object. Child class
  /// must override
  void doRebuild();

  void rebuildPipelineIfNeeded();

  // TODO: Get rid of the need for this, promote RefBox from bitmap text?
  Rect screenRect = Rect.zero;
}

abstract class FskRenderableObject extends FskSceneObject {
  FskRenderableObject(super.parentScene);

  void draw(gpu.RenderPass renderPass,gpu.HostBuffer transients, Matrix4 pMatrix, Matrix4 mvMatrix);
}
