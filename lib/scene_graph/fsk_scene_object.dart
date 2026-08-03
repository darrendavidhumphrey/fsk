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

  void rebuildGeometryIfNeeded() {
    if (!needsRebuild) return;
    doRebuild();
    needsRebuild = false;
  }

  void doRebuild() {}
  void rebuildPipelineIfNeeded();
}

abstract class FskRenderableObject extends FskSceneObject {
  final FskTransformable transformable = FskTransformable();
  bool visible = true;

  FskRenderableObject(super.id,super.parentScene);
  FskRendererBase? _renderer;
  
  FskRendererBase get renderer => _renderer!;

  BaseUniforms? get uniforms => _renderer?.uniforms;

  void draw(gpu.RenderPass renderPass,gpu.HostBuffer transients, Matrix4 pMatrix, Matrix4 mvMatrix, Size viewportSize) {
    if (!visible) return;

    Matrix4 finalMvMatrix = mvMatrix.clone();
    if (transformable.isTransformed()) {
      finalMvMatrix.multiply(transformable.getTransform());
    }

    _renderer?.draw(renderPass, transients, pMatrix, finalMvMatrix, viewportSize);
  }

  void setRenderer(FskRendererBase newRenderer) {
    _renderer = newRenderer;
    _renderer?.uniforms?.addListener(_onUniformsChanged);
  }

  void _onUniformsChanged() {
    parentScene.setNeedsUpdate();
  }

  set shaderMaterial(FskShaderMaterial value) {
    if (_renderer == null) return;
    _renderer!.uniforms?.removeListener(_onUniformsChanged);
    _renderer!.shaderMaterial = value;
    _renderer!.rebuildPipeline();
    _renderer!.uniforms?.addListener(_onUniformsChanged);
    parentScene.setNeedsUpdate();
  }
}

abstract class Fsk2DRenderableObject extends FskRenderableObject {
  Fsk2DRenderableObject(super.id,super.parentScene,this.refBox);
  final ReferenceBox refBox;
}
