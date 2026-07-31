import 'package:fsk/scene_graph/fsk_renderer_base.dart';
import 'package:fsk/scene_graph/fsk_transformable.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import '../fsk_scene.dart';
import '../geometry/reference_box.dart';
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
  /// should override this method if it needs to do anything.
  void doRebuild() {}

  void rebuildPipelineIfNeeded();
}

abstract class FskRenderableObject extends FskSceneObject {
  final FskTransformable transformable = FskTransformable();
  bool visible = true;

  FskRenderableObject(super.id,super.parentScene);
  late FskRendererBase renderer;

  void draw(gpu.RenderPass renderPass,gpu.HostBuffer transients, Matrix4 pMatrix, Matrix4 mvMatrix) {
    if (!visible) return;

    if (transformable.isTransformed()) {
      // Apply the transform to the matrix
      mvMatrix =  transformable.getTransform() * mvMatrix;
    }

    renderer.draw(renderPass, transients, pMatrix, mvMatrix);
  }

  void setRenderer(FskRendererBase newRenderer) {
    renderer = newRenderer;
  }
}

/// Base class for 2D renderable objects defined in terms of a [ReferenceBox].
abstract class Fsk2DRenderableObject extends FskRenderableObject {
  Fsk2DRenderableObject(super.id,super.parentScene,this.refBox);

  /// The [ReferenceBox] that defines the target area for the text to be rendered into.
  final ReferenceBox refBox;
}