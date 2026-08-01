import 'dart:ui';

import 'package:fsk/scene_graph/fsk_renderer_base.dart';
import 'package:fsk/scene_graph/fsk_transformable.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import '../fsk_scene.dart';
import '../geometry/reference_box.dart';
import '../gpu/fsk_shader_material.dart';
import '../shaders/base_uniforms.dart';
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

  /// Access to the renderer's active uniforms
  BaseUniforms? get uniforms => renderer.uniforms;

  void draw(gpu.RenderPass renderPass,gpu.HostBuffer transients, Matrix4 pMatrix, Matrix4 mvMatrix, Size viewportSize) {
    if (!visible) return;

    Matrix4 finalMvMatrix = mvMatrix;
    if (transformable.isTransformed()) {
      // Apply the transform to the matrix
      finalMvMatrix = mvMatrix.clone()..multiply(transformable.getTransform());
    }

    renderer.draw(renderPass, transients, pMatrix, finalMvMatrix, viewportSize);
  }

  void setRenderer(FskRendererBase newRenderer) {
    renderer = newRenderer;
    // Listen for uniform changes to trigger scene updates
    renderer.uniforms?.addListener(_onUniformsChanged);
  }

  void _onUniformsChanged() {
    parentScene.setNeedsUpdate();
  }

  /// Syntactic sugar to set a custom material on the renderer
  set shaderMaterial(FskShaderMaterial value) {
    // Clean up old listener
    renderer.uniforms?.removeListener(_onUniformsChanged);
    
    renderer.shaderMaterial = value;
    renderer.rebuildPipeline();
    
    // Add listener to new uniforms
    renderer.uniforms?.addListener(_onUniformsChanged);
    parentScene.setNeedsUpdate();
  }
}

/// Base class for 2D renderable objects defined in terms of a [ReferenceBox].
abstract class Fsk2DRenderableObject extends FskRenderableObject {
  Fsk2DRenderableObject(super.id,super.parentScene,this.refBox);

  /// The [ReferenceBox] that defines the target area for the text to be rendered into.
  final ReferenceBox refBox;
}
