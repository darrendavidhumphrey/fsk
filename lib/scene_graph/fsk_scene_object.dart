import 'package:fsk/scene_graph/fsk_renderer_base.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import '../fsk_scene.dart';
import '../logging.dart';

abstract class FskSceneObject with LoggableClass {

  final String id;
  final FskScene parentScene;

  FskSceneObject(this.id,this.parentScene);

  bool needsRebuild = true;
  void setNeedsRebuild() {
    needsRebuild = true;
  }

  void rebuildGeometry() {
    rebuildGeometryIfNeeded();
    rebuildPipelineIfNeeded();
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
}

abstract class FskRenderableObject extends FskSceneObject {
  bool visible = true;

  FskRenderableObject(super.id,super.parentScene);
  late FskRendererBase renderer;

  void draw(gpu.RenderPass renderPass,gpu.HostBuffer transients, Matrix4 pMatrix, Matrix4 mvMatrix) {
    if (!visible) return;
    renderer.draw(renderPass, transients, pMatrix, mvMatrix);
  }

  void setRenderer(FskRendererBase newRenderer) {
    renderer = newRenderer;
  }
}
