import 'dart:ui';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'fsk_renderer_base.dart';

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

    Matrix4 finalMvMatrix = mvMatrix;
    if (transformable.isTransformed()) {
      finalMvMatrix = transformable.getTransform().clone()..multiply(mvMatrix);
    }

    if (id == 'Penelope1' || id.contains('prim')) {
      print('--- [DRAW TRACE] $id ---');
      print('Final Translation: ${finalMvMatrix.getTranslation()}');
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
